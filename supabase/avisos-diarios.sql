-- Control de Flota · revisión automática de avisos a la hora que elige el dueño (Configuración → Alertas)
-- Cómo usarlo: Supabase → SQL Editor → pestaña nueva (+) → pega todo esto → Run.
-- Si ya lo habías ejecutado, ejecútalo de nuevo: reemplaza la tarea anterior.
-- Llama cada hora a la función "avisos"; la función solo manda avisos y el resumen a la hora elegida en la app.

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Quita la tarea anterior (si existe) y la crea de nuevo: minuto 0 de cada hora
select cron.unschedule(jobid) from cron.job where jobname = 'avisos-diarios';
select cron.schedule(
  'avisos-diarios',
  '0 * * * *',
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
