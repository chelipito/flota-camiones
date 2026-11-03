-- Control de Flota · inicio de sesión y datos compartidos
-- Cómo usarlo: Supabase → SQL Editor → pestaña nueva (+) → pega todo esto → Run. Se ejecuta una sola vez.
-- Desde aquí, solo quien inicia sesión puede ver y cambiar datos. WhatsApp sigue funcionando igual.

-- Camiones, contratos y configuración de la app (un solo registro que comparten todos los usuarios)
create table estado_app (
  id int primary key default 1 check (id = 1),
  datos jsonb not null,
  actualizado timestamptz not null default now()
);
alter table estado_app enable row level security;
create policy "con sesion: ver estado" on estado_app for select to authenticated using (true);
create policy "con sesion: crear estado" on estado_app for insert to authenticated with check (true);
create policy "con sesion: cambiar estado" on estado_app for update to authenticated using (true) with check (true);

-- Camiones y registros: antes los veía cualquiera con la clave pública; ahora solo usuarios con sesión
drop policy "la app puede leer camiones" on camiones;
drop policy "la app puede leer lecturas" on lecturas;
create policy "con sesion: ver camiones" on camiones for select to authenticated using (true);
create policy "con sesion: ver lecturas" on lecturas for select to authenticated using (true);

-- Agregar camiones: solo usuarios con sesión
revoke execute on function agregar_camion(text, numeric, numeric, timestamptz) from anon;
grant execute on function agregar_camion(text, numeric, numeric, timestamptz) to authenticated;

-- Quitar un camión y sus registros: solo usuarios con sesión
create or replace function quitar_camion(p_patente text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from lecturas where patente = p_patente;
  delete from camiones where patente = p_patente;
end $$;
revoke execute on function quitar_camion(text) from public, anon, authenticated;
grant execute on function quitar_camion(text) to authenticated;
