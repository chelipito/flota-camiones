-- Control de Flota · v38: documentos de la revisión técnica + cambiar el límite de horas desde la app
-- Cómo usarlo: Supabase → SQL Editor → pega todo esto → Run. Se ejecuta una sola vez (se puede repetir sin problema).

-- 1) Cambiar el límite de horas de un camión (solo usuarios con sesión)
create or replace function cambiar_limite(p_patente text, p_limite numeric)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_limite is null or p_limite <= 0 then raise exception 'El límite debe ser mayor que cero'; end if;
  update camiones set limite = p_limite where patente = p_patente;
  if not found then raise exception 'No existe un camión con esa patente'; end if;
end $$;

revoke execute on function cambiar_limite(text, numeric) from public, anon, authenticated;
grant execute on function cambiar_limite(text, numeric) to authenticated;

-- 2) Almacenamiento privado "documentos" (PDF o fotos, máximo 10 MB por archivo)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('documentos', 'documentos', false, 10485760, array['application/pdf', 'image/*'])
on conflict (id) do nothing;

-- Solo usuarios con sesión pueden ver, subir y borrar documentos
drop policy if exists "con sesion: ver documentos" on storage.objects;
drop policy if exists "con sesion: subir documentos" on storage.objects;
drop policy if exists "con sesion: borrar documentos" on storage.objects;
create policy "con sesion: ver documentos" on storage.objects for select to authenticated using (bucket_id = 'documentos');
create policy "con sesion: subir documentos" on storage.objects for insert to authenticated with check (bucket_id = 'documentos');
create policy "con sesion: borrar documentos" on storage.objects for delete to authenticated using (bucket_id = 'documentos');
