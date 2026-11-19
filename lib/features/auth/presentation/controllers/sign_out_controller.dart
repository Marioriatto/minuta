import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth_providers.dart';
import 'auth_form_state.dart';

class SignOutController extends Notifier<AuthFormState> {
  bool _disposed = false;

  @override
  AuthFormState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const AuthFormState();
  }

  Future<void> signOut() async {
    state = const AuthFormState(busy: true);
    final result = await ref.read(signOutProvider)();
    if (_disposed) return;
    state = result.when(
      ok: (_) => const AuthFormState(completed: true),
      err: (failure) => AuthFormState(failure: failure),
    );
  }
}

final signOutControllerProvider =
    NotifierProvider<SignOutController, AuthFormState>(
  SignOutController.new,
);
