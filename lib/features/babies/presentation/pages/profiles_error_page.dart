import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/ui/failure_l10n.dart';
import '../../../../core/ui/icon_badge.dart';
import '../../../../core/ui/primary_button.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/controllers/sign_out_controller.dart';
import '../../babies_providers.dart';

/// Se muestra si no se pudieron cargar los perfiles al iniciar: sin ellos no se
/// sabe si hay que pedir el primero, así que se permite reintentar.
class ProfilesErrorPage extends ConsumerWidget {
  const ProfilesErrorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final error = ref.watch(babiesProvider).error;
    final failure = error is AppFailure ? error : UnknownFailure(cause: error);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    child: IconBadge(icon: Icons.cloud_off_rounded, size: 72),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.profilesErrorTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.forFailure(failure),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: l10n.commonRetry,
                    onPressed: () => ref.invalidate(babiesProvider),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => ref
                          .read(signOutControllerProvider.notifier)
                          .signOut(),
                      child: Text(
                        l10n.settingsSignOut,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
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
