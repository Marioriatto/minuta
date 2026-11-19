# Notificaciones push (Firebase Cloud Messaging)

Cómo funciona:

```
evento (puente) ─► events ─► trigger create_alert_from_event ─► alerts
                                                    │ (warning / critical)
                                                    ▼
                         trigger alerts_notify_push ─► pg_net ─► Edge Function `push`
                                                                   │ FCM HTTP v1
                                                                   ▼
                                                      teléfonos del dueño (push_tokens)
```

- `info` (movimiento, recordatorios, puerta…) no envía push; solo se lista en la pestaña Alertas.
- Cada alerta se envía una sola vez (`alerts.pushed_at`), así que la función no necesita secreto.
- Sin `google-services.json` la app compila y funciona igual, sin push.

## Lo que tienes que configurar (una vez)

1. **Firebase:** <https://console.firebase.google.com> → *Agregar proyecto* (sin Analytics está bien).
2. **App Android:** en el proyecto → *Agregar app* → Android → paquete **`com.colchonminuta.app`**.
   Descarga **`google-services.json`** y cópialo a `android/app/google-services.json`
   (está en `.gitignore`: no se sube a git).
3. **Cuenta de servicio:** *Configuración del proyecto* → *Cuentas de servicio* →
   *Generar nueva clave privada* (descarga un JSON). No lo guardes en el repo.
4. **Secreto en Supabase:** Dashboard → *Edge Functions* → *Secrets* → nuevo secreto
   `FCM_SERVICE_ACCOUNT` con **todo el contenido** del JSON del paso 3.
5. Recompilar e instalar la app (`flutter run …`). Al iniciar sesión pide permiso de
   notificaciones y registra el teléfono.

## Despliegue en Supabase (lo hace Claude con tu "ok")
- Migración `supabase/migrations/20261119000300_push_alerts.sql`
  (`pg_net`, `pushed_at`, `register_push_token`, `unregister_push_token`, `mark_alerts_read`,
  trigger `alerts_notify_push`).
- Edge Function `supabase/functions/push` con `verify_jwt = false`.

## Probar
Con la cuna vinculada y el puente en `--simulate alarm` (la temperatura supera 26 °C y el bebé
se levanta a los 60 s), configura un máximo de temperatura de 26 °C en la cuna: debe llegar
"Temperatura alta en la cuna" con la app cerrada, y tocarla abre la pestaña Alertas.
