import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/app_text_field.dart';
import '../../../../core/ui/failure_l10n.dart';
import '../../../../core/ui/message_banner.dart';
import '../../../../core/ui/primary_button.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../controllers/reset_password_controller.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/field_error_l10n.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  /// Los controladores no se autodestruyen: se limpian al abrir la pantalla
  /// para no mostrar errores de una visita anterior.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(resetPasswordControllerProvider);
    });
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    ref.read(resetPasswordControllerProvider.notifier).submit(
          password: _password.text,
          confirmation: _confirm.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final form = ref.watch(resetPasswordControllerProvider);

    return AuthScaffold(
      title: l10n.authResetTitle,
      subtitle: l10n.authResetSubtitle,
      children: [
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: l10n.authNewPasswordLabel,
                hint: '••••••••',
                controller: _password,
                prefixIcon: Icons.lock_outline_rounded,
                obscure: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                errorText: fieldErrorText(l10n, form.passwordError),
                enabled: !form.busy,
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
                enabled: !form.busy,
                showPasswordTooltip: l10n.authShowPassword,
                hidePasswordTooltip: l10n.authHidePassword,
              ),
            ],
          ),
        ),
        if (form.failure != null) ...[
          const SizedBox(height: 16),
          MessageBanner(message: l10n.forFailure(form.failure!)),
        ],
        const SizedBox(height: 20),
        PrimaryButton(
          label: l10n.authSavePassword,
          busy: form.busy,
          onPressed: _submit,
        ),
      ],
    );
  }
}
