import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Pantalla temporal de Fase 0. Se reemplaza al implementar cada feature.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({required this.name, super.key});
  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(child: Text(l10n.placeholderScreen(name))),
    );
  }
}
