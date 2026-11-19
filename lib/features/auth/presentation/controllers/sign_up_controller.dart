import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth_providers.dart';
import '../../domain/auth_validators.dart';
import 'auth_form_state.dart';

class SignUpController extends Notifier<AuthFormState> {
  bool _disposed = false;

  @override
  AuthFormState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const AuthFormState();
  }

  Future<void> submit({
    required String email,
    required String password,
    required String confirmation,
  }) async {
    final emailError = AuthValidators.email(email);
    final passwordError = AuthValidators.newPassword(password);
    final confirmError = AuthValidators.confirmation(password, confirmation);
    if (emailError != null || passwordError != null || confirmError != null) {
      state = AuthFormState(
        emailError: emailError,
        passwordError: passwordError,
        confirmError: confirmError,
      );
      return;
    }
    state = const AuthFormState(busy: true);
    final result = await ref.read(signUpWithEmailProvider)(
      email: email,
      password: password,
      confirmation: confirmation,
    );
    if (_disposed) return;
    state = result.when(
      ok: (_) => const AuthFormState(completed: true),
      err: (failure) => AuthFormState(failure: failure),
    );
  }
}

final signUpControllerProvider =
    NotifierProvider<SignUpController, AuthFormState>(
  SignUpController.new,
);
