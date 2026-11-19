/// URL a la que Supabase devuelve al usuario tras OAuth, verificación de correo
/// y recuperación de contraseña. Debe estar en las Redirect URLs permitidas del
/// proyecto Supabase y coincidir con el esquema registrado en Android/iOS.
abstract final class AuthRedirect {
  static const url = 'com.colchonminuta.app://login-callback';
}
