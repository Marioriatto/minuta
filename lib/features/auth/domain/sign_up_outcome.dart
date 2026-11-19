enum SignUpOutcome {
  /// La cuenta se creó y falta confirmar el correo.
  needsEmailVerification,

  /// La cuenta se creó y ya hay sesión (confirmación de correo desactivada).
  signedIn,
}
