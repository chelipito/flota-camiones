-- Control de Flota · registrar el horómetro desde la app (además de WhatsApp)
-- Cómo usarlo: Supabase → SQL Editor → pestaña nueva (+) → pega todo esto → Run. Se ejecuta una sola vez.
-- Solo usuarios con sesión. Aplica las mismas reglas que WhatsApp: el horómetro nunca baja y, si está activada
-- en la app (Configuración → Alertas → Registro del horómetro), no puede subir más horas de las que pasaron.
-- Si ya lo habías ejecutado, ejecútalo de nuevo: reemplaza la versión anterior.
create or replace function registrar_lectura(p_patente text, p_valor numeric)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  ult record;
  pasaron numeric;
begin
  if not exists (select 1 from camiones where patente = p_patente) then raise exception 'No existe un camión con esa patente'; end if;
  if p_valor is null or p_valor <= 0 then raise exception 'Escribe el número del horómetro, solo con números.'; end if;
  select valor, fecha into ult from lecturas where patente = p_patente order by fecha desc limit 1;
  if found then
    if p_valor < ult.valor then
      raise exception 'El número es menor que la última lectura (% h). El horómetro nunca baja: revisa el número.', ult.valor;
    end if;
    pasaron := extract(epoch from (now() - ult.fecha)) / 3600;
    if coalesce((select (datos -> 'config' ->> 'validarSalto')::boolean from estado_app where id = 1), false)
       and p_valor - ult.valor > pasaron + 0.5 then
      raise exception 'Son % horas más que la última vez, pero solo han pasado % horas. Revisa el número.', round(p_valor - ult.valor, 1), round(pasaron, 1);
    end if;
  end if;
  insert into lecturas (patente, valor, origen, nombre) values (p_patente, p_valor, 'app', coalesce(auth.jwt() ->> 'email', 'App'));
end $$;

revoke execute on function registrar_lectura(text, numeric) from public, anon, authenticated;
grant execute on function registrar_lectura(text, numeric) to authenticated;
