// Control de Flota · función "avisos" de Supabase (Edge Function)
// Le manda un WhatsApp automático al dueño cuando la mantención (cada X horas), el límite de horas o la
// revisión técnica pasan a "por vencer", "urgente" o "atrasado/vencida". Cada aviso se manda una sola vez.
// La llaman: la función "whatsapp" al recibir un registro, la app (registros, cambios y "Revisar ahora")
// y una tarea programada de Supabase que la llama cada hora (supabase/avisos-diarios.sql); solo trabaja a la hora elegida.
// Configuración → Alertas → "Cómo te llegan los avisos": aviso al momento (sí/no), resumen (nunca, diario o semanal) y hora.
// Usa los mismos secretos que la función "whatsapp" (WHATSAPP_TOKEN y WHATSAPP_PHONE_ID).
import { createClient } from 'jsr:@supabase/supabase-js@2';

const SERVICIO = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const db = createClient(Deno.env.get('SUPABASE_URL')!, SERVICIO);
const TOKEN = Deno.env.get('WHATSAPP_TOKEN') ?? '';
const PHONE_ID = Deno.env.get('WHATSAPP_PHONE_ID') ?? '';
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (cuerpo: unknown, status = 200) => new Response(JSON.stringify(cuerpo), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });
const DIA = 86400000;
const n1 = (v: number) => v.toLocaleString('es-CL', { maximumFractionDigits: 1 });
const n0 = (v: number) => Math.round(v).toLocaleString('es-CL');
// Fecha de hoy en Chile (AAAA-MM-DD) y días hasta otra fecha AAAA-MM-DD
const hoyChile = () => new Date().toLocaleDateString('en-CA', { timeZone: 'America/Santiago' });
const utc = (iso: string) => { const [a, m, d] = iso.split('-').map(Number); return Date.UTC(a, m - 1, d); };
const diasHasta = (iso: string) => Math.round((utc(iso) - utc(hoyChile())) / DIA);
const fecha = (ms: number) => new Date(ms).toLocaleDateString('es-CL', { day: '2-digit', month: '2-digit', year: 'numeric', timeZone: 'America/Santiago' });

// Envía un aviso por WhatsApp. Va SIEMPRE con la plantilla aprobada "alerta_flota" (Español (Chile), una variable
// con el texto del aviso): llega aunque la persona nunca haya escrito al número. Un texto normal, en cambio, Meta lo
// acepta ("OK") pero lo descarta en silencio si la persona no escribió en las últimas 24 h. Si la plantilla falla
// (p. ej. aún no aprobada), se intenta como texto normal.
async function enviarWsp(a: string, texto: string) {
  const url = `https://graph.facebook.com/v25.0/${PHONE_ID}/messages`;
  const headers = { Authorization: `Bearer ${TOKEN}`, 'Content-Type': 'application/json' };
  const r = await fetch(url, { method: 'POST', headers, body: JSON.stringify({ messaging_product: 'whatsapp', to: a, type: 'template',
    template: { name: 'alerta_flota', language: { code: 'es_CL' }, components: [{ type: 'body', parameters: [{ type: 'text', text: texto.replace(/\s*\n+\s*/g, ' · ').slice(0, 900) }] }] } }) }); // la plantilla admite ~1.000 caracteres
  if (r.ok) return { ok: true };
  const error = await r.text();
  const r2 = await fetch(url, { method: 'POST', headers, body: JSON.stringify({ messaging_product: 'whatsapp', to: a, type: 'text', text: { body: texto } }) });
  if (r2.ok) return { ok: true };
  console.error('No se pudo enviar el aviso', a, error, await r2.text());
  return { ok: false, error };
}

// Mismo cálculo que la app: promedio de horas por día de los últimos 14 días
function promedio(ls: { valor: number; fecha: number }[]) {
  if (ls.length < 2) return 0;
  const rec = ls.filter((l) => l.fecha >= Date.now() - 14 * DIA);
  const a = rec.length ? ls[Math.max(0, ls.indexOf(rec[0]) - 1)] : ls[0], b = ls[ls.length - 1];
  return (b.valor - a.valor) / Math.max(1, (b.fecha - a.fecha) / DIA);
}

function revisar(cam: any, ls: { valor: number; fecha: number }[], ficha: any, cfg: any) {
  const actual = ls.length ? ls[ls.length - 1].valor : 0, prom = promedio(ls);
  const iv = cfg.intervaloMant ?? 250, mants = ficha?.mantenciones ?? [];
  // sin mantención registrada se estima según la primera lectura: si pasa la próxima y nadie la registra, queda atrasada
  const base = mants.length ? mants[mants.length - 1].valor : Math.floor((ls.length ? ls[0].valor : actual) / iv) * iv;
  const prox = base + iv, resta = prox - actual;
  const em = resta <= 0 ? 'vencido' : resta <= (cfg.horasMantUrgente ?? 10) ? 'urgente' : resta <= (cfg.horasMantAviso ?? 25) ? 'porvencer' : 'ok';
  const cuando = resta > 0 && prom >= 0.5 ? ` (aprox. el ${fecha(Date.now() + Math.ceil(resta / prom) * DIA)})` : '';
  const nombre = `${cam.patente}${ficha?.tipo ? ` (${ficha.tipo})` : ''}`;
  const ETQ: Record<string, string> = { porvencer: '🟡 Por vencer', urgente: '🔴 Urgente', vencido: '🔴 Atrasada' };
  const avisos = [];
  if (em !== 'ok') avisos.push({ clave: `${cam.patente}|mantencion|${prox}|${em}`,
    texto: `${ETQ[em]} · Mantención\n${nombre}: ${resta > 0 ? `faltan ${n0(resta)} h` : `atrasada ${n0(-resta)} h`} para la mantención de las ${n0(prox)} h${cuando}.\nHorómetro actual: ${n1(actual)} h.` });
  const pct = (actual / Number(cam.limite)) * 100;
  const el = pct >= 100 ? 'vencido' : pct >= (cfg.pctUrgente ?? 95) ? 'urgente' : pct >= (cfg.pctAviso ?? 80) ? 'porvencer' : 'ok';
  if (el !== 'ok') avisos.push({ clave: `${cam.patente}|limite|${el}`,
    texto: `${el === 'vencido' ? '🔴 Superado' : ETQ[el]} · Límite de horas\n${nombre}: ${n1(actual)} de ${n0(Number(cam.limite))} h (${Math.floor(pct)}% del límite).` });
  // Revisión técnica: depende de la fecha guardada en la ficha del camión
  if (ficha?.rtVence) {
    const d = diasHasta(ficha.rtVence), vence = fecha(utc(ficha.rtVence) + 12 * 3600000);
    const er = d <= 0 ? 'vencido' : d <= (cfg.diasUrgente ?? 7) ? 'urgente' : d <= (cfg.diasPorVencer ?? 30) ? 'porvencer' : 'ok';
    if (er !== 'ok') avisos.push({ clave: `${cam.patente}|rt|${ficha.rtVence}|${er}`,
      texto: `${er === 'vencido' ? '🔴 Vencida' : ETQ[er]} · Revisión técnica\n${nombre}: ${d < 0 ? `venció el ${vence} (hace ${-d} ${d === -1 ? 'día' : 'días'})` : d === 0 ? `vence hoy (${vence})` : `vence el ${vence} (en ${d} ${d === 1 ? 'día' : 'días'})`}.` });
  }
  const resumen = resta > 0 ? `Faltan ${n0(resta)} h para la mantención de las ${n0(prox)} h${cuando}.` : `⚠️ Mantención atrasada ${n0(-resta)} h (tocaba a las ${n0(prox)} h).`;
  return { avisos, resumen };
}
// "🟡 Por vencer · Mantención\nHKTZ48: faltan…" → "🟡 HKTZ48: faltan…" (para el resumen)
const lineaCorta = (texto: string) => `${texto.split(' ')[0]} ${texto.split('\n')[1] ?? ''}`;
const DIAS_SEMANA = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });

  const { patente, prueba } = await req.json().catch(() => ({}));
  // La revisión de todos los camiones (tarea diaria) no necesita sesión: solo manda avisos que ya corresponden,
  // una sola vez cada uno. El aviso de prueba y el resumen de un camión sí: función "whatsapp" (clave del servidor) o usuario con sesión.
  const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  let conSesion = token === SERVICIO;
  if (!conSesion && token) { const { data } = await db.auth.getUser(token); conSesion = !!data?.user; }
  if ((prueba || patente) && !conSesion) return json({ error: 'Debes iniciar sesión' }, 401);

  const { data: est } = await db.from('estado_app').select('datos').eq('id', 1).maybeSingle();
  const datos = est?.datos ?? {}, cfg = datos.config ?? {};
  // Revisión programada (corre cada hora, sin sesión): solo trabaja a la hora elegida en Configuración
  const horaChile = Number(new Date().toLocaleString('en-US', { hour: 'numeric', hour12: false, timeZone: 'America/Santiago' })) % 24;
  if (!conSesion && !patente && !prueba && horaChile !== Number(cfg.horaAvisos ?? 9)) return json({ enviados: 0, hora: horaChile });
  const destinos = String(cfg.wsp ?? '').split(/[,;]/).map((x) => x.replace(/\D/g, '')).filter((x) => x.length >= 8);

  // Aviso de prueba desde la app (Avisos → Enviar aviso de prueba)
  if (prueba) {
    if (!destinos.length) return json({ error: 'Falta el WhatsApp que recibe los avisos (en Configuración)' }, 400);
    const rs = await Promise.all(destinos.map((d) => enviarWsp(d, `✅ Prueba de avisos de ${cfg.empresa ?? 'Control de Flota'}.\nAsí te van a llegar los avisos automáticos del horómetro y la mantención.`)));
    const fallo = rs.find((r) => !r.ok);
    return fallo ? json({ error: 'WhatsApp no aceptó el mensaje. Revisa que el número esté en la lista "Para" de Meta y que haya escrito al número de la app en las últimas 24 h.' }, 502) : json({ ok: true });
  }

  let q = db.from('camiones').select('patente, limite');
  if (patente) q = q.eq('patente', patente);
  const { data: camiones } = await q;
  let enviados = 0, resumen = '';
  const pendientes: string[] = [];
  for (const cam of camiones ?? []) {
    const { data: filas } = await db.from('lecturas').select('valor, fecha').eq('patente', cam.patente).order('fecha', { ascending: true });
    const ls = (filas ?? []).map((f) => ({ valor: Number(f.valor), fecha: Date.parse(f.fecha) }));
    const ficha = (datos.camiones ?? []).find((c: any) => c.patente === cam.patente);
    const r = revisar(cam, ls, ficha, cfg);
    if (patente) resumen = r.resumen;
    pendientes.push(...r.avisos.map((a) => lineaCorta(a.texto)));
    // Sin reporte: camión arrendado sin registros hace más de X días
    if (ficha?.contratoId && ls.length) {
      const sin = Math.floor((Date.now() - ls[ls.length - 1].fecha) / DIA);
      if (sin > (cfg.diasSinReporte ?? 2)) pendientes.push(`⚪ ${cam.patente}: ${sin} días sin registrar el horómetro.`);
    }
    if (!destinos.length || cfg.avisoInmediato === false) continue; // aviso al momento apagado en Configuración
    for (const a of r.avisos) {
      // Se anota antes de enviar: si dos registros llegan juntos, el aviso igual sale una sola vez
      const { error } = await db.from('avisos_enviados').insert({ clave: a.clave, detalle: a.texto });
      if (error) continue; // ya se había enviado
      const rs = await Promise.all(destinos.map((d) => enviarWsp(d, a.texto)));
      if (rs.some((x) => x.ok)) enviados++;
      else await db.from('avisos_enviados').delete().eq('clave', a.clave); // no salió: se reintenta en el próximo registro
    }
  }

  // Resumen programado (solo en la revisión diaria, a la hora elegida): todos los días o una vez por semana
  const hoySemana = DIAS_SEMANA.indexOf(new Date().toLocaleDateString('en-US', { weekday: 'short', timeZone: 'America/Santiago' }));
  const tocaResumen = cfg.resumenFrec === 'diario' || (cfg.resumenFrec === 'semanal' && Number(cfg.resumenDia ?? 1) === hoySemana);
  if (!conSesion && !patente && tocaResumen && destinos.length) {
    (datos.contratos ?? []).forEach((k: any) => {
      const d = k.termino ? diasHasta(k.termino) : 999;
      if (d <= (cfg.diasContratoAviso ?? 60)) pendientes.push(`${d <= (cfg.diasContratoUrgente ?? 15) ? '🔴' : '🟡'} Contrato ${k.empresa}: ${d < 0 ? 'terminó' : `termina en ${d} ${d === 1 ? 'día' : 'días'}`}.`);
    });
    const clave = `resumen|${hoyChile()}`;
    const texto = `📋 Resumen ${cfg.empresa ?? 'Control de Flota'} · ${fecha(Date.now())}\n` +
      (pendientes.length ? `${pendientes.length} ${pendientes.length === 1 ? 'pendiente' : 'pendientes'}:\n${pendientes.join('\n')}` : '✅ Todo al día.');
    const { error } = await db.from('avisos_enviados').insert({ clave, detalle: texto });
    if (!error) {
      const rs = await Promise.all(destinos.map((d) => enviarWsp(d, texto)));
      if (rs.some((x) => x.ok)) enviados++; else await db.from('avisos_enviados').delete().eq('clave', clave);
    }
  }
  return json(conSesion ? { resumen, enviados, sinDestino: !destinos.length } : { enviados });
});
