-- Control de Flota · borrar los datos de ejemplo para empezar con los datos reales del cliente
-- ⚠️ NO SE PUEDE DESHACER. Ejecútalo SOLO cuando el cliente vaya a empezar a usar la app (después de la demostración).
-- Cómo usarlo: Supabase → SQL Editor → pestaña nueva (+) → pega todo esto → Run.
-- Después: cierra y vuelve a abrir la app en cada equipo (computador y celulares) ANTES de editar algo,
-- para que ningún equipo vuelva a subir los datos viejos que tenga guardados.
--
-- Borra:     camiones, registros del horómetro, avisos enviados, contratos, mantenciones registradas
--            y validaciones de registros.
-- Mantiene:  las cuentas para entrar (usuarios), la configuración (nombre de la empresa, WhatsApp
--            que reciben avisos, alertas) y la conexión con WhatsApp.

delete from avisos_enviados;
delete from lecturas;
delete from camiones;

update estado_app
set datos = datos
      || jsonb_build_object(
           'camiones', '[]'::jsonb,
           'contratos', '[]'::jsonb,
           'estados', '{}'::jsonb,
           'usuarios', '[{"id": "u0", "nombre": "Administración", "rol": "dueno", "activo": true}]'::jsonb,
           '_v', 'limpio-' || extract(epoch from now())::bigint   -- versión nueva: los equipos abiertos toman los datos limpios
         ),
    actualizado = now()
where id = 1;

-- Revisar que quedó limpio (debe mostrar 0, 0, 0 y 0):
select (select count(*) from camiones) as camiones,
       (select count(*) from lecturas) as registros,
       (select count(*) from avisos_enviados) as avisos,
       (select jsonb_array_length(datos -> 'contratos') from estado_app where id = 1) as contratos;
