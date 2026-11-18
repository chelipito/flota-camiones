-- v48: proveedores definidos (módulo Administración y finanzas > Proveedores)
-- Ejecutar en Supabase > SQL Editor. Se puede ejecutar de nuevo sin problema.
-- Hasta entonces la app guarda los proveedores en el registro compartido.
create table if not exists proveedores (
  id text primary key,
  nombre text not null,
  rut text not null default '',
  direccion text not null default '',
  encargado text not null default '',       -- nombre del representante o encargado
  rut_encargado text not null default '',
  correo text not null default '',
  creado timestamptz not null default now()
);
alter table proveedores enable row level security;
drop policy if exists "con sesion: proveedores" on proveedores;
create policy "con sesion: proveedores" on proveedores for all to authenticated using (true) with check (true);
