-- Control de Flota · revisión automática de avisos todos los días a las 9:00 (hora de Chile)
-- Cómo usarlo: Supabase → SQL Editor → pestaña nueva (+) → pega todo esto → Run. Se ejecuta una sola vez.
-- Llama a la función "avisos", que revisa la revisión técnica (y también mantención y límite) de todos los camiones
-- y manda por WhatsApp lo que corresponda. Cada aviso llega una sola vez.

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- 12:00 UTC = 9:00 en Chile con horario de verano (8:00 en invierno)
select cron.schedule(
  'avisos-diarios',
  '0 12 * * *',
  $$
  select net.http_post(
    url := 'https://fclxmlzzskweqwhnpfkq.supabase.co/functions/v1/avisos',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb
  );
  $$
);

-- Para ver la tarea:   select jobname, schedule from cron.job;
-- Para quitarla:       select cron.unschedule('avisos-diarios');
