import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/failure_l10n.dart';
import '../../../core/ui/message_banner.dart';
import '../../../core/ui/surface_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../devices/devices_providers.dart';
import '../../devices/domain/device.dart';
import '../../devices/domain/lights_settings.dart';
import '../../devices/presentation/controllers/device_actions_controller.dart';

/// Luces de la cuna: encendido, intensidad, velocidad del patrón y
/// temporizador (RF-20, RF-21, RF-22; CUNA-001, CUNA-003).
class LightsPage extends ConsumerStatefulWidget {
  const LightsPage({required this.deviceId, super.key});

  final String deviceId;

  @override
  ConsumerState<LightsPage> createState() => _LightsPageState();
}

class _LightsPageState extends ConsumerState<LightsPage> {
  double? _brightnessDrag;
  double? _speedDrag;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(deviceActionsControllerProvider);
    });
  }

  void _send(
    Device device,
    LightsSettings settings,
    DateTime now, {
    bool? on,
    int? brightness,
    int? speed,
    int? minutes,
    bool keepTimer = false,
  }) {
    ref.read(deviceActionsControllerProvider.notifier).setLights(
          LightsChange(
            deviceId: device.id,
            on: on ?? settings.isOn(now),
            brightness: brightness ?? settings.brightness,
            speed: speed ?? settings.speed,
            minutes: minutes,
            keepTimer: keepTimer,
          ),
        );
  }

  Future<void> _askCustomMinutes(
    Device device,
    LightsSettings settings,
    DateTime now,
  ) async {
    final minutes = await showDialog<int>(
      context: context,
      builder: (_) => const _CustomTimerDialog(),
    );
    if (minutes != null && mounted) {
      _send(device, settings, now, on: true, minutes: minutes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final device = ref.watch(deviceByIdProvider(widget.deviceId));
    final loading = ref.watch(devicesProvider).isLoading;
    final now = ref.watch(nowProvider).value ?? DateTime.now().toUtc();
    final actions = ref.watch(deviceActionsControllerProvider);

    ref.listen<Device?>(deviceByIdProvider(widget.deviceId), (_, __) {
      if (!_dragging && (_brightnessDrag != null || _speedDrag != null)) {
        setState(() {
          _brightnessDrag = null;
          _speedDrag = null;
        });
      }
    });
    ref.listen(deviceActionsControllerProvider, (previous, next) {
      final failure = next.failure;
      if (failure != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.forFailure(failure))));
      }
    });

    if (device == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.lightsTitle)),
        body: Center(
          child: loading
              ? const CircularProgressIndicator.adaptive()
              : Text(l10n.deviceNotFound),
        ),
      );
    }

    final settings = LightsSettings.fromConfig(device.config);
    final isOn = settings.isOn(now);
    final online = device.isOnline(now);
    final remaining = settings.remaining(now);
    final brightness = _brightnessDrag ?? settings.brightness.toDouble();
    final speed = _speedDrag ?? settings.speed.toDouble();
    final timerMinutes =
        isOn && settings.endsAt != null ? settings.timerMinutes : null;
    final customSelected = timerMinutes != null &&
        !LightsRules.timerPresets.contains(timerMinutes);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.lightsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (!online) ...[
            MessageBanner(
              message: l10n.lightsOfflineNote,
              kind: BannerKind.info,
            ),
            const SizedBox(height: 16),
          ],
          SurfaceCard(
            child: SwitchListTile(
              value: isOn,
              onChanged: (v) => _send(device, settings, now, on: v),
              title: Text(
                l10n.lightsPower,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                isOn ? l10n.lightsStatusOn : l10n.lightsStatusOff,
              ),
              secondary: actions.busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Icon(Icons.lightbulb_outline_rounded),
            ),
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SliderRow(
                  label: l10n.lightsBrightness,
                  valueText: l10n.lightsPercent(brightness.round()),
                  value: brightness,
                  onChangeStart: () => _dragging = true,
                  onChanged: (v) => setState(() => _brightnessDrag = v),
                  onChangeEnd: (v) {
                    _dragging = false;
                    _send(
                      device,
                      settings,
                      now,
                      brightness: v.round(),
                      keepTimer: true,
                    );
                  },
                ),
                const SizedBox(height: 8),
                _SliderRow(
                  label: l10n.lightsSpeed,
                  valueText: l10n.lightsPercent(speed.round()),
                  value: speed,
                  onChangeStart: () => _dragging = true,
                  onChanged: (v) => setState(() => _speedDrag = v),
                  onChangeEnd: (v) {
                    _dragging = false;
                    _send(
                      device,
                      settings,
                      now,
                      speed: v.round(),
                      keepTimer: true,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.lightsTimer,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(l10n.lightsTimerNone),
                      selected: isOn && timerMinutes == null,
                      onSelected: isOn
                          ? (_) => _send(device, settings, now, on: true)
                          : null,
                    ),
                    for (final m in LightsRules.timerPresets)
                      ChoiceChip(
                        label: Text(l10n.lightsTimerMinutes(m)),
                        selected: timerMinutes == m,
                        onSelected: isOn
                            ? (_) => _send(
                                  device,
                                  settings,
                                  now,
                                  on: true,
                                  minutes: m,
                                )
                            : null,
                      ),
                    ChoiceChip(
                      label: Text(
                        customSelected
                            ? l10n.lightsTimerMinutes(timerMinutes)
                            : l10n.lightsTimerCustom,
                      ),
                      selected: customSelected,
                      onSelected: isOn
                          ? (_) => _askCustomMinutes(device, settings, now)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  remaining != null
                      ? l10n.lightsTimerRemaining(
                          (remaining.inSeconds / 60).ceil(),
                        )
                      : l10n.lightsTimerNeedsOn,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.valueText,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onChangeStart,
  });

  final String label;
  final String valueText;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final VoidCallback onChangeStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(valueText),
          ],
        ),
        Slider(
          value: value.clamp(0.0, 100.0).toDouble(),
          max: 100,
          divisions: 20,
          label: valueText,
          onChangeStart: (_) => onChangeStart(),
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }
}

class _CustomTimerDialog extends StatefulWidget {
  const _CustomTimerDialog();

  @override
  State<_CustomTimerDialog> createState() => _CustomTimerDialogState();
}

class _CustomTimerDialogState extends State<_CustomTimerDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm(AppLocalizations l10n) {
    final minutes = int.tryParse(_controller.text.trim());
    if (minutes == null || !LightsRules.isValidTimer(minutes)) {
      setState(() => _error = l10n.lightsTimerDialogInvalid);
      return;
    }
    Navigator.of(context).pop(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.lightsTimerDialogTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: l10n.lightsTimerDialogLabel,
          errorText: _error,
        ),
        onSubmitted: (_) => _confirm(l10n),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => _confirm(l10n),
          child: Text(l10n.lightsTimerDialogConfirm),
        ),
      ],
    );
  }
}
