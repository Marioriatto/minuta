# Backlog — Colchón Minuta

> Fuente: `SRS.pdf` (15-oct-2026) §3.1–3.3 y `Refinamiento del Backlog - Requisitos.csv`.
> Las historias con ID del SRS conservan su texto, prioridad y estimación (puntos de historia).
> Las marcadas **(derivada)** cubren requisitos del SRS que no tenían historia propia; su prioridad
> sale del CSV y su estimación es una propuesta.
> **Estado** describe el repo al 2026-11-19. Decisión de alcance vigente: el prototipo usa Arduino UNO
> por USB + puente Python, **sin Wi-Fi** (ver `CLAUDE.md` §2).

Prioridad Jira: Alta → High · Media → Medium · Baja → Low.

**Cargado en Jira (2026-11-19):** proyecto **CM** «Colchón Minuta» (Scrum, team-managed) en
`marioriatto.atlassian.net`. Épicas CM-1 a CM-10 (E1–E10 en orden), historias CM-11 a CM-42 en el orden
de este documento, con su prioridad, «Story point estimate» y etiquetas (`srs`/`derivada`, RF-xx), y
subtareas CM-43 a CM-117. Si cambias algo, actualízalo en Jira: este archivo es la foto inicial.

| Épica | Historias | Puntos |
|---|---|---|
| E1 Plataforma y datos | DB-002 | 5 |
| E2 Cuenta y perfiles | APP-015, DB-001 | 11 |
| E3 Notificaciones y alertas | APP-001, APP-008, APP-009 | 9 |
| E4 Ampliaciones | APP-003, APP-014 | 13 |
| E5 Colchón | COL-001, APP-010 | 13 |
| E6 Cuna, audio y luces | CUNA-006, CUNA-004, CUNA-005, CUNA-001, APP-011, CUNA-003, CUNA-002 | 26 |
| E7 Dashboard, registros y exportación | APP-005, APP-002, APP-004 | 15 |
| E8 Alimentación | ALI-001, APP-012, APP-006, APP-007 | 14 |
| E9 Juguete interactivo | JUG-001, JUG-002, JUG-003, JUG-004 | 13 |
| E10 Sistema de habitación | HAB-002, HAB-003, HAB-001, APP-013 | 20 |
| **Total** | **32 historias** (24 del SRS + 8 derivadas) | **139** |

---

## E1 — Plataforma y datos
Base de datos relacional remota (Supabase) y canal de ingesta desde el hardware.
Requisitos: RF-01, RF-02 · RNF-02, RNF-04.

### DB-002 — Base de datos remota y registro de actividades (derivada)
- **Historia:** Como Usuario, quiero que los datos y actividades que detectan las ampliaciones se guarden en una base de datos remota para consultarlos desde cualquier lugar.
- **Criterios de aceptación:**
  - Existe una base de datos relacional hosteada en la nube (Supabase) con RLS activo.
  - Cada actividad detectada se guarda con fecha, hora, tipo de actividad, descripción y ampliación de origen.
  - Un módulo solo puede escribir con su propio token; un usuario solo ve sus propios datos.
  - El canal de ingesta acepta telemetría cada 10 s de al menos 100 dispositivos sin degradación (RNF-02).
- **Prioridad:** Alta · **Estimación:** 5 · **Trazabilidad:** RF-01, RF-02, RNF-02, RNF-04
- **Estado:** Hecho en su mayoría (tablas, RLS, Edge Function `device`, `device_ingest`). Edge Function probada: responde 409 hasta vincular módulos.
- **Tareas:**
  1. Versionar la migración inicial (`init.sql`) en `supabase/migrations`.
  2. Revocar el `UPDATE` directo sobre `devices.config` y `devices.name`.
  3. Prueba de punta a punta: puente simulado → `/ingest` → filas en `events` y lecturas.
  4. Prueba de carga simple: 100 dispositivos simulados enviando cada 10 s.

---

## E2 — Cuenta y perfiles
Acceso a la app y perfiles de bebé que clasifican todos los datos.
Requisitos: RF-04.

### APP-015 — Acceso con correo o Google (derivada)
- **Historia:** Como Usuario, quiero registrarme e iniciar sesión con mi correo o con mi cuenta de Google para entrar rápido y de forma segura a la app.
- **Criterios de aceptación:**
  - Puedo crear una cuenta con correo y contraseña (mínimo 8 caracteres) y debo confirmar el correo.
  - En las pantallas de inicio de sesión y de registro aparece "Continuar con Google"; la primera vez crea la cuenta y las siguientes inicia sesión.
  - Al terminar el login en el navegador, la app se abre sola (deep link `com.colchonminuta.app://login-callback`).
  - Puedo recuperar la contraseña por correo y cerrar sesión desde Ajustes.
  - Los errores (credenciales, correo sin confirmar, sin red) se muestran con un mensaje claro.
- **Prioridad:** Alta · **Estimación:** 5 · **Trazabilidad:** fuera del SRS (requisito de soporte para RF-04)
- **Estado:** Hecho en código. Falta configurar Google Cloud (cliente Web) + proveedor en Supabase y probar en el teléfono.
- **Tareas:**
  1. Crear cliente OAuth Web en Google Cloud y activar el proveedor Google en Supabase.
  2. Agregar la Redirect URL de la app en Supabase y activar `SOCIAL_LOGIN`.
  3. Probar registro e inicio con Google en Android.
  4. Activar *leaked password protection* en Supabase.

### DB-001 — Perfil de bebé
- **Historia:** Como Usuario, quiero tener registrado un perfil por cada bebé que use la cuna para clasificar los datos que registra la cuna según el bebé que la use.
- **Criterios de aceptación (SRS):** Los datos de bebé que registra y presenta la app en todas las secciones corresponden al perfil del bebé. Es posible agregar, modificar o eliminar perfiles.
- **Criterios refinados:**
  - El perfil guarda nombre, fecha de nacimiento (la edad se calcula) y peso.
  - El peso no se escribe a mano: lo mide el colchón con "Pesar ahora" (ver COL-001).
  - Hay un perfil activo; no se puede archivar el último perfil activo.
  - Los perfiles archivados se pueden restaurar o eliminar definitivamente (con aviso de que se borra su historial).
- **Prioridad:** Media · **Estimación:** 6 · **Trazabilidad:** RF-04
- **Estado:** Hecho (Fase 2) y con tests; pendiente validación del usuario.
- **Tareas:**
  1. Validar el flujo de perfiles con el usuario en el teléfono.
  2. Asociar cada evento/lectura al perfil activo (`fill_device_context`).
  3. Verificar el borrado en cascada del historial al eliminar un perfil.

---

## E3 — Notificaciones y alertas
Notificaciones push nativas y su listado en la app.
Requisitos: RF-03, RF-13, RF-14, RF-18 · RNF-01.

### APP-001 — Recibir notificaciones de alertas
- **Historia:** Como Usuario, quiero recibir notificaciones de eventos importantes en mi teléfono para estar al pendiente del estado y bienestar de mi bebé.
- **Criterios de aceptación (SRS):** La app recibe y notifica alertas en tiempo real, luego las lista en una sección designada para ello.
- **Criterios refinados:**
  - Las alertas llegan como notificación nativa aunque la app esté cerrada.
  - Entre el evento en el hardware y la notificación pasan ≤ 3 s en condiciones normales (RNF-01).
  - La sección "Alertas" lista cada alerta con fecha, hora, tipo y descripción, de la más reciente a la más antigua.
  - Tocar la notificación abre la alerta en la app.
- **Prioridad:** Alta · **Estimación:** 3 · **Trazabilidad:** RF-03, RNF-01
- **Estado:** Pendiente (las alertas ya se crean en la base con `create_alert_from_event`; falta el push).
- **Tareas:**
  1. Integrar Firebase Cloud Messaging en la app y guardar el token del dispositivo.
  2. Edge Function + webhook que envía el push al crearse una alerta.
  3. Pantalla "Alertas" con lista, estados vacío/error/offline.
  4. Medir la latencia evento → notificación.

### APP-008 — Alertas de movimiento
- **Historia:** Como Usuario, quiero recibir notificaciones de alerta cuando el bebé se mueve o se deja de detectar durante el periodo de detección para saber de la actividad y seguridad del bebé.
- **Criterios de aceptación (SRS):** La app manda notificaciones acorde al tipo de movimiento detectado por el colchón o el juguete.
- **Criterios refinados:**
  - Movimiento y ausencia solo generan alerta con el periodo de detección activo (APP-010).
  - El texto distingue "movimiento" de "ausencia" y la ampliación de origen.
- **Prioridad:** Media · **Estimación:** 3 · **Trazabilidad:** RF-13, RF-14, RF-30
- **Estado:** Parcial: el puente ya genera `movement` / `absence`; falta el push (APP-001).
- **Tareas:**
  1. Mapear eventos `movement` / `absence` a alertas con textos propios.
  2. Probar con el colchón real: mover y retirar peso durante un periodo activo.

### APP-009 — Alertas de temperatura y humedad
- **Historia:** Como Usuario, quiero recibir notificaciones de alerta cuando la temperatura o humedad superan un umbral modificable para arreglar el entorno del bebé y así duerma bien.
- **Criterios de aceptación (SRS):** La app manda notificaciones siempre que se supere el umbral establecido.
- **Criterios refinados:**
  - Se genera una alerta al salir del rango configurado (mínimo o máximo).
  - No se repite la alerta en cada lectura mientras siga fuera de rango.
- **Prioridad:** Media · **Estimación:** 3 · **Trazabilidad:** RF-18
- **Estado:** Parcial: trigger `evaluate_thresholds` hecho; falta el push (APP-001).
- **Tareas:**
  1. Verificar `evaluate_thresholds` con lecturas simuladas fuera de rango.
  2. Evitar alertas repetidas mientras el valor siga fuera de rango.

---

## E4 — Ampliaciones
Vincular módulos comprados y darles valores de fábrica.
Requisitos: RF-06, RF-07, RF-08.

### APP-003 — Registro de ampliaciones
- **Historia:** Como Usuario, quiero conectar a la app las ampliaciones que compre para usarlas en conjunto.
- **Criterios de aceptación (SRS):** La app registra cada ampliación y permite usar todas sus funcionalidades.
- **Criterios refinados:**
  - Vinculo una ampliación con el código de 16 caracteres impreso en el módulo; el código es de un solo uso.
  - La sección "Ampliaciones" lista los módulos vinculados con su estado (en línea / sin conexión).
  - Cada módulo abre su pantalla con sus controles (RF-08).
- **Prioridad:** Alta · **Estimación:** 10 · **Trazabilidad:** RF-06, RF-08
- **Estado:** Hecho para colchón, cuna y luces. Falta vincular los módulos reales y probar.
- **Tareas:**
  1. Generar los claim codes con `provision_device` y vincular los 3 módulos.
  2. Repetir la simulación del puente y confirmar respuestas 200.
  3. Desvincular un módulo (revocar su token).

### APP-014 — Valores predeterminados de ampliaciones
- **Historia:** Como Usuario, quiero contar con valores de fábrica predeterminados al configurar cualquier ampliación para utilizar las funciones de las ampliaciones sin necesidad de configuraciones iniciales complejas.
- **Criterios de aceptación (SRS):** Las ampliaciones registradas inician con valores de configuración predeterminados funcionales.
- **Prioridad:** Baja · **Estimación:** 3 · **Trazabilidad:** RF-07
- **Estado:** Hecho para luces; pendiente para cuna (umbrales) y módulos futuros.
- **Tareas:**
  1. Definir `default_config` de cuna (umbrales recomendados).
  2. Botón "Restablecer valores de fábrica" en cada ampliación.

---

## E5 — Colchón
Balanza, presencia y periodo de detección.
Requisitos: RF-11, RF-12, RF-13, RF-14 · RNF-05.

### COL-001 — Balanza del colchón (derivada)
- **Historia:** Como Usuario, quiero que el colchón mida el peso de mi bebé para registrarlo en su perfil sin escribirlo a mano.
- **Criterios de aceptación:**
  - El colchón reporta el peso cada 2 s con precisión de ±50 g tras calibrar.
  - "Pesar ahora" guarda en el perfil el peso actual del colchón.
  - Si el colchón no está vinculado, está fuera de línea o vacío (< 1 kg), la app lo explica.
  - Se puede calibrar con un peso conocido y tarar desde la app.
- **Prioridad:** Alta · **Estimación:** 5 · **Trazabilidad:** RF-11
- **Estado:** Hecho en código (HX711, puente, `weigh_baby`); sin probar con hardware.
- **Tareas:**
  1. Armar las 4 celdas de carga + HX711 y calibrar.
  2. Probar "Pesar ahora" con el colchón real.
  3. Botón "Tarar" en la pantalla del colchón.

### APP-010 — Periodo de detección del bebé
- **Historia:** Como Usuario, quiero establecer un periodo en el que dejo al bebé en el colchón desde la app para que el sistema y las ampliaciones activen sus funcionalidades.
- **Criterios de aceptación (SRS):** La app activa las funcionalidades de las ampliaciones del sistema registradas.
- **Criterios refinados:**
  - Puedo iniciar y detener el periodo desde la app, y ver si está activo.
  - Durante el periodo se generan alertas de movimiento y ausencia; fuera de él, no.
  - El periodo se guarda en la base con inicio y fin.
- **Prioridad:** Alta · **Estimación:** 8 · **Trazabilidad:** RF-12
- **Estado:** Pendiente (el puente ya respeta "periodo abierto"; falta la app).
- **Tareas:**
  1. Tabla / RPC de periodos de detección (iniciar, detener).
  2. Enviar el estado del periodo al puente por `poll`.
  3. Controles en la app y estado visible en Inicio.
  4. Tests de dominio y de widget.

---

## E6 — Cuna, audio y luces
Requisitos: RF-15 a RF-22.

### CUNA-006 — Fuente de energía de la cuna (derivada)
- **Historia:** Como Usuario, quiero que la cuna alimente al colchón desde un solo enchufe para no tener cables sueltos dentro de la cuna.
- **Criterios de aceptación:**
  - La cuna tiene un adaptador para conectar el colchón y un enchufe al tomacorriente.
  - Los componentes eléctricos tienen aislamiento térmico y protección contra sobrecargas (SRS §2.4).
- **Prioridad:** Alta · **Estimación:** 2 · **Trazabilidad:** RF-15
- **Estado:** Pendiente (hardware).
- **Tareas:**
  1. Diseñar la conexión de energía y elegir el adaptador.
  2. Revisar el aislamiento y la protección contra sobrecarga.

### CUNA-004 — Medir temperatura y humedad de la cuna (derivada)
- **Historia:** Como Usuario, quiero ver la temperatura y humedad del entorno de la cuna para saber si mi bebé está cómodo.
- **Criterios de aceptación:**
  - La cuna mide temperatura (°C) y humedad (%) y la app muestra el valor actual.
  - Si la cuna está sin conexión, la app lo indica en vez de mostrar datos viejos como actuales.
- **Prioridad:** Alta · **Estimación:** 3 · **Trazabilidad:** RF-16, RF-17
- **Estado:** Hecho en código (AHT20, puente, `cradle_page`); sin probar con hardware.
- **Tareas:**
  1. Conectar el AHT20 y verificar lecturas reales.
  2. Probar el estado "sin conexión" en la app.

### CUNA-005 — Configurar umbrales de temperatura y humedad (derivada)
- **Historia:** Como Usuario, quiero definir los rangos aceptables de temperatura y humedad para que la app me avise cuando el entorno no sea adecuado.
- **Criterios de aceptación:**
  - En la pantalla de la cuna configuro mínimo y máximo de temperatura y humedad (cada uno opcional).
  - El servidor rechaza rangos inválidos (mínimo ≥ máximo o fuera de límites).
  - El valor actual se marca como bajo / normal / alto según el rango.
- **Prioridad:** Media · **Estimación:** 3 · **Trazabilidad:** RF-18
- **Estado:** Hecho (`set_thresholds`, `ThresholdsValidator`).
- **Tareas:**
  1. Probar en el teléfono con la cuna real.

### CUNA-001 — Regulación de intensidad de luces de la cuna
- **Historia:** Como Usuario, quiero usar un widget en la app móvil para cambiar la intensidad de las luces de la cuna del bebé según vea conveniente.
- **Criterios de aceptación (SRS):** La intensidad de las luces responden a la entrada del widget de la app.
- **Criterios refinados:** El brillo va de 0 a 100 % y los LED responden en ≤ 3 s.
- **Prioridad:** Media · **Estimación:** 2 · **Trazabilidad:** RF-20
- **Estado:** Hecho en código (slider, `set_lights`, PWM); sin probar con hardware.
- **Tareas:**
  1. Armar los 4 LED PWM y probar el slider de punta a punta.

### APP-011 — Velocidad del sistema de luces
- **Historia:** Como Usuario, quiero usar un slider del sistema de luces en la app para cambiar la velocidad.
- **Criterios de aceptación (SRS):** El sistema de luces cambia de velocidad respondiendo al slider de la app.
- **Prioridad:** Media · **Estimación:** 6 · **Trazabilidad:** RF-21
- **Estado:** Hecho en código; sin probar con hardware. Limitación conocida: pausa breve al leer el peso.
- **Tareas:**
  1. Probar el patrón giratorio a distintas velocidades.
  2. Reducir la pausa del patrón durante la lectura del HX711.

### CUNA-003 — Periodo de encendido de luces
- **Historia:** Como Usuario, quiero configurar un temporizador o periodo de tiempo para el encendido de las luces de la cuna para evitar que las luces permanezcan encendidas más tiempo del necesario.
- **Criterios de aceptación (SRS):** La app permite definir la duración del temporizador de luces y apaga el juego de luces al cumplirse el tiempo.
- **Criterios refinados:** El tiempo lo cuenta el servidor (`ends_at`), así que las luces se apagan aunque la app esté cerrada.
- **Prioridad:** Baja · **Estimación:** 3 · **Trazabilidad:** RF-22
- **Estado:** Hecho (`ends_at`, job `cm-expire-lights`).
- **Tareas:**
  1. Probar que las luces se apagan al vencer el temporizador con la app cerrada.

### CUNA-002 — Speaker de la cuna
- **Historia:** Como Usuario, quiero usar un widget en la app móvil para hablarle al bebé desde el micrófono de mi teléfono al speaker de la cuna.
- **Criterios de aceptación (SRS):** El speaker reproduce el audio del micrófono en tiempo real.
- **Prioridad:** Media · **Estimación:** 7 · **Trazabilidad:** RF-19
- **Estado:** Pendiente (fuera del alcance actual; requiere hardware con audio).
- **Tareas:**
  1. Elegir el hardware de audio (el UNO no puede reproducir voz).
  2. Definir el transporte de audio en tiempo real.
  3. Widget "mantener para hablar" con permiso de micrófono.

---

## E7 — Dashboard, registros y exportación
Requisitos: RF-05, RF-09, RF-10 · RNF-03, RNF-06.

### APP-005 — Visualizar registros de datos
- **Historia:** Como Usuario, quiero visualizar los registros de datos en una sección de la app para explorar los registros de mi bebé.
- **Criterios de aceptación (SRS):** La app tiene una sección que contiene los registros de la base de datos por cada tabla.
- **Criterios refinados:** Los registros se separan por tipo (peso, temperatura, humedad, eventos), son del perfil activo y se cargan por páginas.
- **Prioridad:** Media · **Estimación:** 5 · **Trazabilidad:** RF-10
- **Estado:** Pendiente.
- **Tareas:**
  1. Consultas paginadas por tipo de dato y perfil.
  2. Pantalla "Registros" con pestañas por tipo y estados vacío/error.

### APP-002 — Dashboard del bebé
- **Historia:** Como Usuario, quiero visualizar un dashboard con tablas y plots que presenten información relevante acerca de la actividad del bebé para analizar los comportamientos y el estado del bebé.
- **Criterios de aceptación (SRS):** Existe una sección en la app que visualiza el dashboard con los datos del respectivo bebé.
- **Criterios refinados:** Muestra la evolución del peso, temperatura/humedad y eventos por día; se renderiza en < 1,5 s tras elegir el perfil (RNF-03).
- **Prioridad:** Media · **Estimación:** 7 · **Trazabilidad:** RF-05, RNF-03
- **Estado:** Pendiente.
- **Tareas:**
  1. Vistas o RPC de agregados por día en Supabase.
  2. Gráficas de peso, entorno y actividad.
  3. Medir el tiempo de carga.

### APP-004 — Exportar datos
- **Historia:** Como Usuario, quiero exportar a un archivo de Excel los registros del bebé para tener un respaldo de los registros personalmente.
- **Criterios de aceptación (SRS):** La app genera un archivo de extensión .xlsx con los datos registrados en la base de datos.
- **Criterios refinados:** El archivo tiene una hoja por perfil de bebé (RF-09) y se puede compartir o guardar desde el teléfono.
- **Prioridad:** Baja · **Estimación:** 3 · **Trazabilidad:** RF-09
- **Estado:** Pendiente.
- **Tareas:**
  1. Generar el .xlsx con una hoja por perfil.
  2. Compartir / guardar el archivo.

---

## E8 — Alimentación
Requisitos: RF-23 a RF-26. Fuera del alcance del prototipo actual.

### ALI-001 — Sensor de temperatura del biberón (derivada)
- **Historia:** Como Usuario, quiero que el biberón mida la temperatura de la comida para saber si es segura para mi bebé.
- **Criterios de aceptación:** El módulo de alimentación reporta la temperatura del biberón y la app la muestra.
- **Prioridad:** Alta · **Estimación:** 3 · **Trazabilidad:** RF-23
- **Estado:** Pendiente.
- **Tareas:**
  1. Elegir sensor apto para alimentos e integrarlo al firmware.
  2. Mostrar la temperatura en la pantalla de alimentación.

### APP-012 — Establecer alimentación
- **Historia:** Como Usuario, quiero establecer la temperatura, volumen o masa de la comida del bebé en el biberón a través de widgets en la app para cambiar la cantidad y estado de comida que come el bebé.
- **Criterios de aceptación (SRS):** El sistema de alimentación cambia cantidad y temperatura con que se alimenta al bebé según se programe en los widgets.
- **Prioridad:** Media · **Estimación:** 6 · **Trazabilidad:** RF-24
- **Estado:** Pendiente.
- **Tareas:**
  1. Modelo de configuración de alimentación (temperatura, cantidad, horario, duración).
  2. Widgets de configuración en la app.
  3. Aplicar la configuración en el módulo.

### APP-006 — Iniciar alimentación
- **Historia:** Como Usuario, quiero activar el período de alimentación automática con un botón para alimentar al bebé.
- **Criterios de aceptación (SRS):** La app tiene un botón que activa la función de alimentación del sistema de alimentación.
- **Prioridad:** Baja · **Estimación:** 2 · **Trazabilidad:** RF-25
- **Estado:** Pendiente.
- **Tareas:**
  1. Comando `start_feeding` por la nube.
  2. Botón con confirmación y estado en curso.

### APP-007 — Recordatorios de alimentación
- **Historia:** Como Usuario, quiero recibir notificaciones de recordatorio cuando deba alimentar al bebé para recordar que debo alimentar al bebé.
- **Criterios de aceptación (SRS):** La app manda notificaciones en el horario de alimentación.
- **Prioridad:** Media · **Estimación:** 3 · **Trazabilidad:** RF-26
- **Estado:** Pendiente.
- **Tareas:**
  1. Programar notificaciones locales según el horario.
  2. Reprogramarlas al cambiar el horario.

---

## E9 — Juguete interactivo
Requisitos: RF-27 a RF-30. Fuera del alcance del prototipo actual.

### JUG-001 — Juego interactivo del juguete
- **Historia:** Como Usuario, quiero que mi bebé interactúe con un juego de luces aleatorias en los botones del juguete para entretenerse y presionar los botones encendidos.
- **Criterios de aceptación (SRS):** El juguete enciende botones luminosos al azar para que el bebé los presione durante la sesión de juego.
- **Prioridad:** Media · **Estimación:** 5 · **Trazabilidad:** RF-27
- **Estado:** Pendiente.
- **Tareas:**
  1. Firmware del juego (botones con LED al azar).
  2. Reportar pulsaciones como eventos.

### JUG-002 — Configurar y activar juego del juguete
- **Historia:** Como Usuario, quiero establecer la duración del juego e iniciar el periodo de juego desde la app para controlar el tiempo que el bebé juega con el juguete interactivo.
- **Criterios de aceptación (SRS):** La app incluye widgets para definir el tiempo de juego e iniciar la sesión del juguete.
- **Prioridad:** Baja · **Estimación:** 3 · **Trazabilidad:** RF-28
- **Estado:** Pendiente.
- **Tareas:**
  1. RPC para iniciar sesión de juego con duración.
  2. Widgets de duración e inicio.

### JUG-003 — Regulación de luces del juguete
- **Historia:** Como Usuario, quiero ajustar la intensidad del brillo de las luces del juguete desde la app para adaptar el brillo del juguete a la iluminación del entorno.
- **Criterios de aceptación (SRS):** La app incluye un widget para regular el brillo de las luces del juguete en tiempo real.
- **Prioridad:** Baja · **Estimación:** 2 · **Trazabilidad:** RF-29
- **Estado:** Pendiente (reutiliza el patrón de `set_lights`).
- **Tareas:**
  1. Slider de brillo del juguete reutilizando el de luces.

### JUG-004 — Sensor de movimiento del juguete (derivada)
- **Historia:** Como Usuario, quiero que el juguete avise cuando detecta movimiento durante la sesión de juego para saber cuándo mi bebé lo usa.
- **Criterios de aceptación:** Durante una sesión activa, el juguete registra un evento y la app recibe una alerta al detectar movimiento; fuera de la sesión no.
- **Prioridad:** Baja · **Estimación:** 3 · **Trazabilidad:** RF-30
- **Estado:** Pendiente.
- **Tareas:**
  1. Integrar el sensor de movimiento al firmware del juguete.
  2. Generar alerta solo con sesión activa.

---

## E10 — Sistema de habitación
Requisitos: RF-31, RF-32 · retención de capturas 30 días / 1 GB (SRS §2.4). Fuera del alcance del prototipo actual.

### HAB-002 — Sensor de apertura de puerta
- **Historia:** Como Usuario, quiero que el sistema de habitación detecte la apertura de la puerta para recibir una notificación de alerta.
- **Criterios de aceptación (SRS):** El sistema de habitación identifica correctamente la apertura de la puerta y la clasifica según el grado de apertura.
- **Prioridad:** Media · **Estimación:** 4 · **Trazabilidad:** RF-31
- **Estado:** Pendiente.
- **Tareas:**
  1. Elegir sensor de ángulo/apertura e integrarlo al firmware.
  2. Clasificar el grado de apertura y reportarlo como evento.

### HAB-003 — Captura de imágenes al abrir la puerta
- **Historia:** Como Usuario, quiero que el sistema tome fotografías de la habitación al detectar la apertura de la puerta y las guarde en la BD para tener evidencia visual de las entradas a la habitación del bebé.
- **Criterios de aceptación (SRS):** La cámara del sistema de habitación toma una captura al abrirse la puerta y almacena el registro en la base de datos.
- **Criterios refinados:** Las capturas se borran tras 30 días o al superar 1 GB por cuenta.
- **Prioridad:** Alta · **Estimación:** 6 · **Trazabilidad:** RF-32
- **Estado:** Pendiente (existe la tabla `storage_cleanup`, falta el vaciado).
- **Tareas:**
  1. Captura con cámara al recibir el evento de puerta.
  2. Subida a Supabase Storage con registro en la base.
  3. Job de retención (30 días / 1 GB).
  4. Ver capturas en la app.

### HAB-001 — Detección de movimiento
- **Historia:** Como Usuario, quiero que el sistema de habitación detecte movimiento de la cuna y las personas en la habitación para recibir una notificación de alerta.
- **Criterios de aceptación (SRS):** El sistema de habitación identifica correctamente el movimiento de los sujetos y de la cuna y los distingue de los objetos.
- **Prioridad:** Media · **Estimación:** 7 · **Trazabilidad:** RF-31 (ampliación)
- **Estado:** Pendiente.
- **Tareas:**
  1. Investigar detección de movimiento (PIR vs. visión).
  2. Prototipo y medición de falsos positivos.

### APP-013 — Alertas del sistema de habitación
- **Historia:** Como Usuario, quiero recibir alertas en la app cuando el sistema de habitación detecte actividad para estar al pendiente de la seguridad del bebé en la habitación.
- **Criterios de aceptación (SRS):** La app recibe una notificación de alerta cuando el sistema de habitación detecta movimiento.
- **Prioridad:** Baja · **Estimación:** 3 · **Trazabilidad:** RF-31, RF-32
- **Estado:** Pendiente (depende de APP-001).
- **Tareas:**
  1. Mapear eventos de habitación a alertas push con enlace a la captura.

---

## Requisitos no funcionales (como criterios transversales)
| RNF | Dónde se verifica |
|---|---|
| RNF-01 latencia ≤ 3 s | APP-001 |
| RNF-02 100 dispositivos cada 10 s | DB-002 |
| RNF-03 dashboard < 1,5 s | APP-002 |
| RNF-04 disponibilidad 99 % | E1 (plan gratuito de Supabase) |
| RNF-05 alertas locales sin red | E5: buzzer local + buffer de 2000 lecturas en el puente |
| RNF-06 controles básicos en ≤ 2 toques | Revisión de UX en cada historia de app |
