import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Pantalla mientras se resuelve el estado de la sesión.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: CircularProgressIndicator.adaptive(
            semanticsLabel: AppLocalizations.of(context).commonLoading,
          ),
        ),
      );
}
