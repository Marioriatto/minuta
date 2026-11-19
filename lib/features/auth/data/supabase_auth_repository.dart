import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/errors/run_catching.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_snapshot.dart';
import '../domain/auth_user.dart';
import '../domain/sign_up_outcome.dart';
import '../domain/social_provider.dart';
import 'auth_redirect.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final sb.SupabaseClient _client;

  sb.GoTrueClient get _auth => _client.auth;

  @override
  Stream<AuthSnapshot> watchSession() async* {
    yield _snapshot(null, _auth.currentSession);
    await for (final state in _auth.onAuthStateChange) {
      yield _snapshot(state.event, state.session);
    }
  }

  AuthSnapshot _snapshot(sb.AuthChangeEvent? event, sb.Session? session) {
    final user = session?.user;
    final authUser =
        user == null ? null : AuthUser(id: user.id, email: user.email);
    if (event == sb.AuthChangeEvent.passwordRecovery) {
      return AuthSnapshot(AuthEvent.passwordRecovery, authUser);
    }
    return authUser == null
        ? const AuthSnapshot(AuthEvent.signedOut)
        : AuthSnapshot(AuthEvent.signedIn, authUser);
  }

  @override
  Future<Result<void>> signInWithPassword({
    required String email,
    required String password,
  }) =>
      runCatching<void>(() async {
        await _auth.signInWithPassword(email: email, password: password);
      });

  @override
  Future<Result<SignUpOutcome>> signUp({
    required String email,
    required String password,
  }) =>
      runCatching<SignUpOutcome>(() async {
        final response = await _auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: AuthRedirect.url,
        );
        return response.session == null
            ? SignUpOutcome.needsEmailVerification
            : SignUpOutcome.signedIn;
      });

  @override
  Future<Result<void>> resendVerification({required String email}) =>
      runCatching<void>(() async {
        await _auth.resend(
          type: sb.OtpType.signup,
          email: email,
          emailRedirectTo: AuthRedirect.url,
        );
      });

  @override
  Future<Result<void>> sendPasswordReset({required String email}) =>
      runCatching<void>(() async {
        await _auth.resetPasswordForEmail(email, redirectTo: AuthRedirect.url);
      });

  @override
  Future<Result<void>> updatePassword({required String newPassword}) =>
      runCatching<void>(() async {
        await _auth.updateUser(sb.UserAttributes(password: newPassword));
      });

  @override
  Future<Result<void>> signInWithSocial(SocialProvider provider) =>
      runCatching<void>(() async {
        final launched = await _auth.signInWithOAuth(
          switch (provider) {
            SocialProvider.google => sb.OAuthProvider.google,
            SocialProvider.apple => sb.OAuthProvider.apple,
          },
          redirectTo: AuthRedirect.url,
        );
        if (!launched) throw const UnknownFailure();
      });

  @override
  Future<Result<void>> signOut() => runCatching<void>(() async {
        await _auth.signOut();
      });
}
