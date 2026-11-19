import '../../../core/errors/result.dart';
import 'auth_snapshot.dart';
import 'sign_up_outcome.dart';
import 'social_provider.dart';

abstract interface class AuthRepository {
  /// Emite el estado actual al suscribirse y luego cada cambio de sesión.
  Stream<AuthSnapshot> watchSession();

  Future<Result<void>> signInWithPassword({
    required String email,
    required String password,
  });

  Future<Result<SignUpOutcome>> signUp({
    required String email,
    required String password,
  });

  Future<Result<void>> resendVerification({required String email});

  Future<Result<void>> sendPasswordReset({required String email});

  /// Cambia la contraseña de la sesión activa (flujo de recuperación).
  Future<Result<void>> updatePassword({required String newPassword});

  /// Abre el navegador del proveedor; el resultado llega por [watchSession].
  Future<Result<void>> signInWithSocial(SocialProvider provider);

  Future<Result<void>> signOut();
}
