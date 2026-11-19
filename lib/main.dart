import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/app_config_provider.dart';
import 'core/supabase/supabase_bootstrap.dart';
import 'features/notifications/data/firebase_push_gateway.dart';
import 'features/notifications/notifications_providers.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      // Pendiente (fase-x): reportar a crash reporting (por definir).
    };

    final AppConfig config;
    try {
      config = AppConfig.fromEnvironment();
    } on ConfigException catch (e) {
      runApp(_ConfigErrorApp(message: e.message));
      return;
    }

    await initSupabase(config);

    // Push (RF-03): si Firebase no está configurado la app sigue sin push.
    final push = await FirebasePushGateway.create();

    runApp(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          if (push != null) pushGatewayProvider.overrideWithValue(push),
        ],
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
