import 'package:colchon_minuta/core/errors/result.dart';
import 'package:colchon_minuta/features/auth/domain/auth_repository.dart';
import 'package:colchon_minuta/features/auth/domain/auth_snapshot.dart';
import 'package:colchon_minuta/features/auth/domain/sign_up_outcome.dart';
import 'package:colchon_minuta/features/auth/domain/social_provider.dart';

/// Repositorio falso configurable que registra las llamadas recibidas.
class FakeAuthRepository implements AuthRepository {
  Result<void> signInResult = const Ok<void>(null);
  Result<SignUpOutcome> signUpResult =
      const Ok(SignUpOutcome.needsEmailVerification);
  Result<void> resendResult = const Ok<void>(null);
  Result<void> resetRequestResult = const Ok<void>(null);
  Result<void> updatePasswordResult = const Ok<void>(null);
  Result<void> socialResult = const Ok<void>(null);
  Result<void> signOutResult = const Ok<void>(null);

  final calls = <String>[];

  @override
  Stream<AuthSnapshot> watchSession() => const Stream.empty();

  @override
  Future<Result<void>> signInWithPassword({
    required String email,
    required String password,
  }) async {
    calls.add('signIn:$email');
    return signInResult;
  }

  @override
  Future<Result<SignUpOutcome>> signUp({
    required String email,
    required String password,
  }) async {
    calls.add('signUp:$email');
    return signUpResult;
  }

  @override
  Future<Result<void>> resendVerification({required String email}) async {
    calls.add('resend:$email');
    return resendResult;
  }

  @override
  Future<Result<void>> sendPasswordReset({required String email}) async {
    calls.add('reset:$email');
    return resetRequestResult;
  }

  @override
  Future<Result<void>> updatePassword({required String newPassword}) async {
    calls.add('updatePassword');
    return updatePasswordResult;
  }

  @override
  Future<Result<void>> signInWithSocial(SocialProvider provider) async {
    calls.add('social:${provider.name}');
    return socialResult;
  }

  @override
  Future<Result<void>> signOut() async {
    calls.add('signOut');
    return signOutResult;
  }
}
