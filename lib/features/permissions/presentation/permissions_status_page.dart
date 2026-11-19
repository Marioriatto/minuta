import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/primary_button.dart';
import '../../../core/ui/state_view.dart';
import '../../../core/ui/surface_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/app_permission.dart';
import '../permissions_providers.dart';

/// Estado actual de los permisos (Ajustes → Permisos). Los permisos del sistema
/// no se pueden revocar desde la app: se enlaza a los ajustes del sistema.
class PermissionsStatusPage extends ConsumerStatefulWidget {
  const PermissionsStatusPage({super.key});

  @override
  ConsumerState<PermissionsStatusPage> createState() =>
      _PermissionsStatusPageState();
}

class _PermissionsStatusPageState extends ConsumerState<PermissionsStatusPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver de los ajustes del sistema se refrescan los estados.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(permissionStatusesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statuses = ref.watch(permissionStatusesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsPermissions)),
      body: StateView<Map<AppPermission, AppPermissionStatus>>(
        value: statuses,
        onRetry: () => ref.invalidate(permissionStatusesProvider),
        builder: (context, data) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(l10n.permissionSettingsHint),
            const SizedBox(height: 16),
            SurfaceCard(
              child: Column(
                children: [
                  for (final entry in data.entries) ...[
                    ListTile(
                      title: Text(
                        entry.key == AppPermission.notifications
                            ? l10n.permissionNotificationsTitle
                            : l10n.permissionMicrophoneTitle,
                      ),
                      trailing: Text(
                        entry.value == AppPermissionStatus.granted
                            ? l10n.permissionGranted
                            : l10n.permissionDenied,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: entry.value == AppPermissionStatus.granted
                              ? Theme.of(context).colorScheme.tertiary
                              : Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    if (entry.key != data.keys.last) const Divider(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: l10n.permissionOpenSettings,
              tone: ButtonTone.tonal,
              icon: Icons.settings_outlined,
              onPressed: () =>
                  ref.read(permissionsGatewayProvider).openSystemSettings(),
            ),
          ],
        ),
      ),
    );
  }
}
