import 'package:colchon_minuta/app/app_gate.dart';
import 'package:colchon_minuta/app/router/app_router.dart';
import 'package:colchon_minuta/core/router/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('redirectForGate', () {
    test('cargando → splash', () {
      expect(
        redirectForGate(AppGate.loading, AppRoutes.home),
        AppRoutes.splash,
      );
      expect(redirectForGate(AppGate.loading, AppRoutes.splash), isNull);
    });

    test('sin sesión: solo rutas públicas', () {
      for (final route in [
        AppRoutes.login,
        AppRoutes.signUp,
        AppRoutes.verifyEmail,
        AppRoutes.forgotPassword,
      ]) {
        expect(
          redirectForGate(AppGate.signedOut, route),
          isNull,
          reason: route,
        );
      }
      for (final route in [
        AppRoutes.home,
        AppRoutes.settings,
        AppRoutes.settingsPermissions,
        AppRoutes.settingsBabies,
        AppRoutes.permissionsIntro,
        AppRoutes.firstProfile,
        AppRoutes.resetPassword,
        AppRoutes.authCallback,
      ]) {
        expect(
          redirectForGate(AppGate.signedOut, route),
          AppRoutes.login,
          reason: route,
        );
      }
    });

    test('recuperación de contraseña fuerza la pantalla de nueva contraseña',
        () {
      expect(
        redirectForGate(AppGate.recovery, AppRoutes.home),
        AppRoutes.resetPassword,
      );
      expect(
        redirectForGate(AppGate.recovery, AppRoutes.resetPassword),
        isNull,
      );
    });

    test('primera vez: introducción de permisos', () {
      expect(
        redirectForGate(AppGate.needsPermissionsIntro, AppRoutes.home),
        AppRoutes.permissionsIntro,
      );
      expect(
        redirectForGate(
          AppGate.needsPermissionsIntro,
          AppRoutes.permissionsIntro,
        ),
        isNull,
      );
    });

    test('sin perfil activo: crear el primero', () {
      expect(
        redirectForGate(AppGate.needsFirstProfile, AppRoutes.home),
        AppRoutes.firstProfile,
      );
      expect(
        redirectForGate(AppGate.needsFirstProfile, AppRoutes.permissionsIntro),
        AppRoutes.firstProfile,
      );
      expect(
        redirectForGate(AppGate.needsFirstProfile, AppRoutes.firstProfile),
        isNull,
      );
    });

    test('error al cargar perfiles: pantalla de reintento', () {
      expect(
        redirectForGate(AppGate.profilesError, AppRoutes.home),
        AppRoutes.profilesError,
      );
      expect(
        redirectForGate(AppGate.profilesError, AppRoutes.profilesError),
        isNull,
      );
    });

    test('con sesión lista: fuera de las pantallas de entrada', () {
      for (final route in [
        '/',
        AppRoutes.splash,
        AppRoutes.login,
        AppRoutes.signUp,
        AppRoutes.resetPassword,
        AppRoutes.permissionsIntro,
        AppRoutes.firstProfile,
        AppRoutes.profilesError,
        AppRoutes.authCallback,
      ]) {
        expect(
          redirectForGate(AppGate.ready, route),
          AppRoutes.home,
          reason: route,
        );
      }
      for (final route in [
        AppRoutes.home,
        AppRoutes.alerts,
        AppRoutes.settingsPermissions,
        AppRoutes.settingsBabies,
        AppRoutes.settingsBabiesNew,
        AppRoutes.settingsBabyEdit('abc'),
      ]) {
        expect(redirectForGate(AppGate.ready, route), isNull, reason: route);
      }
    });
  });
}
