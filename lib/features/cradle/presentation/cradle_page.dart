import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/ui/app_text_field.dart';
import '../../../core/ui/failure_l10n.dart';
import '../../../core/ui/message_banner.dart';
import '../../../core/ui/primary_button.dart';
import '../../../core/ui/surface_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../devices/devices_providers.dart';
import '../../devices/domain/device.dart';
import '../../devices/domain/thresholds.dart';
import '../../devices/presentation/controllers/device_actions_controller.dart';
import '../../devices/presentation/widgets/device_presentation.dart';

/// Cuna: temperatura y humedad ambiental en vivo y umbrales de alerta
/// (RF-16, RF-17, RF-18; APP-009).
class CradlePage extends ConsumerStatefulWidget {
  const CradlePage({required this.deviceId, super.key});

  final String deviceId;

  @override
  ConsumerState<CradlePage> createState() => _CradlePageState();
}

class _CradlePageState extends ConsumerState<CradlePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(deviceActionsControllerProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final device = ref.watch(deviceByIdProvider(widget.deviceId));
    final loading = ref.watch(devicesProvider).isLoading;
    final now = ref.watch(nowProvider).value ?? DateTime.now().toUtc();

    ref.listen(deviceActionsControllerProvider, (previous, next) {
      final messenger = ScaffoldMessenger.of(context);
      final failure = next.failure;
      if (failure != null) {
        messenger
            .showSnackBar(SnackBar(content: Text(l10n.forFailure(failure))));
      } else if (next.done == DeviceActionDone.thresholds) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.cradleSaved)));
      } else if (next.done == DeviceActionDone.buzz) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.cradleBuzzSent)));
      }
    });

    if (device == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.cradleTitle)),
        body: Center(
          child: loading
              ? const CircularProgressIndicator.adaptive()
              : Text(l10n.deviceNotFound),
        ),
      );
    }

    final thresholds = Thresholds.fromConfig(device.config);
    final online = device.isOnline(now);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cradleTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (!online) ...[
            MessageBanner(
              message: l10n.cradleOfflineNote,
              kind: BannerKind.info,
            ),
            const SizedBox(height: 16),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.thermostat_rounded,
                  label: l10n.cradleTemperature,
                  value: '${formatDecimal(device.temperatureC)} °C',
                  level: thresholds.temperatureLevel(device.temperatureC),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  icon: Icons.water_drop_outlined,
                  label: l10n.cradleHumidity,
                  value: '${formatDecimal(device.humidityPct)} %',
                  level: thresholds.humidityLevel(device.humidityPct),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Pitido del buzzer de la cuna (sustituye al speaker de RF-19 en el
          // prototipo). Solo con la cuna en línea: el comando caduca en 2 min.
          PrimaryButton(
            label: l10n.cradleBuzz,
            icon: Icons.notifications_active_outlined,
            tone: ButtonTone.tonal,
            busy: ref.watch(deviceActionsControllerProvider).busy,
            onPressed: online
                ? () => ref
                    .read(deviceActionsControllerProvider.notifier)
                    .buzz(device)
                : null,
          ),
          const SizedBox(height: 24),
          _ThresholdsForm(device: device, initial: thresholds),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.level,
  });

  final IconData icon;
  final String label;
  final String value;
  final MetricLevel level;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (bg, fg, text) = switch (level) {
      MetricLevel.ok => (
          DesignTokens.successContainer,
          DesignTokens.success,
          l10n.levelOk,
        ),
      MetricLevel.high => (
          DesignTokens.dangerContainer,
          DesignTokens.danger,
          l10n.levelHigh,
        ),
      MetricLevel.low => (
          DesignTokens.dangerContainer,
          DesignTokens.danger,
          l10n.levelLow,
        ),
      MetricLevel.unknown => (
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurfaceVariant,
          l10n.levelUnknown,
        ),
    };
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThresholdsForm extends ConsumerStatefulWidget {
  const _ThresholdsForm({required this.device, required this.initial});

  final Device device;
  final Thresholds initial;

  @override
  ConsumerState<_ThresholdsForm> createState() => _ThresholdsFormState();
}

class _ThresholdsFormState extends ConsumerState<_ThresholdsForm> {
  late final _tempMin =
      TextEditingController(text: thresholdText(widget.initial.tempMin));
  late final _tempMax =
      TextEditingController(text: thresholdText(widget.initial.tempMax));
  late final _humMin =
      TextEditingController(text: thresholdText(widget.initial.humMin));
  late final _humMax =
      TextEditingController(text: thresholdText(widget.initial.humMax));
  Map<ThresholdField, ThresholdError> _errors = const {};

  @override
  void dispose() {
    _tempMin.dispose();
    _tempMax.dispose();
    _humMin.dispose();
    _humMax.dispose();
    super.dispose();
  }

  void _save() {
    final result = ThresholdsValidator.validate(
      tempMin: _tempMin.text,
      tempMax: _tempMax.text,
      humMin: _humMin.text,
      humMax: _humMax.text,
    );
    setState(() => _errors = result.errors);
    if (!result.isValid) return;
    ref.read(deviceActionsControllerProvider.notifier).setThresholds(
          deviceId: widget.device.id,
          thresholds: result.value!,
        );
  }

  String? _errorFor(
    AppLocalizations l10n,
    ThresholdField field, {
    required bool isTemperature,
  }) =>
      switch (_errors[field]) {
        ThresholdError.notANumber => l10n.thresholdErrorNotNumber,
        ThresholdError.outOfRange => isTemperature
            ? l10n.thresholdErrorRangeTemp
            : l10n.thresholdErrorRangeHum,
        ThresholdError.minNotBelowMax => l10n.thresholdErrorOrder,
        null => null,
      };

  Widget _field(
    AppLocalizations l10n,
    String label,
    TextEditingController controller,
    ThresholdField field, {
    required bool isTemperature,
    required bool enabled,
  }) =>
      AppTextField(
        label: label,
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\-]')),
        ],
        errorText: _errorFor(l10n, field, isTemperature: isTemperature),
        enabled: enabled,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final busy = ref.watch(deviceActionsControllerProvider).busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.cradleThresholdsTitle,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.cradleThresholdsHelp,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        _field(
          l10n,
          l10n.cradleTempMin,
          _tempMin,
          ThresholdField.tempMin,
          isTemperature: true,
          enabled: !busy,
        ),
        const SizedBox(height: 12),
        _field(
          l10n,
          l10n.cradleTempMax,
          _tempMax,
          ThresholdField.tempMax,
          isTemperature: true,
          enabled: !busy,
        ),
        const SizedBox(height: 12),
        _field(
          l10n,
          l10n.cradleHumMin,
          _humMin,
          ThresholdField.humMin,
          isTemperature: false,
          enabled: !busy,
        ),
        const SizedBox(height: 12),
        _field(
          l10n,
          l10n.cradleHumMax,
          _humMax,
          ThresholdField.humMax,
          isTemperature: false,
          enabled: !busy,
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: l10n.cradleSave,
          busy: busy,
          onPressed: _save,
        ),
      ],
    );
  }
}
