import 'dart:convert';

import 'package:colchon_minuta/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

String _fakeJwt(String role) {
  String enc(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${enc({'alg': 'HS256'})}.${enc({'role': role})}.firma';
}

AppConfig _parse({
  String env = 'dev',
  String url = 'https://abc.supabase.co',
  String key = 'clave-publica',
}) =>
    AppConfig.parse(environment: env, supabaseUrl: url, supabaseAnonKey: key);

void main() {
  group('AppConfig.parse', () {
    test('acepta una configuración válida', () {
      final c = _parse(env: 'prod', key: _fakeJwt('anon'));
      expect(c.environment, AppEnvironment.prod);
      expect(c.isProd, isTrue);
    });

    test('rechaza APP_ENV desconocido o vacío', () {
      expect(() => _parse(env: 'qa'), throwsA(isA<ConfigException>()));
      expect(() => _parse(env: ''), throwsA(isA<ConfigException>()));
    });

    test('rechaza URL vacía o malformada', () {
      expect(() => _parse(url: ''), throwsA(isA<ConfigException>()));
      expect(() => _parse(url: 'no es url'), throwsA(isA<ConfigException>()));
    });

    test('exige https salvo http a localhost en dev', () {
      expect(
        () => _parse(url: 'http://abc.supabase.co'),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => _parse(env: 'prod', url: 'http://localhost:54321'),
        throwsA(isA<ConfigException>()),
      );
      expect(_parse(url: 'http://10.0.2.2:54321').supabaseUrl, contains('10.0.2.2'));
    });

    test('rechaza clave vacía', () {
      expect(() => _parse(key: '  '), throwsA(isA<ConfigException>()));
    });

    test('rechaza claves de servicio', () {
      expect(
        () => _parse(key: _fakeJwt('service_role')),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => _parse(key: 'sb_secret_abc123'),
        throwsA(isA<ConfigException>()),
      );
    });
  });
}
