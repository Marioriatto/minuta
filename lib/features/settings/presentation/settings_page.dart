import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/ui/failure_l10n.dart';
import '../../../core/ui/primary_button.dart';
import '../../../core/ui/surface_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/auth_providers.dart';
import '../../auth/presentation/controllers/sign_out_controller.dart';
import '../../babies/babies_providers.dart';

/// Ajustes: cuenta, perfiles de bebé, permisos y cerrar sesión. La cuna
/// vinculada se añade en su fase.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final email = ref.watch(authSnapshotProvider).value?.user?.email;
    final signOut = ref.watch(signOutControllerProvider);
    final activeBabies = ref.watch(activeBabiesProvider);

    ref.listen(signOutControllerProvider, (previous, next) {
      final failure = next.failure;
      if (failure != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.forFailure(failure))),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SurfaceCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(
                    l10n.settingsAccount,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(email ?? '—'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.child_care_rounded),
                  title: Text(
                    l10n.settingsBabies,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    l10n.settingsBabiesSubtitle(activeBabies.length),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.settingsBabies),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.verified_user_outlined),
                  title: Text(
                    l10n.settingsPermissions,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(l10n.settingsPermissionsSubtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.settingsPermissions),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: l10n.settingsSignOut,
            tone: ButtonTone.destructive,
            busy: signOut.busy,
            onPressed: () =>
                ref.read(signOutControllerProvider.notifier).signOut(),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              l10n.appTitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
