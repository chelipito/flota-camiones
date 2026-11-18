-- v47: facturas recibidas de proveedores (hoja "Proveedores" de Ventas y caja)
-- Ejecutar una sola vez en Supabase > SQL Editor. Hasta entonces la app las guarda en el registro compartido.
create table if not exists compras (
  id text primary key,
  proveedor text not null,
  factura text not null default '',     -- N° de factura recibida
  fecha date,                            -- fecha de la factura
  vence date,                            -- vencimiento (vacío = fecha + plazo normal de Configuración)
  neto numeric,                          -- monto neto; IVA 19 % y total se calculan en la app
  estado text not null default 'pendiente',  -- 'pendiente' | 'pagada'
  fecha_pago date,
  notas text not null default '',
  creado timestamptz not null default now()
);
alter table compras enable row level security;
drop policy if exists "con sesion: compras" on compras;
create policy "con sesion: compras" on compras for all to authenticated using (true) with check (true);
