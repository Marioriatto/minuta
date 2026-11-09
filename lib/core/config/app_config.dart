import 'dart:convert';

enum AppEnvironment {
  dev,
  staging,
  prod;

  static AppEnvironment? tryParse(String value) {
    for (final e in values) {
      if (e.name == value) return e;
    }
    return null;
  }
}

class ConfigException implements Exception {
  const ConfigException(this.message);
  final String message;

  @override
  String toString() => 'ConfigException: $message';
}

/// Configuración inmutable inyectada en compilación con
/// `--dart-define-from-file=config/<env>.json`. Nunca se versiona la real.
class AppConfig {
  const AppConfig._({
    required this.environment,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  factory AppConfig.fromEnvironment() => AppConfig.parse(
        environment: const String.fromEnvironment('APP_ENV'),
        supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
        supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      );

  /// Valida y construye. Separado de [fromEnvironment] para poder probarlo.
  factory AppConfig.parse({
    required String environment,
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) {
    final env = AppEnvironment.tryParse(environment.trim());
    if (env == null) {
      throw ConfigException(
        'APP_ENV inválido: "$environment". Usa dev, staging o prod.',
      );
    }

    final uri = Uri.tryParse(supabaseUrl.trim());
    if (uri == null || uri.host.isEmpty) {
      throw const ConfigException('SUPABASE_URL ausente o malformada.');
    }
    const localHosts = {'localhost', '127.0.0.1', '10.0.2.2'};
    final allowHttp =
        env == AppEnvironment.dev && localHosts.contains(uri.host);
    if (uri.scheme != 'https' && !(allowHttp && uri.scheme == 'http')) {
      throw const ConfigException('SUPABASE_URL debe usar https.');
    }

    final key = supabaseAnonKey.trim();
    if (key.isEmpty) {
      throw const ConfigException('SUPABASE_ANON_KEY ausente.');
    }
    if (_looksLikeServiceKey(key)) {
      throw const ConfigException(
        'La clave configurada es de servicio (service_role/secret). '
        'Nunca debe estar en la app: usa la anon/publishable key.',
      );
    }

    return AppConfig._(
      environment: env,
      supabaseUrl: uri.toString(),
      supabaseAnonKey: key,
    );
  }

  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get isProd => environment == AppEnvironment.prod;

  static bool _looksLikeServiceKey(String key) {
    if (key.startsWith('sb_secret_')) return true;
    final parts = key.split('.');
    if (parts.length != 3) return false;
    try {
      final payload =
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final json = jsonDecode(payload);
      return json is Map<String, dynamic> && json['role'] == 'service_role';
    } on FormatException {
      return false;
    }
  }
}
