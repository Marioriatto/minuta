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
import '../controllers/sign_in_controller.dart';
import '../controllers/social_sign_in_controller.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/field_error_l10n.dart';
import '../widgets/social_sign_in_buttons.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  /// Los controladores no se autodestruyen: se limpian al abrir la pantalla
  /// para no mostrar errores de una visita anterior.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(signInControllerProvider);
      ref.invalidate(socialSignInControllerProvider);
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    ref.read(signInControllerProvider.notifier).submit(
          email: _email.text,
          password: _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final form = ref.watch(signInControllerProvider);
    final social = ref.watch(socialSignInControllerProvider);
    final busy = form.busy || social.busy;
    final failure = form.failure ?? social.failure;

    return AuthScaffold(
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
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                errorText: fieldErrorText(l10n, form.passwordError),
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
          label: l10n.authSignIn,
          busy: form.busy,
          onPressed: busy ? null : _submit,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed:
                busy ? null : () => context.push(AppRoutes.forgotPassword),
            child: Text(
              l10n.authForgotPassword,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        SocialSignInButtons(disabled: form.busy),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              l10n.authNoAccount,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            TextButton(
              onPressed: busy ? null : () => context.push(AppRoutes.signUp),
              child: Text(
                l10n.authSignUpLink,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
