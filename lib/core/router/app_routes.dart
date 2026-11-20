/// Rutas de la app. Solo constantes: el router vive en `lib/app/router`.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const signUp = '/sign-up';
  static const verifyEmail = '/verify-email';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const permissionsIntro = '/permissions';
  static const firstProfile = '/first-profile';
  static const profilesError = '/profiles-error';

  /// Destino al que Android/iOS pueden entregar el deep link de retorno de
  /// OAuth o de verificación de correo (ver docs/fase1_setup.md).
  static const authCallback = '/login-callback';

  static const home = '/home';
  static const alerts = '/alerts';
  static const records = '/records';
  static const accessories = '/accessories';
  static const accessoriesClaim = '/accessories/claim';

  static String accessoriesLights(String id) => '/accessories/lights/$id';
  static String accessoriesCradle(String id) => '/accessories/cradle/$id';
  static String accessoriesMattress(String id) => '/accessories/mattress/$id';
  static const settings = '/settings';
  static const settingsPermissions = '/settings/permissions';
  static const settingsBabies = '/settings/babies';
  static const settingsBabiesNew = '/settings/babies/new';

  static String settingsBabyEdit(String id) => '/settings/babies/$id/edit';
}
