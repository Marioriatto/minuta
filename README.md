# Colchón Minuta — App móvil (Flutter)

Android 8+ (API 26) · iOS 14+. Backend: Supabase (diseñado y mantenido fuera de este repo).

## Arranque rápido

```bash
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter test
```

Para correr la app ver `docs/flavors.md`.

## Arquitectura

Feature-first con capas dentro de cada feature:

```
lib/
  app/             composición: router, AppGate (sesión + permisos)
  core/            config, errores, red, rutas, tema, ui compartida
  features/<f>/
    <f>_providers.dart  única conexión datos ↔ dominio (inyección)
    presentation/  widgets + notifiers (sin lógica de negocio)
    domain/        entidades, interfaces de repositorio, casos de uso (Dart puro)
    data/          data sources (Supabase), implementación de repositorios
  l10n/            ARB (es base); código generado en l10n/generated (no versionado)
```

Features actuales: `auth`, `permissions`, `babies`, `settings`, `shell`.
Contrato de la tabla `babies`: `docs/fase2_contrato.md`.
Configuración de plataforma y Supabase: `docs/fase1_setup.md`.

`test/architecture/layers_test.dart` falla si se violan las dependencias entre capas.

## Reglas

- Los repositorios devuelven `Result<T>` (ver `core/errors`); nunca excepciones crudas.
- Estados de pantalla con `StateView` (cargando, vacío, error, sin conexión).
- Todo texto visible va en `lib/l10n/app_es.arb`.
- Sin secretos en el repo.
