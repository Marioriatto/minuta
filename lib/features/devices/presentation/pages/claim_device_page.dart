import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/app_text_field.dart';
import '../../../../core/ui/failure_l10n.dart';
import '../../../../core/ui/message_banner.dart';
import '../../../../core/ui/primary_button.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/device_code.dart';
import '../controllers/claim_device_controller.dart';

/// Vincular una ampliación con su código (RF-06, RF-07, APP-003, APP-014).
class ClaimDevicePage extends ConsumerStatefulWidget {
  const ClaimDevicePage({super.key});

  @override
  ConsumerState<ClaimDevicePage> createState() => _ClaimDevicePageState();
}

class _ClaimDevicePageState extends ConsumerState<ClaimDevicePage> {
  final _code = TextEditingController();
  final _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(claimDeviceControllerProvider);
    });
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    ref.read(claimDeviceControllerProvider.notifier).submit(
          code: _code.text,
          name: _name.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(claimDeviceControllerProvider);

    ref.listen(claimDeviceControllerProvider, (previous, next) {
      if (next.claimed != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.claimSuccess)));
        context.pop();
      }
    });

    final codeError = switch (state.codeError) {
      DeviceCodeError.empty => l10n.claimCodeEmpty,
      DeviceCodeError.invalid => l10n.claimCodeInvalid,
      null => null,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.claimTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l10n.claimIntro),
          const SizedBox(height: 24),
          AppTextField(
            label: l10n.claimCodeLabel,
            hint: l10n.claimCodeHint,
            controller: _code,
            prefixIcon: Icons.qr_code_2_rounded,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9 -]')),
              LengthLimitingTextInputFormatter(24),
            ],
            errorText: codeError,
            enabled: !state.busy,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: l10n.claimNameLabel,
            hint: l10n.claimNameHint,
            controller: _name,
            prefixIcon: Icons.edit_outlined,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            enabled: !state.busy,
          ),
          if (state.failure != null) ...[
            const SizedBox(height: 16),
            MessageBanner(message: l10n.forFailure(state.failure!)),
          ],
          const SizedBox(height: 24),
          PrimaryButton(
            label: l10n.claimSubmit,
            busy: state.busy,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
