# Fase 3 (parcial): vincular, luces y cuna

## Qué hace la app
| Pantalla | Ruta | Requisitos |
|---|---|---|
| Ampliaciones (lista + estado en línea) | `/accessories` | RF-08, RNF-06 |
| Vincular con código | `/accessories/claim` | RF-06, RF-07, APP-003, APP-014 |
| Luces: encendido, intensidad, velocidad, temporizador | `/accessories/lights/:id` | RF-20, RF-21, RF-22, CUNA-001, CUNA-003 |
| Cuna: temperatura, humedad y umbrales | `/accessories/cradle/:id` | RF-16, RF-17, RF-18, APP-009 |

## Contrato con Supabase
- Lectura y Realtime de la tabla `devices` (RLS: solo el dueño).
- `claim_device(p_code, p_name)`: vincula y copia `device_kinds.default_config` (RF-07).
- `set_lights(p_device_id, p_on, p_brightness, p_speed, p_minutes, p_keep_timer)`: el servidor calcula
  `config.ends_at = now() + p_minutes`; con `p_keep_timer = true` conserva el temporizador en curso
  (cambiar brillo o velocidad no lo reinicia). El job `cm-expire-lights` apaga en la base las luces vencidas.
- `set_thresholds(p_device_id, p_temp_min, p_temp_max, p_hum_min, p_hum_max)`: guarda
  `config.thresholds`; el trigger `evaluate_thresholds` genera las alertas.
- Estado real de la cuna: `reported_state.temperature_c` y `reported_state.humidity_pct` (los sube el puente).
- Un módulo se considera "en línea" si `last_seen_at` tiene menos de 30 s (el puente consulta cada 3 s).

## Errores de negocio
`invalid_or_used_code` → `InvalidDeviceCodeFailure`; `device_not_found` → `NotFoundFailure`;
`22023` (valores fuera de rango) → `ValidationFailure`.

## Decisiones
- Pantallas con el sistema visual actual (no hay diseños de Figma de Ampliaciones/Luces/Cuna).
- El brillo y la velocidad se envían al soltar el control; si se mueven mientras un envío está en curso,
  solo se envía el último valor.
- Los temporizadores rápidos son 15, 30, 60 y 120 min, más un valor libre de 1 a 720 min.
- Los controles se pueden usar con el módulo sin conexión: el cambio queda guardado y se aplica al reconectar.

## Fuera de esta entrega
Dashboard de gráficos (RF-05), iniciar/detener la detección del colchón desde la app (RF-12), alimentación,
juguete, puerta y cámara, voz en tiempo real (RF-19) y notificaciones push (FCM).
