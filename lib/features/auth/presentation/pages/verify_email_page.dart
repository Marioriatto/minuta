import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/ui/failure_l10n.dart';
import '../../../../core/ui/icon_badge.dart';
import '../../../../core/ui/message_banner.dart';
import '../../../../core/ui/primary_button.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../controllers/resend_verification_controller.dart';
import '../widgets/auth_scaffold.dart';

class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({required this.email, super.key});

  final String email;

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  /// Los controladores no se autodestruyen: se limpian al abrir la pantalla.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(resendVerificationControllerProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(resendVerificationControllerProvider);
    final email = widget.email;

    return AuthScaffold(
      header: const IconBadge(icon: Icons.mark_email_unread_outlined),
      title: l10n.authVerifyTitle,
      subtitle: l10n.authVerifyBody(email),
      children: [
        if (state.failure != null) ...[
          MessageBanner(message: l10n.forFailure(state.failure!)),
          const SizedBox(height: 16),
        ],
        if (state.completed) ...[
          MessageBanner(message: l10n.authResendDone, kind: BannerKind.info),
          const SizedBox(height: 16),
        ],
        PrimaryButton(
          label: l10n.authResend,
          tone: ButtonTone.tonal,
          busy: state.busy,
          onPressed: email.isEmpty
              ? null
              : () => ref
                  .read(resendVerificationControllerProvider.notifier)
                  .submit(email: email),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => context.go(AppRoutes.login),
            child: Text(
              l10n.authBackToSignIn,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}
