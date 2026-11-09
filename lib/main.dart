import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/app_config_provider.dart';
import 'core/supabase/supabase_bootstrap.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      // TODO(fase-x): reportar a crash reporting (herramienta por definir).
    };

    final AppConfig config;
    try {
      config = AppConfig.fromEnvironment();
    } on ConfigException catch (e) {
      runApp(_ConfigErrorApp(message: e.message));
      return;
    }

    await initSupabase(config);

    runApp(
      ProviderScope(
        overrides: [appConfigProvider.overrideWithValue(config)],
        child: const App(),
      ),
    );
  }, (error, stack) {
    debugPrint('Error no capturado: $error\n$stack');
  });
}

/// Pantalla solo para desarrolladores cuando falta o está mal la configuración.
/// No se localiza a propósito: ocurre antes de que exista la app.
class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Configuración inválida.\n\n$message\n\n'
                'Ejecuta con --dart-define-from-file=config/<env>.json',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}
