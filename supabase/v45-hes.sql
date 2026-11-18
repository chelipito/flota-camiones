-- Control de Flota · v45: número de HES en cada servicio
-- Cómo usarlo: Supabase → SQL Editor → pestaña nueva (+) → pega todo esto → Run. Se ejecuta una vez (se puede repetir).
-- Agrega una columna a la tabla ventas. No borra ni cambia ningún dato.
alter table ventas add column if not exists hes text not null default '';
select count(*) as ventas from ventas;
