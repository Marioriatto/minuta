# Flavors nativos (dev / staging / prod)

`flutter create` no se pudo ejecutar al generar este esqueleto. Crea las
carpetas de plataforma una sola vez y aplica lo siguiente.

```bash
flutter create --org <TU_ORG> --project-name colchon_minuta \
  --platforms android,ios .
```

`<TU_ORG>` define el applicationId / bundle id base: **decisión pendiente**.

## Android (`android/app/build.gradle.kts`)

```kotlin
android {
    defaultConfig {
        minSdk = 26   // Android 8.0
    }
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Minuta Dev")
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".staging"
            resValue("string", "app_name", "Minuta Staging")
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "Colchón Minuta")
        }
    }
}
```

En `AndroidManifest.xml`: `android:label="@string/app_name"`.

## iOS

1. Deployment target `14.0` (Runner → General, y `Podfile`: `platform :ios, '14.0'`).
2. Duplica los esquemas en `dev`, `staging` y `prod`.
3. Crea configuraciones de build `Debug-<flavor>`, `Release-<flavor>` y
   `Profile-<flavor>` por esquema, con un `.xcconfig` cada una que defina
   `PRODUCT_BUNDLE_IDENTIFIER` y `PRODUCT_NAME`.
4. Ejecuta con `--flavor <flavor>`.

## Ejecución

```bash
cp config/dev.example.json config/dev.json   # completa tus valores
flutter run --flavor dev --dart-define-from-file=config/dev.json
```

`config/*.json` está en `.gitignore`; solo se versionan los `*.example.json`.
La anon/publishable key de Supabase es pública por diseño, pero la URL y
cualquier otro valor por entorno se tratan como configuración no versionada.
**Nunca** pongas aquí la service_role: `AppConfig` la rechaza al arrancar.
