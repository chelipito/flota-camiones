-- Control de Flota · base de datos para la demo con WhatsApp real
-- Se pega completo en Supabase → SQL Editor → Run. Se ejecuta una sola vez.

-- Camiones que pueden recibir registros por WhatsApp
create table camiones (
  patente text primary key,
  limite numeric not null            -- límite de horas de motor
);

-- Cada lectura del horómetro
create table lecturas (
  id bigint generated always as identity primary key,
  patente text not null references camiones (patente),
  valor numeric not null check (valor > 0),
  fecha timestamptz not null default now(),
  origen text not null default 'whatsapp',   -- 'whatsapp' o 'ejemplo'
  nombre text,                               -- nombre de perfil de WhatsApp de quien registró
  telefono text,
  wamid text unique                          -- id del mensaje de WhatsApp: evita guardar dos veces el mismo
);
create index lecturas_patente_fecha on lecturas (patente, fecha);

-- Seguridad: la app (clave pública) solo puede LEER.
-- Solo la función de WhatsApp escribe, porque usa la clave secreta del servidor.
alter table camiones enable row level security;
alter table lecturas enable row level security;
create policy "la app puede leer camiones" on camiones for select to anon using (true);
create policy "la app puede leer lecturas" on lecturas for select to anon using (true);

-- Camión de la presentación (misma patente que en la app)
insert into camiones (patente, limite) values ('HKTZ48', 12000);

-- Historial de ejemplo: 13 lecturas diarias que terminan hace 2 días,
-- para que la app muestre el gráfico, la proyección y el aviso de "sin reporte"
insert into lecturas (patente, valor, fecha, origen, nombre)
select 'HKTZ48',
       round(7340 + g * 7.4 + (g % 3) * 0.6, 1),
       date_trunc('day', now()) - (15 - g) * interval '1 day' + interval '21 hours',
       'ejemplo',
       'Juan Pérez'
from generate_series(1, 13) as g;
