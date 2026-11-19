import 'package:colchon_minuta/core/errors/app_failure.dart';
import 'package:colchon_minuta/core/errors/result.dart';
import 'package:colchon_minuta/features/auth/auth_providers.dart';
import 'package:colchon_minuta/features/auth/domain/auth_validators.dart';
import 'package:colchon_minuta/features/auth/domain/social_provider.dart';
import 'package:colchon_minuta/features/auth/presentation/controllers/forgot_password_controller.dart';
import 'package:colchon_minuta/features/auth/presentation/controllers/sign_in_controller.dart';
import 'package:colchon_minuta/features/auth/presentation/controllers/sign_up_controller.dart';
import 'package:colchon_minuta/features/auth/presentation/controllers/social_sign_in_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  group('SignInController', () {
    test('muestra errores por campo y no llama al repositorio', () async {
      container.listen(signInControllerProvider, (_, __) {});
      await container
          .read(signInControllerProvider.notifier)
          .submit(email: '', password: '');
      final state = container.read(signInControllerProvider);
      expect(state.emailError, FieldError.empty);
      expect(state.passwordError, FieldError.empty);
      expect(repo.calls, isEmpty);
    });

    test('propaga la falla de credenciales', () async {
      repo.signInResult = const Err<void>(InvalidCredentialsFailure());
      container.listen(signInControllerProvider, (_, __) {});
      await container
          .read(signInControllerProvider.notifier)
          .submit(email: 'a@b.co', password: 'mala');
      final state = container.read(signInControllerProvider);
      expect(state.failure, isA<InvalidCredentialsFailure>());
      expect(state.busy, isFalse);
      expect(state.completed, isFalse);
    });

    test('éxito marca completed', () async {
      container.listen(signInControllerProvider, (_, __) {});
      await container
          .read(signInControllerProvider.notifier)
          .submit(email: 'a@b.co', password: 'buena');
      expect(container.read(signInControllerProvider).completed, isTrue);
    });
  });

  group('SignUpController', () {
    test('contraseñas distintas', () async {
      container.listen(signUpControllerProvider, (_, __) {});
      await container.read(signUpControllerProvider.notifier).submit(
            email: 'a@b.co',
            password: 'larga-123',
            confirmation: 'otra-1234',
          );
      expect(
        container.read(signUpControllerProvider).confirmError,
        FieldError.mismatch,
      );
      expect(repo.calls, isEmpty);
    });

    test('registro correcto completa el flujo', () async {
      container.listen(signUpControllerProvider, (_, __) {});
      await container.read(signUpControllerProvider.notifier).submit(
            email: 'a@b.co',
            password: 'larga-123',
            confirmation: 'larga-123',
          );
      expect(container.read(signUpControllerProvider).completed, isTrue);
      expect(repo.calls, ['signUp:a@b.co']);
    });
  });

  test('ForgotPasswordController completa sin revelar si el correo existe',
      () async {
    container.listen(forgotPasswordControllerProvider, (_, __) {});
    await container
        .read(forgotPasswordControllerProvider.notifier)
        .submit(email: 'a@b.co');
    expect(container.read(forgotPasswordControllerProvider).completed, isTrue);
  });

  test('SocialSignInController delega por proveedor y reporta fallas',
      () async {
    repo.socialResult = const Err<void>(UnknownFailure());
    container.listen(socialSignInControllerProvider, (_, __) {});
    await container
        .read(socialSignInControllerProvider.notifier)
        .signIn(SocialProvider.google);
    expect(repo.calls, ['social:google']);
    expect(
      container.read(socialSignInControllerProvider).failure,
      isA<UnknownFailure>(),
    );
  });
}
