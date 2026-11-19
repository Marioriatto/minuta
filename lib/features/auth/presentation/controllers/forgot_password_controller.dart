import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth_providers.dart';
import '../../domain/auth_validators.dart';
import 'auth_form_state.dart';

class ForgotPasswordController extends Notifier<AuthFormState> {
  bool _disposed = false;

  @override
  AuthFormState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const AuthFormState();
  }

  Future<void> submit({required String email}) async {
    final emailError = AuthValidators.email(email);
    if (emailError != null) {
      state = AuthFormState(emailError: emailError);
      return;
    }
    state = const AuthFormState(busy: true);
    final result = await ref.read(requestPasswordResetProvider)(email: email);
    if (_disposed) return;
    state = result.when(
      ok: (_) => const AuthFormState(completed: true),
      err: (failure) => AuthFormState(failure: failure),
    );
  }
}

final forgotPasswordControllerProvider =
    NotifierProvider<ForgotPasswordController, AuthFormState>(
  ForgotPasswordController.new,
);
