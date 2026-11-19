import 'dart:async';
import 'dart:io';

import 'package:colchon_minuta/core/errors/app_failure.dart';
import 'package:colchon_minuta/core/errors/failure_mapper.dart';
import 'package:colchon_minuta/core/errors/run_catching.dart';
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

    group('auth', () {
      AuthException auth(String code, {String message = 'm', String? status}) =>
          AuthException(message, statusCode: status, code: code);

      test('por código', () {
        expect(
          mapToFailure(auth('invalid_credentials')),
          isA<InvalidCredentialsFailure>(),
        );
        expect(
          mapToFailure(auth('email_not_confirmed')),
          isA<EmailNotConfirmedFailure>(),
        );
        expect(
          mapToFailure(auth('user_already_exists')),
          isA<EmailAlreadyRegisteredFailure>(),
        );
        expect(mapToFailure(auth('weak_password')), isA<WeakPasswordFailure>());
        expect(
          mapToFailure(auth('over_email_send_rate_limit')),
          isA<RateLimitedFailure>(),
        );
      });

      test('respaldo por mensaje cuando no hay código', () {
        expect(
          mapToFailure(
            const AuthException('Invalid login credentials', statusCode: '400'),
          ),
          isA<InvalidCredentialsFailure>(),
        );
        expect(
          mapToFailure(
            const AuthException('Email not confirmed', statusCode: '400'),
          ),
          isA<EmailNotConfirmedFailure>(),
        );
      });

      test('por estado HTTP', () {
        expect(
          mapToFailure(const AuthException('m', statusCode: '401')),
          isA<UnauthorizedFailure>(),
        );
        expect(
          mapToFailure(const AuthException('m', statusCode: '422')),
          isA<ValidationFailure>(),
        );
        expect(
          mapToFailure(const AuthException('m', statusCode: '429')),
          isA<RateLimitedFailure>(),
        );
      });
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
      final r = await runCatching<int>(
        () async => throw const SocketException('x'),
      );
      expect(r.when(ok: (_) => null, err: (f) => f), isA<NetworkFailure>());
    });
  });
}
