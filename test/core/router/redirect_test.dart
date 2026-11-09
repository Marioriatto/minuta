import 'package:colchon_minuta/core/router/app_router.dart';
import 'package:colchon_minuta/core/router/session_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('redirectForSession', () {
    test('sesión desconocida → splash', () {
      expect(redirectForSession(SessionStatus.unknown, AppRoutes.home), AppRoutes.splash);
      expect(redirectForSession(SessionStatus.unknown, AppRoutes.splash), isNull);
    });

    test('sin sesión → login', () {
      expect(redirectForSession(SessionStatus.unauthenticated, AppRoutes.home), AppRoutes.login);
      expect(redirectForSession(SessionStatus.unauthenticated, AppRoutes.login), isNull);
    });

    test('con sesión → fuera de login/splash, resto sin tocar', () {
      expect(redirectForSession(SessionStatus.authenticated, AppRoutes.login), AppRoutes.home);
      expect(redirectForSession(SessionStatus.authenticated, AppRoutes.splash), AppRoutes.home);
      expect(redirectForSession(SessionStatus.authenticated, AppRoutes.home), isNull);
    });
  });
}
