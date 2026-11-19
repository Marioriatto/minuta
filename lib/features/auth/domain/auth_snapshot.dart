import 'auth_user.dart';

enum AuthEvent { signedIn, signedOut, passwordRecovery }

/// Estado de la sesión en un instante.
class AuthSnapshot {
  const AuthSnapshot(this.event, [this.user]);

  final AuthEvent event;
  final AuthUser? user;
}
