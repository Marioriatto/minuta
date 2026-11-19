import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import 'auth_repository.dart';
import 'auth_validators.dart';
import 'sign_up_outcome.dart';
import 'social_provider.dart';

/// Cada caso de uso vuelve a validar sus entradas: la UI valida para mostrar
/// mensajes por campo, pero el dominio no confía en ella.

class SignInWithEmail {
  const SignInWithEmail(this._repository);
  final AuthRepository _repository;

  Future<Result<void>> call({
    required String email,
    required String password,
  }) async {
    if (AuthValidators.email(email) != null ||
        AuthValidators.loginPassword(password) != null) {
      return const Err(ValidationFailure());
    }
    return _repository.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }
}

class SignUpWithEmail {
  const SignUpWithEmail(this._repository);
  final AuthRepository _repository;

  Future<Result<SignUpOutcome>> call({
    required String email,
    required String password,
    required String confirmation,
  }) async {
    if (AuthValidators.email(email) != null ||
        AuthValidators.newPassword(password) != null ||
        AuthValidators.confirmation(password, confirmation) != null) {
      return const Err(ValidationFailure());
    }
    return _repository.signUp(email: email.trim(), password: password);
  }
}

class ResendVerification {
  const ResendVerification(this._repository);
  final AuthRepository _repository;

  Future<Result<void>> call({required String email}) async {
    if (AuthValidators.email(email) != null) {
      return const Err(ValidationFailure());
    }
    return _repository.resendVerification(email: email.trim());
  }
}

class RequestPasswordReset {
  const RequestPasswordReset(this._repository);
  final AuthRepository _repository;

  Future<Result<void>> call({required String email}) async {
    if (AuthValidators.email(email) != null) {
      return const Err(ValidationFailure());
    }
    return _repository.sendPasswordReset(email: email.trim());
  }
}

class ResetPassword {
  const ResetPassword(this._repository);
  final AuthRepository _repository;

  Future<Result<void>> call({
    required String newPassword,
    required String confirmation,
  }) async {
    if (AuthValidators.newPassword(newPassword) != null ||
        AuthValidators.confirmation(newPassword, confirmation) != null) {
      return const Err(ValidationFailure());
    }
    return _repository.updatePassword(newPassword: newPassword);
  }
}

class SignInWithSocial {
  const SignInWithSocial(this._repository);
  final AuthRepository _repository;

  Future<Result<void>> call(SocialProvider provider) =>
      _repository.signInWithSocial(provider);
}

class SignOut {
  const SignOut(this._repository);
  final AuthRepository _repository;

  Future<Result<void>> call() => _repository.signOut();
}
