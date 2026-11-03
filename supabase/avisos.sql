-- Control de Flota · registro de avisos automáticos enviados al dueño
-- Cómo usarlo: Supabase → SQL Editor → pestaña nueva (+) → pega todo esto → Run. Se ejecuta una sola vez.
-- Sirve para que cada aviso llegue una sola vez y para mostrar en la app los últimos avisos enviados.
create table avisos_enviados (
  clave text primary key,          -- p. ej. HKTZ48|mantencion|7500|porvencer
  detalle text not null,           -- el mensaje que se envió
  enviado timestamptz not null default now()
);
alter table avisos_enviados enable row level security;
create policy "con sesion: ver avisos enviados" on avisos_enviados for select to authenticated using (true);
