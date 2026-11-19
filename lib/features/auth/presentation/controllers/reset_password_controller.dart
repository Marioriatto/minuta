import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth_providers.dart';
import '../../domain/auth_validators.dart';
import 'auth_form_state.dart';

class ResetPasswordController extends Notifier<AuthFormState> {
  bool _disposed = false;

  @override
  AuthFormState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const AuthFormState();
  }

  Future<void> submit({
    required String password,
    required String confirmation,
  }) async {
    final passwordError = AuthValidators.newPassword(password);
    final confirmError = AuthValidators.confirmation(password, confirmation);
    if (passwordError != null || confirmError != null) {
      state = AuthFormState(
        passwordError: passwordError,
        confirmError: confirmError,
      );
      return;
    }
    state = const AuthFormState(busy: true);
    final result = await ref.read(resetPasswordProvider)(
      newPassword: password,
      confirmation: confirmation,
    );
    if (_disposed) return;
    // Al guardar, la sesión se actualiza y el router sale de esta pantalla.
    state = result.when(
      ok: (_) => const AuthFormState(completed: true),
      err: (failure) => AuthFormState(failure: failure),
    );
  }
}

final resetPasswordControllerProvider =
    NotifierProvider<ResetPasswordController, AuthFormState>(
  ResetPasswordController.new,
);
