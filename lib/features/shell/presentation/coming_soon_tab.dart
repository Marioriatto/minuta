import 'package:flutter/material.dart';

import '../../../core/ui/icon_badge.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Marcador de pestañas cuyo contenido llega en fases posteriores.
class ComingSoonTab extends StatelessWidget {
  const ComingSoonTab({required this.title, required this.icon, super.key});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconBadge(icon: icon, size: 72),
              const SizedBox(height: 16),
              Text(
                l10n.tabComingSoon,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
