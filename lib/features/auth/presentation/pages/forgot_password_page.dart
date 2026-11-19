import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/ui/app_text_field.dart';
import '../../../../core/ui/failure_l10n.dart';
import '../../../../core/ui/message_banner.dart';
import '../../../../core/ui/primary_button.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../controllers/forgot_password_controller.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/field_error_l10n.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _email = TextEditingController();

  /// Los controladores no se autodestruyen: se limpian al abrir la pantalla
  /// para no mostrar errores de una visita anterior.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(forgotPasswordControllerProvider);
    });
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    ref.read(forgotPasswordControllerProvider.notifier).submit(
          email: _email.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final form = ref.watch(forgotPasswordControllerProvider);

    return AuthScaffold(
      showAppBar: true,
      title: l10n.authForgotTitle,
      subtitle: l10n.authForgotSubtitle,
      children: [
        if (form.completed) ...[
          // No se revela si el correo existe.
          MessageBanner(message: l10n.authForgotSent, kind: BannerKind.info),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => context.go(AppRoutes.login),
              child: Text(
                l10n.authBackToSignIn,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ] else ...[
          AppTextField(
            label: l10n.authEmailLabel,
            hint: l10n.authEmailHint,
            controller: _email,
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            errorText: fieldErrorText(l10n, form.emailError),
            onSubmitted: (_) => _submit(),
            enabled: !form.busy,
          ),
          if (form.failure != null) ...[
            const SizedBox(height: 16),
            MessageBanner(message: l10n.forFailure(form.failure!)),
          ],
          const SizedBox(height: 20),
          PrimaryButton(
            label: l10n.authSendLink,
            busy: form.busy,
            onPressed: _submit,
          ),
        ],
      ],
    );
  }
}
