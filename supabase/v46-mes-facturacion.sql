-- Control de Flota · v46: mes de facturación de cada servicio
-- Cómo usarlo: Supabase → SQL Editor → pestaña nueva (+) → pega todo esto → Run. Se ejecuta una vez (se puede repetir).
-- Agrega una columna a la tabla ventas y la llena con el mes de la fecha de factura de los servicios ya facturados.
alter table ventas add column if not exists mes_facturacion text not null default '';   -- 'AAAA-MM'
update ventas set mes_facturacion = to_char(fecha_factura, 'YYYY-MM') where fecha_factura is not null and mes_facturacion = '';
select count(*) as ventas, count(*) filter (where mes_facturacion <> '') as con_mes_de_facturacion from ventas;
