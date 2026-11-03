-- Control de Flota · cambiar el camión de la demo por uno real
-- Cómo usarlo: Supabase → SQL Editor → pega todo esto → cambia SOLO los 3 valores de abajo → Run.
-- La app y WhatsApp toman el cambio solos (la app en menos de 10 segundos).
-- OJO: borra el camión anterior y todos sus registros. Para volver al ejemplo, córrelo con HKTZ48, 12000 y 7450.
do $$
declare
  nueva_patente    text    := 'HKTZ48';  -- patente del equipo (puede ir con guion o espacios)
  limite_horas     numeric := 12000;     -- límite de horas de motor
  horometro_actual numeric := 7450;      -- lo que marca hoy el horómetro (decimales con punto: 7450.5)
  p text := upper(regexp_replace(nueva_patente, '[^A-Za-z0-9]', '', 'g'));
begin
  delete from lecturas;
  delete from camiones;
  insert into camiones (patente, limite) values (p, limite_horas);
  -- Lectura inicial: desde aquí, WhatsApp acepta el mismo número o uno mayor (según las horas que pasen)
  insert into lecturas (patente, valor, origen, nombre) values (p, horometro_actual, 'ejemplo', 'Lectura inicial');
end $$;
