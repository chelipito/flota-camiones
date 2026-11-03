// Control de Flota · función "whatsapp" de Supabase (Edge Function)
// Recibe los mensajes que llegan al número de WhatsApp (Meta), valida el horómetro,
// lo guarda en la tabla "lecturas" y responde por WhatsApp.
//
// Secretos que hay que crear en Supabase (Edge Functions → Secrets):
//   WHATSAPP_VERIFY_TOKEN  palabra secreta inventada; la misma se pone en Meta al configurar el webhook
//   WHATSAPP_TOKEN         token de acceso de Meta (WhatsApp → API Setup)
//   WHATSAPP_PHONE_ID      "Phone number ID" del número de prueba de Meta
// SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY los entrega Supabase solo.
import { createClient } from 'jsr:@supabase/supabase-js@2';

const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
const VERIFY_TOKEN = Deno.env.get('WHATSAPP_VERIFY_TOKEN') ?? '';
const TOKEN = Deno.env.get('WHATSAPP_TOKEN') ?? '';
const PHONE_ID = Deno.env.get('WHATSAPP_PHONE_ID') ?? '';

const n1 = (v: number) => v.toLocaleString('es-CL', { maximumFractionDigits: 1 });
const n0 = (v: number) => Math.round(v).toLocaleString('es-CL');

// Mismas reglas que la app: "7.450" o "7 450" = 7450; "7450,5" o "7450.5" = 7450,5
function leerNumero(txt: string) {
  const s = txt.trim().replace(/\s/g, '');
  if (/^\d+\.\d$/.test(s)) return Number(s);
  return Number(s.replace(/\./g, '').replace(',', '.'));
}

// Acepta "HKTZ48 7450", "HKTZ-48 7.450 h" o solo "7450" (si hay un solo camión)
function leerMensaje(txt: string) {
  const m = txt.trim().toUpperCase().match(/^(?:([A-Z]{2,4}-?\d{2,4})\s+)?(\d[\d.,\s]*?)\s*(?:H|HRS|HORAS)?\.?$/);
  return m ? { patente: m[1]?.replace('-', ''), valor: leerNumero(m[2]) } : null;
}

async function responder(a: string, texto: string) {
  if (!TOKEN || !PHONE_ID) return;
  const r = await fetch(`https://graph.facebook.com/v25.0/${PHONE_ID}/messages`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${TOKEN}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ messaging_product: 'whatsapp', to: a, type: 'text', text: { body: texto } }),
  });
  if (!r.ok) console.error('No se pudo responder por WhatsApp', r.status, await r.text()); // p. ej. token vencido: el registro igual queda guardado
}

async function procesar(msg: any, nombre: string) {
  const de = msg.from;
  const ayuda = 'Para registrar el horómetro escribe la patente y el número. Ejemplo: HKTZ48 7450';
  if (msg.type !== 'text') return responder(de, '📷 Por ahora solo recibo texto. ' + ayuda);
  const leido = leerMensaje(msg.text.body);
  if (!leido || isNaN(leido.valor) || leido.valor <= 0) return responder(de, ayuda);

  const { data: camiones } = await db.from('camiones').select('patente, limite');
  let cam = leido.patente ? camiones?.find((c) => c.patente === leido.patente) : camiones?.length === 1 ? camiones[0] : null;
  if (!cam) return responder(de, leido.patente ? `No encuentro la patente ${leido.patente}. ${ayuda}` : ayuda);

  const { data: ult } = await db.from('lecturas').select('valor, fecha').eq('patente', cam.patente).order('fecha', { ascending: false }).limit(1).maybeSingle();
  const v = leido.valor;
  if (ult && v < Number(ult.valor)) return responder(de, `❌ ${v} es menor que la última lectura (${n1(Number(ult.valor))} h). El horómetro nunca baja: revisa el número.`);
  if (ult) {
    const pasaron = (Date.now() - Date.parse(ult.fecha)) / 3600000;
    if (v - Number(ult.valor) > pasaron + 0.5) return responder(de, `❌ Son ${n1(v - Number(ult.valor))} horas más que la última vez, pero solo han pasado ${n1(pasaron)} horas. Revisa el número.`);
  }

  const { error } = await db.from('lecturas').insert({ patente: cam.patente, valor: v, origen: 'whatsapp', nombre, telefono: de, wamid: msg.id });
  if (error?.code === '23505') return; // Meta reenvió el mismo mensaje: ya estaba guardado
  if (error) { console.error(error); return responder(de, '⚠️ No pude guardar el registro. Intenta de nuevo en un momento.'); }

  const resta = Number(cam.limite) - v;
  await responder(de, `✅ Registrado ${cam.patente}: ${n1(v)} h.\n${resta > 0 ? `Le quedan ${n0(resta)} h para el límite de ${n0(Number(cam.limite))} h.` : '⚠️ Superó el límite de horas.'}`);
}

Deno.serve(async (req) => {
  // 1) Meta verifica el webhook una vez, al configurarlo
  if (req.method === 'GET') {
    const u = new URL(req.url);
    if (u.searchParams.get('hub.mode') === 'subscribe' && u.searchParams.get('hub.verify_token') === VERIFY_TOKEN) {
      return new Response(u.searchParams.get('hub.challenge') ?? '', { status: 200 });
    }
    return new Response('Token incorrecto', { status: 403 });
  }
  // 2) Mensajes entrantes. Siempre se responde 200 para que Meta no reintente.
  try {
    const body = await req.json();
    const valor = body?.entry?.[0]?.changes?.[0]?.value;
    const nombre = valor?.contacts?.[0]?.profile?.name ?? 'WhatsApp';
    for (const msg of valor?.messages ?? []) await procesar(msg, nombre);
  } catch (e) {
    console.error(e);
  }
  return new Response('ok', { status: 200 });
});
