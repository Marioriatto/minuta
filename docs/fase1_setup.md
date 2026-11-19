# Fase 1 — Configuración de plataforma y backend

Estos pasos son **manuales** (carpetas `android/` e `ios/` y panel de Supabase);
el código de la app ya asume que están hechos.

## 1. Identificador de la app → `com.colchonminuta.app`

**Android** (`android/app/build.gradle.kts`):

```kotlin
android {
    namespace = "com.colchonminuta.app"
    defaultConfig {
        applicationId = "com.colchonminuta.app"
        minSdk = 26
    }
}
```

Mueve `MainActivity.kt` a `android/app/src/main/kotlin/com/colchonminuta/app/`
y cambia su primera línea a `package com.colchonminuta.app`. Borra las carpetas
vacías del paquete anterior y ejecuta `flutter clean`.

**iOS:** Runner → Signing & Capabilities → Bundle Identifier
`com.colchonminuta.app`.

## 2. Android — `android/app/src/main/AndroidManifest.xml`

Dentro de `<manifest>` (antes de `<application>`). `INTERNET` es imprescindible:
`flutter create` solo lo añade a los manifiestos de debug/profile, y sin él la
app **no se conecta en release**.

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

Dentro de `<activity android:name=".MainActivity" ...>`:

```xml
<!-- Supabase gestiona el deep link; evita que Flutter lo enrute a go_router -->
<meta-data android:name="flutter_deeplinking_enabled" android:value="false" />
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="com.colchonminuta.app" android:host="login-callback" />
</intent-filter>
```

## 3. iOS (requiere Mac con Xcode)

`ios/Runner/Info.plist`:

```xml
<key>FlutterDeepLinkingEnabled</key>
<false/>
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>com.colchonminuta.app</string></array>
  </dict>
</array>
<key>NSMicrophoneUsageDescription</key>
<string>Para hablarle a tu bebé a través del altavoz de la cuna.</string>
```

`ios/Podfile`, dentro de `post_install` (activa solo los permisos usados):

```ruby
target.build_configurations.each do |config|
  config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
    '$(inherited)',
    'PERMISSION_NOTIFICATIONS=1',
    'PERMISSION_MICROPHONE=1',
  ]
end
```

Xcode → Signing & Capabilities → añade **Sign in with Apple**. Deployment target
`14.0`.

## 4. Supabase (tu proyecto)

Authentication → …

- **URL Configuration → Redirect URLs:** `com.colchonminuta.app://login-callback`
- **Providers → Email:** activar *Confirm email*. Longitud mínima de contraseña
  **8** (la app valida 8; si Supabase tiene un mínimo mayor, súbelo en
  `AuthValidators.minPasswordLength`).
- **Providers → Google:** Client ID y Secret de un cliente OAuth tipo *Web* de
  Google Cloud, con la URI de redirección `https://<proyecto>.supabase.co/auth/v1/callback`.
- **Providers → Apple:** Services ID, Team ID, Key ID y clave privada (requiere
  Apple Developer Program). Solo se ofrece en iOS.
- **Correo:** el SMTP por defecto de Supabase tiene límites muy bajos; para
  probar con correos reales configura un SMTP propio.

Los botones de Google/Apple **solo aparecen si** `config/<env>.json` trae
`"SOCIAL_LOGIN": true`. Por defecto está en `false` (solo correo y contraseña):
actívalo cuando los proveedores estén configurados en Supabase.

Para desarrollo solo con correo: en *Providers → Email* desactiva *Confirm email*
(o crea usuarios ya confirmados en *Authentication → Users → Add user*). El SMTP
por defecto de Supabase envía muy pocos correos por hora.

No se necesitan tablas nuevas en esta fase.

## 5. Después de copiar los archivos

```bash
flutter pub get
flutter gen-l10n
dart fix --apply
dart format lib test
flutter analyze
flutter test
flutter run -d <dispositivo> --dart-define-from-file=config/dev.json
```
