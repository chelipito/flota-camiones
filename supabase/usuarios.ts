// Control de Flota · función "usuarios" de Supabase (Edge Function)
// Permite crear, listar y quitar usuarios desde la app. Solo responde a quien ya inició sesión.
// Usa la clave secreta del servidor (SUPABASE_SERVICE_ROLE_KEY), que Supabase entrega sola y nunca va en la app.
import { createClient } from 'jsr:@supabase/supabase-js@2';

const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
};
const json = (cuerpo: unknown, status = 200) => new Response(JSON.stringify(cuerpo), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });

  // Quien llama debe tener una sesión válida
  const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  const { data: quien, error: errSesion } = await admin.auth.getUser(token);
  if (errSesion || !quien?.user) return json({ error: 'Debes iniciar sesión' }, 401);

  // Lista de usuarios con acceso
  if (req.method === 'GET') {
    const { data, error } = await admin.auth.admin.listUsers({ perPage: 100 });
    if (error) return json({ error: error.message }, 500);
    return json(data.users.map((u) => ({ id: u.id, correo: u.email, creado: u.created_at, ultimo: u.last_sign_in_at })));
  }

  // Crear un usuario (queda confirmado: puede entrar al tiro)
  if (req.method === 'POST') {
    const { correo, clave } = await req.json().catch(() => ({}));
    const email = String(correo ?? '').trim().toLowerCase();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return json({ error: 'Escribe un correo válido' }, 400);
    if (String(clave ?? '').length < 8) return json({ error: 'La contraseña debe tener al menos 8 caracteres' }, 400);
    const { error } = await admin.auth.admin.createUser({ email, password: String(clave), email_confirm: true });
    if (error) return json({ error: /already|registered|exists/i.test(error.message) ? 'Ya existe un usuario con ese correo' : error.message }, 400);
    return json({ ok: true });
  }

  // Quitar el acceso a un usuario (no a uno mismo)
  if (req.method === 'DELETE') {
    const id = new URL(req.url).searchParams.get('id') ?? '';
    if (!id) return json({ error: 'Falta el usuario' }, 400);
    if (id === quien.user.id) return json({ error: 'No puedes quitarte el acceso a ti mismo' }, 400);
    const { error } = await admin.auth.admin.deleteUser(id);
    if (error) return json({ error: error.message }, 400);
    return json({ ok: true });
  }

  return json({ error: 'Método no permitido' }, 405);
});
