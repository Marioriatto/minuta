import 'dart:async';
import 'dart:io';

import 'package:colchon_minuta/core/errors/app_failure.dart';
import 'package:colchon_minuta/core/errors/failure_mapper.dart';
import 'package:colchon_minuta/core/errors/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('mapToFailure', () {
    test('errores de red', () {
      expect(mapToFailure(const SocketException('x')), isA<NetworkFailure>());
      expect(mapToFailure(TimeoutException('x')), isA<NetworkFailure>());
    });

    test('PostgREST: RLS, JWT, no encontrado, validación, servidor', () {
      PostgrestException pg(String code) =>
          PostgrestException(message: 'm', code: code);
      expect(mapToFailure(pg('42501')), isA<ForbiddenFailure>());
      expect(mapToFailure(pg('PGRST301')), isA<UnauthorizedFailure>());
      expect(mapToFailure(pg('PGRST116')), isA<NotFoundFailure>());
      expect(mapToFailure(pg('23505')), isA<ValidationFailure>());
      expect(mapToFailure(pg('XX000')), isA<ServerFailure>());
    });

    test('auth: 401 sin autorización, 400 validación', () {
      expect(
        mapToFailure(const AuthException('m', statusCode: '401')),
        isA<UnauthorizedFailure>(),
      );
      expect(
        mapToFailure(const AuthException('m', statusCode: '400')),
        isA<ValidationFailure>(),
      );
    });

    test('desconocido conserva la causa y AppFailure pasa intacto', () {
      final f = mapToFailure(StateError('boom'));
      expect(f, isA<UnknownFailure>());
      expect(f.cause, isA<StateError>());
      const original = ForbiddenFailure();
      expect(identical(mapToFailure(original), original), isTrue);
    });
  });

  group('runCatching', () {
    test('Ok cuando no hay excepción', () async {
      final r = await runCatching(() async => 42);
      expect(r.when(ok: (v) => v, err: (_) => -1), 42);
    });

    test('Err con la falla mapeada', () async {
      final r = await runCatching<int>(() async => throw const SocketException('x'));
      expect(r.when(ok: (_) => null, err: (f) => f), isA<NetworkFailure>());
    });
  });
}
