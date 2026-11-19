import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth_providers.dart';
import '../../domain/social_provider.dart';
import 'auth_form_state.dart';

class SocialSignInController extends Notifier<AuthFormState> {
  bool _disposed = false;

  @override
  AuthFormState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const AuthFormState();
  }

  Future<void> signIn(SocialProvider provider) async {
    state = const AuthFormState(busy: true);
    final result = await ref.read(signInWithSocialProvider)(provider);
    if (_disposed) return;
    // El éxito real llega por el deep link y el cambio de sesión.
    state = result.when(
      ok: (_) => const AuthFormState(),
      err: (failure) => AuthFormState(failure: failure),
    );
  }
}

final socialSignInControllerProvider =
    NotifierProvider<SocialSignInController, AuthFormState>(
  SocialSignInController.new,
);
