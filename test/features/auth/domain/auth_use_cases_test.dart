import 'package:colchon_minuta/core/errors/app_failure.dart';
import 'package:colchon_minuta/core/errors/result.dart';
import 'package:colchon_minuta/features/auth/domain/auth_use_cases.dart';
import 'package:colchon_minuta/features/auth/domain/sign_up_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_auth_repository.dart';

AppFailure? _failure<T>(Result<T> r) =>
    r.when<AppFailure?>(ok: (_) => null, err: (f) => f);

void main() {
  late FakeAuthRepository repo;
  setUp(() => repo = FakeAuthRepository());

  group('SignInWithEmail', () {
    test('entradas inválidas no llegan al repositorio', () async {
      final r = await SignInWithEmail(repo)(email: 'x', password: '');
      expect(_failure(r), isA<ValidationFailure>());
      expect(repo.calls, isEmpty);
    });

    test('recorta el correo y delega', () async {
      final r = await SignInWithEmail(repo)(
        email: '  maria@correo.com ',
        password: 'secreto',
      );
      expect(_failure(r), isNull);
      expect(repo.calls, ['signIn:maria@correo.com']);
    });
  });

  group('SignUpWithEmail', () {
    test('rechaza contraseña corta y confirmación distinta', () async {
      final useCase = SignUpWithEmail(repo);
      var r = await useCase(
        email: 'a@b.co',
        password: 'corta',
        confirmation: 'corta',
      );
      expect(_failure(r), isA<ValidationFailure>());
      r = await useCase(
        email: 'a@b.co',
        password: 'larga-123',
        confirmation: 'otra-1234',
      );
      expect(_failure(r), isA<ValidationFailure>());
      expect(repo.calls, isEmpty);
    });

    test('devuelve el resultado del repositorio', () async {
      final r = await SignUpWithEmail(repo)(
        email: 'a@b.co',
        password: 'larga-123',
        confirmation: 'larga-123',
      );
      expect(
        r.when(ok: (v) => v, err: (_) => null),
        SignUpOutcome.needsEmailVerification,
      );
    });
  });

  test('RequestPasswordReset y ResendVerification validan el correo', () async {
    expect(
      _failure(await RequestPasswordReset(repo)(email: 'mal')),
      isA<ValidationFailure>(),
    );
    expect(
      _failure(await ResendVerification(repo)(email: '')),
      isA<ValidationFailure>(),
    );
    expect(repo.calls, isEmpty);
  });

  test('ResetPassword valida longitud y coincidencia', () async {
    final useCase = ResetPassword(repo);
    expect(
      _failure(await useCase(newPassword: 'corta', confirmation: 'corta')),
      isA<ValidationFailure>(),
    );
    expect(
      _failure(
        await useCase(newPassword: 'larga-123', confirmation: 'larga-124'),
      ),
      isA<ValidationFailure>(),
    );
    expect(
      _failure(
        await useCase(newPassword: 'larga-123', confirmation: 'larga-123'),
      ),
      isNull,
    );
    expect(repo.calls, ['updatePassword']);
  });
}
