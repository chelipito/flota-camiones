-- Control de Flota · v43: clientes, ventas y leasing en tablas propias (una fila cada uno)
-- (Incluye también lo del v44: la columna lineas. Con este solo script basta.)
-- Cómo usarlo: Supabase → SQL Editor → pestaña nueva (+) → pega todo esto → Run. Se puede repetir sin problema.
-- Qué hace: crea las tablas, copia lo que hoy está guardado dentro del registro compartido (estado_app) y,
-- solo si la copia quedó completa, lo saca de ahí. No borra ningún dato.
-- Después: recarga la app en cada equipo (computador y celulares).

-- 1) Tablas
create table if not exists clientes (
  id text primary key,
  nombre text not null,
  contacto text not null default '',
  telefono text not null default '',
  correo text not null default '',
  plazo_pago int,                      -- días para pagar; vacío = el plazo normal de Configuración
  creado timestamptz not null default now()
);
create table if not exists ventas (
  id text primary key,
  mes text not null,                   -- 'AAAA-MM'
  area text not null default 'rental',
  cliente text not null,
  oc text not null default '',         -- N° de orden de compra
  edp text not null default '',        -- N° EDP (por aclarar con el cliente)
  equipos text not null default '',
  desde date,
  hasta date,
  neto numeric not null default 0,     -- monto neto; IVA y total se calculan
  proveedor numeric,                   -- valor del proveedor (equipos de terceros)
  estado text not null default 'pendiente',   -- pendiente · en revision · facturado · pagado
  factura text not null default '',
  fecha_factura date,
  fecha_pago date,
  notas text not null default '',
  origen text not null default 'app',  -- app o excel
  hes text not null default '',        -- N° HES
  lineas jsonb,                        -- equipos de la orden: [{id, equipo, neto, tercero, leasing}]
  creado timestamptz not null default now()
);
alter table ventas add column if not exists hes text not null default '';
alter table ventas add column if not exists lineas jsonb;   -- por si la tabla ya existía sin esta columna
create index if not exists ventas_mes on ventas (mes);
create index if not exists ventas_estado on ventas (estado);
create table if not exists leasing (
  id text primary key,
  equipo text not null,
  valor numeric not null default 0,
  pie numeric not null default 0,
  plazo int not null default 1,
  tasa numeric not null default 0,
  vf numeric not null default 0,
  arriendo numeric,
  inicio date,
  creado timestamptz not null default now()
);

-- 2) Seguridad: solo usuarios con sesión pueden ver y cambiar
alter table clientes enable row level security;
alter table ventas enable row level security;
alter table leasing enable row level security;
drop policy if exists "con sesion: clientes" on clientes;
drop policy if exists "con sesion: ventas" on ventas;
drop policy if exists "con sesion: leasing" on leasing;
create policy "con sesion: clientes" on clientes for all to authenticated using (true) with check (true);
create policy "con sesion: ventas" on ventas for all to authenticated using (true) with check (true);
create policy "con sesion: leasing" on leasing for all to authenticated using (true) with check (true);

-- 3) Copiar lo que hay hoy en estado_app (si ya se copió, no se repite)
insert into clientes (id, nombre, contacto, telefono, correo, plazo_pago)
select x.id, x.nombre, coalesce(x.contacto, ''), coalesce(x.telefono, ''), coalesce(x.correo, ''), x."plazoPago"
from estado_app e, jsonb_to_recordset(coalesce(e.datos -> 'clientes', '[]'::jsonb))
  as x(id text, nombre text, contacto text, telefono text, correo text, "plazoPago" int)
where e.id = 1
on conflict (id) do nothing;

insert into ventas (id, mes, area, cliente, oc, edp, equipos, desde, hasta, neto, proveedor, estado, factura, fecha_factura, fecha_pago, notas, origen, lineas)
select x.id, x.mes, coalesce(x.area, 'rental'), x.cliente, coalesce(x.oc, ''), coalesce(x.edp, ''), coalesce(x.equipos, ''),
       nullif(x.desde, '')::date, nullif(x.hasta, '')::date, coalesce(x.neto, 0), x.proveedor, coalesce(x.estado, 'pendiente'),
       coalesce(x.factura, ''), nullif(x."fechaFactura", '')::date, nullif(x."fechaPago", '')::date, coalesce(x.notas, ''), coalesce(x.origen, 'app'), x.lineas
from estado_app e, jsonb_to_recordset(coalesce(e.datos -> 'ventas', '[]'::jsonb))
  as x(id text, mes text, area text, cliente text, oc text, edp text, equipos text, desde text, hasta text, neto numeric, proveedor numeric,
       estado text, factura text, "fechaFactura" text, "fechaPago" text, notas text, origen text, lineas jsonb)
where e.id = 1
on conflict (id) do nothing;

insert into leasing (id, equipo, valor, pie, plazo, tasa, vf, arriendo, inicio)
select x.id, x.equipo, coalesce(x.valor, 0), coalesce(x.pie, 0), coalesce(x.plazo, 1), coalesce(x.tasa, 0), coalesce(x.vf, 0), x.arriendo, nullif(x.inicio, '')::date
from estado_app e, jsonb_to_recordset(coalesce(e.datos -> 'leasing', '[]'::jsonb))
  as x(id text, equipo text, valor numeric, pie numeric, plazo int, tasa numeric, vf numeric, arriendo numeric, inicio text)
where e.id = 1
on conflict (id) do nothing;

-- 4) Sacar esos datos del registro compartido, solo si las tablas quedaron con todo
update estado_app
set datos = (datos - 'clientes' - 'ventas' - 'leasing') || jsonb_build_object('_v', 'tablas-' || extract(epoch from now())::bigint),
    actualizado = now()
where id = 1
  and (select count(*) from clientes) >= coalesce(jsonb_array_length(datos -> 'clientes'), 0)
  and (select count(*) from ventas)   >= coalesce(jsonb_array_length(datos -> 'ventas'), 0)
  and (select count(*) from leasing)  >= coalesce(jsonb_array_length(datos -> 'leasing'), 0);

-- Revisar: con tus datos de hoy debe mostrar 171 ventas y 27 clientes
select (select count(*) from ventas) as ventas,
       (select count(*) from clientes) as clientes,
       (select count(*) from leasing) as leasing,
       (select datos ? 'ventas' from estado_app where id = 1) as aun_en_registro_compartido;
