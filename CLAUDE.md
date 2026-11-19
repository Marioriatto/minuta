# CLAUDE.md — Colchón Minuta (arquitectura y traspaso)

> Documento vivo. Última actualización: 2026-11-19. Fuente de verdad funcional: el SRS (PDF). Si algo no está en el SRS, **preguntar** antes de decidir.

## 1. Qué es el proyecto y cómo se trabaja

**Colchón Minuta** es un monitor de bebé IoT: colchón con peso/temperatura/humedad, cuna ambiente, juego de luces y app móvil con notificaciones push.

- Prioridad del proyecto: **entregar avances incrementales para aprender Scrum**. Se prefiere lo simple que funcione sobre lo completo.
- Idioma: español (Costa Rica). Textos de UI en ARB listos para i18n.
- Todo cambio debe trazarse a un **RF / RNF / HU** del SRS.

### Protocolo obligatorio por fase
1. Preguntas de decisión (máx. 3 por ronda, con opción recomendada).
2. Resumen de 5 líneas y esperar "ok".
3. Generar código.
4. Cerrar con: (a) tabla de trazabilidad RF/RNF/HU, (b) qué probar, (c) riesgos/supuestos, (d) pendiente para la siguiente fase.
5. No avanzar sin aprobación.

### Reglas de código
- Capas `presentation / domain / data`; **sin lógica de negocio en widgets**.
- Secretos fuera del repo. Estados explícitos: loading / empty / error / offline.
- Tests por módulo. `test/architecture/layers_test.dart` hace cumplir las capas.

### Restricciones de seguridad (no negociables)
- **No leer ni imprimir** `google_secret.txt` ni `config/*.json` (claves reales).
- **No ejecutar nada contra Supabase** desde Claude Code sin permiso explícito. El proyecto Supabase `minuta` es **producción**: pedir "ok" antes de migraciones, despliegues o escrituras.
- **No tocar** el proyecto Supabase `hackaton-nasa`.
- `hardware/bridge/bridge.toml` contiene tokens: está en `.gitignore`; nunca subirlo ni pegarlo en el chat.
- Pendiente: confirmar que `google_secret.txt` está ignorado por git.

## 2. Decisiones de alcance (y por qué)

| Decisión | Por qué |
|---|---|
| **Ignorar el WiFi del SRS** | El prototipo es un Arduino UNO por USB; el usuario lo pidió explícitamente. |
| Hardware mínimo: medir **temperatura, humedad y peso real** | Es lo único exigido para la demo; el resto es simulable. |
| **Puente en Python** entre el COM y la nube | El UNO no tiene red; la PC hace de gateway hacia Supabase. |
| App móvil + Supabase para push | Compensa el software limitado del hardware. |
| Diseño: "con el sistema visual actual" | No hay diseño Figma aportado; reutilizar tema existente. |
| Luces = 4 LED en pines PWM | Permite brillo y patrón giratorio (RF-20/21) con un UNO. |
| Alcance de la entrega de hoy: vincular + luces + cuna | Es lo que cabe en un sprint corto y se puede probar de punta a punta. |

**Fuera de alcance por ahora:** iniciar/detener detección desde la app (RF-12), alimentación, juguete, puerta/cámara, voz (RF-19), Edge Function de push FCM + webhook, vaciado de `storage_cleanup`, exportación `.xlsx`.

## 3. Stack

| Capa | Tecnología | Nota |
|---|---|---|
| App | Flutter / Dart | Arquitectura feature-first |
| Estado | Riverpod **2.6.1** | `Notifier`/`AsyncNotifier`; sin `ref.mounted` ni `NotifierProvider.autoDispose`; se usa flag `_disposed` + `ref.onDispose`; `AsyncValue.value` |
| Navegación | go_router **14.8.1** | Rutas anidadas bajo `accessories` |
| Backend | Supabase (Postgres, RLS, Realtime, pg_cron, Edge Functions en Deno) | `supabase_flutter` con `publishableKey` |
| i18n | `gen-l10n` con `lib/l10n/app_es.arb` | ~190 claves; **solo añadir claves**, no renombrar |
| Firmware | Arduino UNO (C++), v0.2.0 | Protocolo serie CSV |
| Puente | Python ≥ 3.11 (`tomllib`) | Tests con pytest |
| Errores | `Result<T>` + `AppFailure` (sealed) + `runCatching` | Mapeo en `failure_mapper.dart` |

## 4. Estructura de carpetas

```
colchon_minuta/
├─ CLAUDE.md
├─ docs/
│  ├─ hardware_bom.md            # lista de materiales
│  ├─ hardware_protocolo.md      # protocolo serie + §6 estado del despliegue
│  └─ fase3_ampliaciones.md
├─ hardware/
│  ├─ README.md
│  ├─ arduino/colchon_uno/colchon_uno.ino
│  └─ bridge/                    # puente Python (COM → Supabase)
│     ├─ colchon_bridge/{__main__,api,bridge,calibrate,config,links,logic,protocol}.py
│     ├─ tests/                  # 30 tests
│     ├─ bridge.example.toml     # plantilla (sí va a git)
│     └─ bridge.toml             # real, CON tokens (ignorado por git)
├─ supabase/
│  ├─ functions/device/index.ts  # Edge Function de módulos
│  ├─ config.toml.device-snippet # verify_jwt = false para `device`
│  └─ migrations/                # 20261119000000_lights_cradle.sql, 20261119000100_lights_keep_timer.sql
├─ lib/
│  ├─ app/router/app_router.dart
│  ├─ core/{errors,router,ui}/   # app_failure, failure_mapper, app_routes, failure_l10n
│  ├─ l10n/app_es.arb
│  └─ features/
│     ├─ devices/{domain,data,presentation,devices_providers.dart}
│     ├─ lights/presentation/lights_page.dart
│     └─ cradle/presentation/cradle_page.dart
└─ test/{architecture,support,features/...}
```

### Reglas de capas (verificadas por test)
- `domain`: sin `flutter`, `riverpod`, `supabase`, ni imports de `data`/`presentation`.
- `presentation`: sin imports de `/data/` ni `supabase`.
- `data`: sin imports de `/presentation/`.
- `<feature>_providers.dart` es el **único** punto de cableado data↔domain.

> Nota: existen archivos huérfanos antiguos en `lib/core/router/{app_router,placeholder_pages,session_status}.dart`. No se han tocado; revisar y borrar en una fase de limpieza.

## 5. Arquitectura de punta a punta

```
Arduino UNO ──USB/COM (CSV, 115200)──► Puente Python ──HTTPS──► Edge Function `device` ──RPC──► Postgres
   ▲                                        ▲   │ poll cada 3 s                                     │
   └── comandos (LIGHT, BUZ, TARE)  ◄───────┘   └───────────────────────────────────────────────────┘
                                                                                Realtime ──► App Flutter
```

**Por qué así:**
- **Protocolo serie CSV, no JSON**: el UNO tiene 2 KB de RAM.
- **Edge Function y no PostgREST directo**: el módulo no es un usuario de Supabase; se autentica con un token propio y la `service_role` nunca sale de la función (`verify_jwt = false`).
- **Un token por módulo lógico** (`mattress`, `cradle`, `lights`): aísla y permite revocar por separado.
- **Poll cada 3 s** en vez de push al dispositivo: el puente está detrás de NAT y es el mecanismo más simple.

### Hardware (pines)
| Elemento | Pin |
|---|---|
| HX711 DT / SCK | D2 / D3 |
| AHT20 (I2C) | A4 (SDA) / A5 (SCL) |
| 4 LED PWM (220 Ω) | D9, D10, D11, D6 |
| Buzzer activo | D8 |
| Botones (INPUT_PULLUP) | D4, D5 |

Sketches: `colchon_uno.ino` (todo, v0.2.1: ya no se cuelga sin HX711) y `cuna_uno.ino` (cuna sin balanza; ver `docs/hardware_cuna.md`). Ambos compilan para UNO con el `arduino-cli` del IDE.
Librerías: HX711 (Bogdan Necula), Adafruit AHTX0 (+ BusIO). Calibración del factor de escala en EEPROM.
**Limitación conocida:** leer el peso bloquea ~0,3–0,5 s cada 2 s, así que el patrón de luces hace una pausa breve.

### Protocolo serie (resumen; detalle en `docs/hardware_protocolo.md`)
- Arduino → PC: `H,<fw>` (hello), `R,<kg>,<°C>,<%>` (lectura cada 2 s), `B,<n>` (botón), `K,<cmd>` (ack), `E,<código>` (error), `X,<raw>` (calibración).
- PC → Arduino: `LIGHT,<0|1>,<brillo 0-100>,<velocidad 0-100>`, `BUZ,<ms>`, `TARE`, `RAW`, `CAL,<factor>`, `PING`.

### Lógica del puente
- Lotes cada **10 s**, con reintentos y buffer de **2000** lecturas.
- Eventos `presence` / `movement` / `absence`; ausencia y movimiento solo con **periodo de detección abierto**.
- Comandos de nube: `tare` (colchón), `buzz` (cuna). La app encola `buzz` insertando en `commands` (RLS + trigger `commands_enforce_refs` validan dueño); botón "Hacer sonar la cuna".
- Luces: estado efectivo = `config` + `ends_at` comparado con `server_time` (el reloj del servidor manda, no el de la PC).
- Tras un `Hello` (reinicio del Arduino) se reenvía el estado de luces.

## 6. Backend (Supabase)

### Edge Function `device` (`/functions/v1/device/…`)
Auth: `Authorization: Bearer <token de 64 hex>` → `authenticate_device`.

| Ruta | Método | RPC | Errores |
|---|---|---|---|
| `/ingest` | POST | `device_ingest(p_device_id, p_payload)` | 401, 409 `device_not_claimed`, 413 `payload_too_large` (256 KB), 422 |
| `/poll` | GET/POST | `device_poll(p_device_id)` | 401, 409 |
| `/ack` | POST | `device_ack_command(p_device_id, p_command_id, p_status, p_result)` | 422 `invalid_command_id` / `invalid_status` |

Estado: **desplegada (v1) pero aún no ejercitada contra el proyecto real**. Primera prueba: `python -m colchon_bridge run --simulate normal`.

### Funciones SQL relevantes
- Dispositivos: `provision_device`, `claim_device` (código de 16 alfanuméricos; errores `invalid_or_used_code`, `device_not_found`), `authenticate_device`, `device_ingest`, `device_poll`, `device_ack_command`.
- Bebés: `weigh_baby(p_baby_id)` ("Pesar ahora": copia `reported_state.weight_kg` del colchón al perfil); trigger `guard_baby_weight` impide escribir `babies.weight` por otra vía.
- App → config: `set_lights(p_device_id, p_on, p_brightness, p_speed, p_minutes default null, p_keep_timer default false)`, `set_thresholds`.
- Mantenimiento: `expire_lights_timers` (job **pg_cron** `cm-expire-lights`, cada minuto).
- Triggers: `bump_config_version`, `fill_device_context`, `evaluate_thresholds`, `create_alert_from_event`, `audit_devices`.

### Seguridad en base de datos
- **RLS** activo. Funciones `SECURITY DEFINER` con `set search_path = ''`.
- `set_*`: ejecutable por `authenticated`; `expire_lights_timers`: solo `service_role`; `anon` sin acceso.
- **Brecha conocida:** `authenticated` conserva `UPDATE` de columna sobre `devices.config` y `devices.name` (puede saltarse la validación de las funciones). Solo afecta a sus propias filas. No se revocó todavía.
- Pendiente: activar *leaked password protection*.

### Configuración por defecto de luces
`{"on":false,"brightness":50,"speed":50,"timer_minutes":null,"ends_at":null}`

### Migraciones
- Aplicadas en producción: `lights_cradle`, `lights_keep_timer` (una sola sobrecarga de `set_lights`) y `baby_weight_from_mattress` (`babies.weight` nullable + `weigh_baby` + trigger `guard_baby_weight`).
- Ojo: en producción el dueño de `babies` es **`owner_id`** (no `parent_id` como dice `docs/fase2_contrato.md`).
- **Falta** traer a `supabase/` del proyecto la migración inicial (`20261112000000_init.sql` / `reset.sql`).

## 7. App Flutter — cómo está hecha

- **Dominio** (`features/devices/domain`): `Device` (`isOnline(now)` con ventana de **30 s**; `temperatureC`/`humidityPct` salen de `reportedState`), `DeviceCode` (normaliza y valida 16 caracteres), `LightsSettings`/`LightsRules`, `Thresholds` + `ThresholdsValidator` (acepta coma decimal) + `MetricLevel`, `DevicesRepository`, casos de uso (`ListDevices`, `ClaimDevice`, `SetLights`, `SetThresholds`).
- **Datos**: `DeviceMapper`, `DevicesRemoteSource` (select, stream Realtime, RPCs), `DevicesRepositoryImpl`.
- **Estado**: `DevicesNotifier` (carga inicial + suscripción Realtime + upsert), `deviceByIdProvider` (family), `nowProvider` (tick cada 10 s para recalcular "en línea").
- **Controladores**: `ClaimDeviceController`; `DeviceActionsController` con cola **"el último gana"** para el slider de luces (evita saturar el RPC).
- **Rutas**: `accessories` → `claim`, `lights/:id`, `cradle/:id`.
- **Errores**: `InvalidDeviceCodeFailure` y `NotFoundFailure` mapeados desde `PostgrestException` y traducidos en `failure_l10n.dart`.

## 8. Estado actual y verificación

| Pieza | Estado |
|---|---|
| Migraciones + Edge Function | Aplicadas/desplegadas; función **sin probar** |
| Firmware y puente | Escritos; 30 tests Python pasando en mi entorno; **sin probar con hardware** |
| Flutter (devices/lights/cradle) | Escrito, sintaxis revisada; **sin `analyze` ni `test` reales** |
| Fase 2 (perfiles de bebé) | Sin validación del usuario |

### Checklist de primera ejecución
1. `flutter gen-l10n && dart fix --apply && dart format lib test && flutter analyze && flutter test`
2. `cd hardware/bridge && python -m pytest`
3. Subir `colchon_uno.ino`; armar 4 LED y el resto según §5.
4. Poner el puerto COM correcto en `bridge.toml`.
5. `python -m colchon_bridge run --simulate normal` (primera prueba de la Edge Function).
6. En la app: Accesorios → vincular módulos con sus claim codes (uso único; se regeneran con `provision_device`).
7. Mover el control de luces: los LED deben responder en ~3 s.

## 9. Trazabilidad

| Requisito | Dónde |
|---|---|
| RF-20 / RF-21 (brillo y velocidad de luces) | `lights_page.dart`, `set_lights`, patrón giratorio en firmware |
| Temporizador de luces | `ends_at`, `expire_lights_timers`, `p_keep_timer` |
| Cuna: temperatura/humedad y umbrales | `cradle_page.dart`, `set_thresholds`, trigger `evaluate_thresholds` |
| Vinculación de módulos | `claim_device_page.dart`, `claim_device` |
| RF-05 dashboard de Inicio | `features/dashboard` (`HomeDashboardPage`, `readings_hourly`, `events`); estados vacíos para cuenta nueva |
| RF-11 peso del bebé medido por el colchón | `WeighBaby`, menú "Pesar ahora" en `babies_page.dart`, `weigh_baby` |
| Login con Google | `signInWithOAuth` ya implementado; se activa con `SOCIAL_LOGIN=true` + proveedor en Supabase |
| Ingesta de sensores | Puente + Edge Function `device` + `device_ingest` |
| Seguridad / secretos | Token por módulo, RLS, `bridge.toml` ignorado |

## 10. Pendiente y riesgos

**Siguiente:** iniciar/detener detección (RF-12); push FCM + webhook; validar Fase 2; limpiar huérfanos de `lib/core/router/`; migración inicial en `supabase/`; revocar `UPDATE` directo en `devices.config`; confirmar `.gitignore` de `google_secret.txt`; Figma si se aportan diseños.

**Backlog:** en Jira, proyecto **CM** (10 épicas, 32 historias, 75 subtareas, 139 puntos). Detalle y mapeo en `docs/backlog.md`.

**Riesgos:** errores de compilación Dart no detectables sin Flutter; Edge Function nunca ejercitada; pausa del patrón de luces por lectura del HX711; el resultado de los tests de Claude Code en paralelo es desconocido.

## 11. Trampas conocidas (para quien siga)
- Riverpod 2.6.1: no existe `ref.mounted`; usar `_disposed`.
- `Slider.value` requiere `.clamp(0.0, 100.0).toDouble()`.
- `pg_cron`/`now()` en tests SQL: `now()` es constante dentro de una transacción.
- Con el MCP de Supabase, `execute_sql` multi-sentencia solo devuelve el último resultado.
- El entorno de Claude (chat) no tiene Flutter/Dart/Deno: nada de lo anterior se compiló allí.
