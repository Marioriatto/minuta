import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'placeholder_pages.dart';
import 'session_status.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const home = '/';
}

/// Lógica pura de redirección por sesión (probada de forma aislada).
/// Devuelve `null` si no hay que redirigir.
String? redirectForSession(SessionStatus status, String location) {
  switch (status) {
    case SessionStatus.unknown:
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    case SessionStatus.unauthenticated:
      return location == AppRoutes.login ? null : AppRoutes.login;
    case SessionStatus.authenticated:
      final inPublic =
          location == AppRoutes.login || location == AppRoutes.splash;
      return inPublic ? AppRoutes.home : null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<SessionStatus>(sessionStatusProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) => redirectForSession(
      ref.read(sessionStatusProvider),
      state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const PlaceholderPage(name: 'splash'),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const PlaceholderPage(name: 'login'),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, __) => const PlaceholderPage(name: 'inicio'),
      ),
    ],
  );
});
