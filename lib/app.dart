import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router/app_router.dart';
import 'core/router/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/ui/offline_banner.dart';
import 'features/notifications/notifications_providers.dart';
import 'l10n/generated/app_localizations.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Registra el token push mientras haya sesión.
    ref.watch(pushRegistrationProvider);
    // Tocar una notificación de alerta abre la pestaña Alertas.
    ref.listen(alertOpenedProvider, (_, next) {
      if (next is AsyncData) router.go(AppRoutes.alerts);
    });

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light(),
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) =>
          OfflineBanner(child: child ?? const SizedBox.shrink()),
    );
  }
}
