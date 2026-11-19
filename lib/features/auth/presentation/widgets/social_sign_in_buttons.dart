import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config_provider.dart';
import '../../../../core/ui/primary_button.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/social_provider.dart';
import '../controllers/social_sign_in_controller.dart';

/// "o continúa con" + botones de Google (y Apple en iOS). Sirve para iniciar
/// sesión y para registrarse: Supabase crea la cuenta en el primer acceso.
/// No muestra nada si `SOCIAL_LOGIN` está apagado en la configuración.
class SocialSignInButtons extends ConsumerWidget {
  const SocialSignInButtons({required this.disabled, super.key});

  /// La pantalla tiene otra operación en curso.
  final bool disabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(appConfigProvider).socialLoginEnabled) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final social = ref.watch(socialSignInControllerProvider);
    final providers = socialProvidersFor(
      isIOS: Theme.of(context).platform == TargetPlatform.iOS,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                l10n.authOrContinueWith,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        for (final provider in providers) ...[
          PrimaryButton(
            label: switch (provider) {
              SocialProvider.google => l10n.authContinueGoogle,
              SocialProvider.apple => l10n.authContinueApple,
            },
            tone: ButtonTone.tonal,
            busy: social.busy,
            onPressed: (disabled || social.busy)
                ? null
                : () => ref
                    .read(socialSignInControllerProvider.notifier)
                    .signIn(provider),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
