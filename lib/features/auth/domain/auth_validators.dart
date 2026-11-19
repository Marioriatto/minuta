enum FieldError { empty, invalidEmail, tooShort, mismatch }

/// Reglas de validación de formularios de cuenta (sin dependencias de UI).
abstract final class AuthValidators {
  /// Debe coincidir (o ser menor) con la longitud mínima configurada en
  /// Supabase Auth.
  static const minPasswordLength = 8;

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static FieldError? email(String value) {
    final v = value.trim();
    if (v.isEmpty) return FieldError.empty;
    return _email.hasMatch(v) ? null : FieldError.invalidEmail;
  }

  /// Al iniciar sesión no se exige longitud: solo que no esté vacía.
  static FieldError? loginPassword(String value) =>
      value.isEmpty ? FieldError.empty : null;

  static FieldError? newPassword(String value) {
    if (value.isEmpty) return FieldError.empty;
    return value.length < minPasswordLength ? FieldError.tooShort : null;
  }

  static FieldError? confirmation(String password, String confirmation) {
    if (confirmation.isEmpty) return FieldError.empty;
    return password == confirmation ? null : FieldError.mismatch;
  }
}
