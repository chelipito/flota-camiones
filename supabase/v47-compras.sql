-- v47: facturas recibidas de proveedores (hoja "Proveedores" de Ventas y caja)
-- Ejecutar en Supabase > SQL Editor. Se puede ejecutar de nuevo sin problema (si ya lo corriste, agrega solo lo que falta).
-- Hasta entonces la app guarda las facturas en el registro compartido.
create table if not exists compras (
  id text primary key,
  proveedor text not null,
  factura text not null default '',     -- N° de factura recibida
  fecha date,                            -- fecha de la factura (define el mes de factura)
  vence date,                            -- vencimiento (vacío = fecha + plazo normal de Configuración)
  neto numeric,                          -- monto neto; IVA 19 % y total se calculan en la app
  estado text not null default 'pendiente',  -- 'pendiente' | 'parcial' | 'pagada'
  fecha_pago date,
  notas text not null default '',
  creado timestamptz not null default now()
);
alter table compras add column if not exists mes_servicio text not null default '';  -- 'AAAA-MM'
alter table compras add column if not exists abonado numeric;                         -- monto pagado con IVA (pago parcial)
alter table compras add column if not exists pagos jsonb;                             -- pagos en cuotas: [{id, fecha, monto, pagado}]
alter table compras add column if not exists tipo text not null default 'afecta';     -- 'afecta' (con IVA 19 %) | 'exenta' (sin IVA)
-- las facturas que ya existían: su mes de servicio es el mes de la factura
update compras set mes_servicio = to_char(fecha, 'YYYY-MM') where mes_servicio = '' and fecha is not null;
alter table compras enable row level security;
drop policy if exists "con sesion: compras" on compras;
create policy "con sesion: compras" on compras for all to authenticated using (true) with check (true);
