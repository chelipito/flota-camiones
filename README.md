# Control de Flota: horómetros, revisiones técnicas y arriendos

App web para una empresa que es **dueña de camiones y los arrienda** a otras empresas. Controla:
- qué camión está arrendado, a quién y hasta cuándo (contratos), para renegociar a tiempo;
- vencimientos de **revisiones técnicas**;
- **horómetro** (horas de motor) de cada camión vs. su límite, con la fecha estimada en que lo alcanza.

- **Prototipo publicado:** https://chelipito.github.io/flota-camiones/
- **Repositorio:** https://github.com/chelipito/flota-camiones
- **Brief:** `00-Ideas/flota-camiones.md` · **Diseño:** `02-Diseño/flota-camiones.md`

> Estado actual: **prototipo con datos de ejemplo** (versión 8). Todo se guarda en el navegador de cada persona y no hay base de datos todavía. El siguiente paso es conectar **Supabase**.

## Pantallas

| Perfil | Pantalla | Qué hace |
|---|---|---|
| Dueño | **Inicio** | Saludo, indicadores (flota, arrendados, disponibles, por revisar), "Requiere atención", contratos y ocupación |
| Dueño | **Flota** | Lista de camiones con filtro Todos / Arrendados / Disponibles. Detalle de cada camión |
| Dueño | **Contratos** | Lista de contratos (empresa, camiones, término, estado). El detalle incluye el administrador de contrato con llamar, WhatsApp y correo, y la **ficha descargable en Word o PDF** |
| Dueño | **Revisiones técnicas** | Lista ordenada por vencimiento |
| Dueño | **Horómetros** | Registros por validar (foto vs. número) y lista de horas vs. límite |
| Dueño | **Avisos** | Mensaje armado con todo lo que vence, para enviarlo por WhatsApp o correo |
| Dueño | **Usuarios y accesos** | Quién entra y con qué perfil (Dueño / Empleado / Cliente) |
| Dueño | **Configuración** | Empresa, contacto y cuántos días o qué % antes avisar |
| Empleado | **Mis camiones** | Registra el horómetro en 3 pasos (número → foto → confirmar). Funciona **sin señal** y envía al volver |
| Empleado | **WhatsApp (simulación)** | Escribe "KDLP21 7450" y el bot valida y registra |
| Cliente | **Mis camiones** | Ve sus camiones arrendados y la vigencia de su contrato (solo lectura) |

En la demo, la app abre en la vista del Dueño. Las otras vistas están en el menú → **"Ver como empleado o cliente"**.

## Reglas del horómetro
- La lectura nunca puede bajar respecto de la anterior.
- No puede subir más horas de las que pasaron desde la última lectura.
- Alerta "sin reporte" si un camión **arrendado** pasa más de X días sin registro (los disponibles no se exigen).
- Proyección: promedio de horas por día de los últimos 14 días. Con menos de 0,5 h por día no se proyecta.

## Datos de ejemplo
5 camiones, cada uno con un caso: revisión técnica vencida, disponible por vencer, horómetro al 96 %, 4 días sin reporte y uno al día. Hay 2 contratos (uno vence en 25 días). Los nombres, RUT, teléfonos y correos son **inventados**. El botón "Reiniciar datos de ejemplo" está en Configuración.

## Bitácora de decisiones

| Fecha | Decisión | Por qué |
|---|---|---|
| 2026-10-24 | Se vende a **una sola empresa**, no multi-cliente | Para no complicarse; a otra empresa se le instala una copia aparte |
| 2026-10-24 | Backend futuro en **Supabase** (no Firebase) | El usuario quiere aprenderlo; planea migrar todo a Supabase |
| 2026-10-24 | El server de la casa sirve solo para aprender y respaldar, no para el cliente | Cortes de luz o internet, seguridad, respaldos |
| 2026-10-24 | Colores corporativos **amarillo y negro**; "por vencer" en naranja | Pedido del cliente. El naranja evita confundir el amarillo de la marca con una alerta |
| 2026-10-24 | Botón **Volver** fijo arriba | Pedido del usuario |
| 2026-10-24 | El modelo de negocio es **arriendo**: se agregan contratos, ficha Word y perfiles Dueño / Empleado / Cliente | Aclarado por el usuario con una captura de referencia (layout tipo workspace con menú lateral) |
| 2026-10-24 | Registro por **WhatsApp** con patente + número (no modelo) | El modelo se repite en la flota; la patente es única |
| 2026-10-25 | La app abre directo en la vista del Dueño | El selector de perfiles escondía la interfaz principal |
| 2026-10-25 | **Colores neutros** y **listas de una fila** en vez de tarjetas | El usuario encontró la interfaz recargada |
| 2026-10-25 | Sin nombres personales en la app (el dueño de ejemplo se llama "Administración") | Pedido del usuario |
| 2026-10-25 | Celular: indicadores compactos en una sola fila | Pedido del usuario |

## Avisos automáticos (versión real)
- **Correo:** función programada en Supabase. Simple y barato.
- **WhatsApp automático y bot de registro:** API de WhatsApp Business (Meta). Requiere un número dedicado, verificar la empresa y tiene costo por mensaje (confirmar precios al implementar). Power Automate también es posible, pero igual necesita la API de WhatsApp.

## Pendientes
- [ ] Nombre y logo de la empresa cliente.
- [ ] ¿Los camiones tienen **GPS o telemetría** que entregue las horas de motor?
- [ ] Qué ve exactamente el **cliente** (por ejemplo, ¿ve una revisión técnica vencida?).
- [ ] ¿Un contrato puede incluir **varios camiones**? (el prototipo lo permite).
- [ ] **Límite real de horas** de cada camión y de dónde sale.
- [ ] Modelo de cobro (implementación + mensualidad, o por camión).
- [ ] Simplificar las pantallas de detalle (camión, contrato, cliente).
- [ ] Conectar **Supabase**: login, tablas, fotos, funciones programadas.

## Cómo publicar cambios
El código está en esta carpeta, conectada al repositorio de GitHub. Cada cambio se publica con `git add`, `git commit` y `git push`, y GitHub Pages lo actualiza en 1 o 2 minutos. La franja amarilla de la app muestra el número de versión, para comprobar que se ve la última.
