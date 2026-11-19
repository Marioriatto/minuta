# Hardware del prototipo: Arduino UNO + puente de Python

```
Sensores/LED/buzzer ── Arduino UNO ──USB (serie 115200)── PC ── script Python ──HTTPS── Edge Function `device` ── Postgres
                                                                                                         │
                                                              App Flutter ◄── Realtime / FCM ◄── triggers ┘
```

**Decisión del equipo:** el prototipo no usa Wi-Fi (el requisito de conexión Wi-Fi del SRS §2.4 queda
fuera del alcance del prototipo). Si el script se detiene o la PC se apaga, la cuna aparece
desconectada en la app (`last_seen_at` deja de avanzar). Voz en tiempo real (RF-19): aplazada.

## 1. Conexiones del Arduino UNO
| Pieza | Pin |
|---|---|
| HX711 | DT → D2, SCK → D3, VCC → 5 V, GND |
| AHT20 (I2C) | SDA → A4, SCL → A5, VCC 5 V (módulo con regulador) o 3,3 V (chip desnudo), GND |
| 4 LED de luces | D9, D10, D11 y D6, cada uno con 220 Ω hacia el LED y GND (todos con PWM: brillo y patrón giratorio) |
| Buzzer activo | D8 → buzzer → GND (si pide más de 20 mA, usa un 2N2222 y 1 kΩ) |
| Botón 1 / 2 (4 patas) | D4 / D5 y GND, con `INPUT_PULLUP` (pata de un lado a D, la del lado opuesto a GND) |

Botón de 4 patas: las patas del mismo lado están unidas entre sí; conecta en diagonal para no
quedar siempre cerrado. Todo a 5 V por USB; nada de red eléctrica cerca del bebé. No es un
dispositivo médico (SRS §1.2).

## 2. Protocolo serie (CSV por líneas, `\n`, 115200 baudios)
Se usa CSV y no JSON porque el UNO solo tiene 2 KB de RAM.

**Arduino → PC**
| Línea | Significado |
|---|---|
| `H,<firmware>` | Arranque o respuesta a `PING` |
| `R,<kg>,<°C>,<%HR>` | Lectura cada 2 s; `nan` si un sensor falla |
| `B,<1\|2>` | Botón pulsado |
| `K,<CMD>` | Comando ejecutado |
| `X,<crudo>` | Respuesta a `RAW` (para calibrar) |
| `E,<código>` | Error (`aht20_not_found`, `unknown_command`, `cal_invalid`, `line_too_long`) |

**PC → Arduino**
`LIGHT,<0|1>,<brillo 0-100>,<velocidad 0-100>` · `BUZ,<ms 1-5000>` · `TARE` · `RAW` · `CAL,<factor>` (queda en la EEPROM) · `PING`

## 3. Qué hace el puente (`hardware/bridge`)
- Reparte las lecturas en **módulos lógicos**, cada uno con su token: `mattress` (peso y eventos del colchón),
  `cradle` (temperatura y humedad) y, opcional, `lights` (brillo).
- Guarda una lectura por métrica cada `sample_interval_s` (10 s) y sube lotes cada `flush_interval_s`.
  Si no hay red, conserva hasta 2000 lecturas y reintenta.
- Genera los eventos `presence_detected`, `movement_detected` y `absence_detected`. **La ausencia y el
  movimiento solo se emiten con un periodo de detección abierto** (lo inicia la app con `start_detection`,
  RF-12); así la alerta tiene un bebé al que atribuirse.
- La temperatura y la humedad fuera de rango las evalúa el **trigger de la base** con los umbrales de
  `devices.config.thresholds`; el puente no decide umbrales.
- Consulta `device_poll` cada 3 s: ejecuta los comandos `tare` (mattress) y `buzz` (cradle, `params.ms`),
  y aplica la configuración de `lights` (`on`, `brightness`, `speed`) cada vez que cambia el estado efectivo.
  El temporizador (RF-22) se evalúa con la hora del **servidor** (`server_time` de `device_poll` contra
  `config.ends_at`); además el job `cm-expire-lights` marca las luces como apagadas en la base cada minuto. Cualquier otro comando se
  confirma como `failed / unsupported_command`.

## 4. Puesta en marcha
1. **Base:** ejecuta la migración (ya hecho si seguiste el paso anterior).
2. **Edge Function:** copia `supabase/functions/device/` a tu proyecto; añade el contenido de
   `supabase/config.toml.device-snippet` a `supabase/config.toml`; despliega con
   `supabase functions deploy device --no-verify-jwt`. No hay que crear secretos: la función lee
   `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` del entorno de Supabase.
3. **Fabricar módulos** (SQL Editor, una vez por módulo; el código y el token se ven **una sola vez**):
   ```sql
   select * from public.provision_device('mattress', 'SN-PROTO-MATTRESS');
   select * from public.provision_device('cradle',   'SN-PROTO-CRADLE');
   select * from public.provision_device('lights',   'SN-PROTO-LIGHTS');  -- opcional
   ```
4. **Arduino:** instala las librerías `HX711` (Bogdan Necula) y `Adafruit AHTX0`; abre
   `hardware/arduino/colchon_uno/colchon_uno.ino`, elige "Arduino Uno" y súbelo. Con el colchón vacío al encender.
5. **Puente:** `cd hardware/bridge`, `python -m venv .venv`, activa el entorno, `pip install -r requirements.txt`,
   copia `bridge.example.toml` a `bridge.toml` y pon URL, puerto COM y tokens (o variables
   `COLCHON_TOKEN_*`; **no subas `bridge.toml` al repositorio**).
6. **Calibrar:** `python -m colchon_bridge calibrate --known-kg 2.0` (con un peso conocido).
7. **Ejecutar:** `python -m colchon_bridge run`. Sin hardware: `python -m colchon_bridge run --simulate alarm`
   (el bebé se levanta a los 60 s y la temperatura pasa de 26 °C: genera alertas y push).
8. **Vincular:** en la app, "Vincular cuna" con el `claim_code` de cada módulo. Hasta entonces el puente
   avisa "aún no está vinculado" y guarda los datos.

## 5. Verificación realizada
- Puente: 27 pruebas unitarias (protocolo, reglas, subida con reintentos, comandos, calibración, escenario simulado).
- Base: el lote que genera el puente simulado se aplicó a `device_ingest` en PostgreSQL 16 real con la
  migración: 3 eventos y 30 lecturas aceptados, todo atribuido al bebé con detección abierta, y 3 alertas
  creadas por los triggers (movimiento, ausencia, temperatura alta).
- **No verificado:** la Edge Function (TypeScript) no se ejecutó (no hay Deno en mi entorno); el sketch no se
  compiló ni se probó con hardware; el cliente HTTP no se probó contra tu proyecto real.

## 6. Estado del despliegue (19-nov-2026)
- Migración `lights_cradle` aplicada en el proyecto `minuta` (`set_lights`, `set_thresholds`,
  `expire_lights_timers`, job `cm-expire-lights`).
- Edge Function `device` desplegada (versión 1, sin verificación de JWT). No se ha ejercitado todavía contra
  el proyecto real: la primera prueba es `python -m colchon_bridge run --simulate normal`.
- Módulos del prototipo creados: `SN-PROTO-MATTRESS`, `SN-PROTO-CRADLE`, `SN-PROTO-LIGHTS`.
  Sus tokens están solo en tu `hardware/bridge/bridge.toml` (fuera de git).
- Limitación del firmware: leer el peso bloquea el Arduino ~0,3 a 0,5 s cada 2 s; el patrón de luces hace una
  pausa breve en ese instante.
