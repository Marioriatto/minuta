import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/ui/app_text_field.dart';
import '../../../../core/ui/failure_l10n.dart';
import '../../../../core/ui/message_banner.dart';
import '../../../../core/ui/minuta_logo.dart';
import '../../../../core/ui/primary_button.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../controllers/sign_up_controller.dart';
import '../controllers/social_sign_in_controller.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/field_error_l10n.dart';
import '../widgets/social_sign_in_buttons.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  /// Los controladores no se autodestruyen: se limpian al abrir la pantalla
  /// para no mostrar errores de una visita anterior.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(signUpControllerProvider);
      ref.invalidate(socialSignInControllerProvider);
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    ref.read(signUpControllerProvider.notifier).submit(
          email: _email.text,
          password: _password.text,
          confirmation: _confirm.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final form = ref.watch(signUpControllerProvider);
    final social = ref.watch(socialSignInControllerProvider);
    final busy = form.busy || social.busy;
    final failure = form.failure ?? social.failure;

    ref.listen(signUpControllerProvider, (previous, next) {
      if (next.completed && !(previous?.completed ?? false)) {
        final email = Uri.encodeQueryComponent(_email.text.trim());
        context.go('${AppRoutes.verifyEmail}?email=$email');
      }
    });

    return AuthScaffold(
      showAppBar: true,
      header: MinutaLogo(label: l10n.brandName, size: 52),
      children: [
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: l10n.authEmailLabel,
                hint: l10n.authEmailHint,
                controller: _email,
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                errorText: fieldErrorText(l10n, form.emailError),
                enabled: !busy,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: l10n.authPasswordLabel,
                hint: '••••••••',
                controller: _password,
                prefixIcon: Icons.lock_outline_rounded,
                obscure: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                errorText: fieldErrorText(l10n, form.passwordError),
                enabled: !busy,
                showPasswordTooltip: l10n.authShowPassword,
                hidePasswordTooltip: l10n.authHidePassword,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: l10n.authConfirmPasswordLabel,
                hint: '••••••••',
                controller: _confirm,
                prefixIcon: Icons.lock_outline_rounded,
                obscure: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                errorText: fieldErrorText(l10n, form.confirmError),
                onSubmitted: (_) => _submit(),
                enabled: !busy,
                showPasswordTooltip: l10n.authShowPassword,
                hidePasswordTooltip: l10n.authHidePassword,
              ),
            ],
          ),
        ),
        if (failure != null) ...[
          const SizedBox(height: 16),
          MessageBanner(message: l10n.forFailure(failure)),
        ],
        const SizedBox(height: 20),
        PrimaryButton(
          label: l10n.authCreateAccount,
          busy: form.busy,
          onPressed: busy ? null : _submit,
        ),
        SocialSignInButtons(disabled: form.busy),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              l10n.authHaveAccount,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            TextButton(
              onPressed: busy ? null : () => context.go(AppRoutes.login),
              child: Text(
                l10n.authSignInLink,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
