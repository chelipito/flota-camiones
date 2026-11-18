-- Control de Flota · v44: cada orden de compra puede traer varios equipos, cada uno con su monto
-- Cómo usarlo: Supabase → SQL Editor → pestaña nueva (+) → pega todo esto → Run. Se ejecuta una vez (se puede repetir).
-- Agrega una columna a la tabla ventas. No borra ni cambia ningún dato.
alter table ventas add column if not exists lineas jsonb;   -- [{id, equipo, neto, tercero, leasing}]
select count(*) as ventas from ventas;
