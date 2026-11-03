-- Control de Flota · permitir que la app agregue camiones nuevos que funcionen con WhatsApp
-- Cómo usarlo: Supabase → SQL Editor → pega todo esto → Run. Se ejecuta una sola vez.
--
-- Seguridad: la app solo puede AGREGAR camiones nuevos con su primera lectura.
-- No puede borrar ni cambiar camiones existentes, ni agregar lecturas a ellos.
-- Es una solución para la demo: en la versión real esto queda detrás del inicio de sesión del dueño.
create or replace function agregar_camion(p_patente text, p_limite numeric, p_horometro numeric, p_fecha timestamptz default now())
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  p text := upper(regexp_replace(p_patente, '[^A-Za-z0-9]', '', 'g'));
begin
  if p !~ '^[A-Z]{2,4}[0-9]{2,4}$' then raise exception 'La patente debe tener letras y números, por ejemplo ABCD12'; end if;
  if p_limite is null or p_limite <= 0 or p_horometro is null or p_horometro <= 0 then raise exception 'El límite y el horómetro deben ser mayores que cero'; end if;
  if p_fecha > now() + interval '5 minutes' then raise exception 'La fecha de la lectura no puede ser futura'; end if;
  if exists (select 1 from camiones where patente = p) then raise exception 'Ya existe un camión con esa patente'; end if;
  if (select count(*) from camiones) >= 20 then raise exception 'La demo admite hasta 20 camiones'; end if;
  insert into camiones (patente, limite) values (p, p_limite);
  insert into lecturas (patente, valor, fecha, origen, nombre) values (p, p_horometro, p_fecha, 'ejemplo', 'Lectura inicial');
end $$;

revoke execute on function agregar_camion(text, numeric, numeric, timestamptz) from public, anon, authenticated;
grant execute on function agregar_camion(text, numeric, numeric, timestamptz) to anon;
