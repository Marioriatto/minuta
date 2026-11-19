import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth_providers.dart';
import 'auth_form_state.dart';

class ResendVerificationController extends Notifier<AuthFormState> {
  bool _disposed = false;

  @override
  AuthFormState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const AuthFormState();
  }

  Future<void> submit({required String email}) async {
    state = const AuthFormState(busy: true);
    final result = await ref.read(resendVerificationProvider)(email: email);
    if (_disposed) return;
    state = result.when(
      ok: (_) => const AuthFormState(completed: true),
      err: (failure) => AuthFormState(failure: failure),
    );
  }
}

final resendVerificationControllerProvider =
    NotifierProvider<ResendVerificationController, AuthFormState>(
  ResendVerificationController.new,
);
