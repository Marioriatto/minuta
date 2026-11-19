import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../features/alerts/presentation/alerts_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/auth/presentation/pages/sign_up_page.dart';
import '../../features/auth/presentation/pages/verify_email_page.dart';
import '../../features/babies/presentation/pages/babies_page.dart';
import '../../features/babies/presentation/pages/baby_form_page.dart';
import '../../features/babies/presentation/pages/profiles_error_page.dart';
import '../../features/cradle/presentation/cradle_page.dart';
import '../../features/dashboard/presentation/home_dashboard_page.dart';
import '../../features/devices/presentation/pages/accessories_page.dart';
import '../../features/devices/presentation/pages/claim_device_page.dart';
import '../../features/lights/presentation/lights_page.dart';
import '../../features/permissions/presentation/permissions_intro_page.dart';
import '../../features/permissions/presentation/permissions_status_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/shell/presentation/coming_soon_tab.dart';
import '../../features/shell/presentation/splash_page.dart';
import '../../l10n/generated/app_localizations.dart';
import '../app_gate.dart';

const _publicRoutes = {
  AppRoutes.login,
  AppRoutes.signUp,
  AppRoutes.verifyEmail,
  AppRoutes.forgotPassword,
};

/// Pantallas de entrada que no deben verse con la sesión lista.
const _entryRoutes = {
  '/',
  AppRoutes.splash,
  AppRoutes.login,
  AppRoutes.signUp,
  AppRoutes.verifyEmail,
  AppRoutes.forgotPassword,
  AppRoutes.resetPassword,
  AppRoutes.permissionsIntro,
  AppRoutes.firstProfile,
  AppRoutes.profilesError,
  AppRoutes.authCallback,
};

/// Lógica pura de redirección (probada de forma aislada). `null` = sin cambios.
String? redirectForGate(AppGate gate, String location) {
  switch (gate) {
    case AppGate.loading:
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    case AppGate.signedOut:
      return _publicRoutes.contains(location) ? null : AppRoutes.login;
    case AppGate.recovery:
      return location == AppRoutes.resetPassword
          ? null
          : AppRoutes.resetPassword;
    case AppGate.needsPermissionsIntro:
      return location == AppRoutes.permissionsIntro
          ? null
          : AppRoutes.permissionsIntro;
    case AppGate.needsFirstProfile:
      return location == AppRoutes.firstProfile ? null : AppRoutes.firstProfile;
    case AppGate.profilesError:
      return location == AppRoutes.profilesError
          ? null
          : AppRoutes.profilesError;
    case AppGate.ready:
      return _entryRoutes.contains(location) ? AppRoutes.home : null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<AppGate>(appGateProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) =>
        redirectForGate(ref.read(appGateProvider), state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.authCallback,
        builder: (_, __) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (_, __) => const SignUpPage(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (_, state) => VerifyEmailPage(
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (_, __) => const ResetPasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.permissionsIntro,
        builder: (_, __) => const PermissionsIntroPage(),
      ),
      GoRoute(
        path: AppRoutes.firstProfile,
        builder: (_, __) => const BabyFormPage(isFirst: true),
      ),
      GoRoute(
        path: AppRoutes.profilesError,
        builder: (_, __) => const ProfilesErrorPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, __) => const HomeDashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.alerts,
                builder: (_, __) => const AlertsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.records,
                builder: (context, _) => ComingSoonTab(
                  title: AppLocalizations.of(context).navRecords,
                  icon: Icons.bar_chart_outlined,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.accessories,
                builder: (_, __) => const AccessoriesPage(),
                routes: [
                  GoRoute(
                    path: 'claim',
                    builder: (_, __) => const ClaimDevicePage(),
                  ),
                  GoRoute(
                    path: 'lights/:id',
                    builder: (_, state) => LightsPage(
                      deviceId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: 'cradle/:id',
                    builder: (_, state) => CradlePage(
                      deviceId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (_, __) => const SettingsPage(),
                routes: [
                  GoRoute(
                    path: 'permissions',
                    builder: (_, __) => const PermissionsStatusPage(),
                  ),
                  GoRoute(
                    path: 'babies',
                    builder: (_, __) => const BabiesPage(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (_, __) => const BabyFormPage(),
                      ),
                      GoRoute(
                        path: ':id/edit',
                        builder: (_, state) => BabyFormPage(
                          babyId: state.pathParameters['id'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
