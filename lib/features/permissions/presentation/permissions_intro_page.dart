import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/failure_l10n.dart';
import '../../../core/ui/icon_badge.dart';
import '../../../core/ui/message_banner.dart';
import '../../../core/ui/primary_button.dart';
import '../../../core/ui/surface_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'permissions_intro_controller.dart';

class PermissionsIntroPage extends ConsumerWidget {
  const PermissionsIntroPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(permissionsIntroControllerProvider);
    final controller = ref.read(permissionsIntroControllerProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    child:
                        IconBadge(icon: Icons.verified_user_outlined, size: 80),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.permissionsTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.permissionsSubtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _PermissionToggle(
                    icon: Icons.notifications_none_rounded,
                    title: l10n.permissionNotificationsTitle,
                    body: l10n.permissionNotificationsBody,
                    value: state.notifications,
                    onChanged: state.busy ? null : controller.setNotifications,
                  ),
                  const SizedBox(height: 12),
                  _PermissionToggle(
                    icon: Icons.mic_none_rounded,
                    title: l10n.permissionMicrophoneTitle,
                    body: l10n.permissionMicrophoneBody,
                    value: state.microphone,
                    onChanged: state.busy ? null : controller.setMicrophone,
                  ),
                  if (state.failure != null) ...[
                    const SizedBox(height: 16),
                    MessageBanner(message: l10n.forFailure(state.failure!)),
                  ],
                  const SizedBox(height: 32),
                  PrimaryButton(
                    label: l10n.commonContinue,
                    busy: state.busy,
                    onPressed: controller.submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionToggle extends StatelessWidget {
  const _PermissionToggle({
    required this.icon,
    required this.title,
    required this.body,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IconBadge(icon: icon, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            label: title,
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}
