/// Usuario autenticado. El correo puede faltar (p. ej. proveedores sociales
/// que no lo comparten).
class AuthUser {
  const AuthUser({required this.id, this.email});

  final String id;
  final String? email;
}
