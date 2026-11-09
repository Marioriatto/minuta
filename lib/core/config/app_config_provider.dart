import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';

/// Se sobreescribe en `main.dart` con la configuración ya validada.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider no fue inicializado'),
);
