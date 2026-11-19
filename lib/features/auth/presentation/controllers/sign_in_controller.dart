import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth_providers.dart';
import '../../domain/auth_validators.dart';
import 'auth_form_state.dart';

class SignInController extends Notifier<AuthFormState> {
  bool _disposed = false;

  @override
  AuthFormState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const AuthFormState();
  }

  Future<void> submit({required String email, required String password}) async {
    final emailError = AuthValidators.email(email);
    final passwordError = AuthValidators.loginPassword(password);
    if (emailError != null || passwordError != null) {
      state = AuthFormState(
        emailError: emailError,
        passwordError: passwordError,
      );
      return;
    }
    state = const AuthFormState(busy: true);
    final result = await ref.read(signInWithEmailProvider)(
      email: email,
      password: password,
    );
    if (_disposed) return;
    // Si sale bien, el cambio de sesión redirige solo: no hay navegación aquí.
    state = result.when(
      ok: (_) => const AuthFormState(completed: true),
      err: (failure) => AuthFormState(failure: failure),
    );
  }
}

final signInControllerProvider =
    NotifierProvider<SignInController, AuthFormState>(
  SignInController.new,
);
