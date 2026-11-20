import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/ui/failure_l10n.dart';
import '../../../core/ui/message_banner.dart';
import '../../../core/ui/primary_button.dart';
import '../../../core/ui/surface_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../babies/babies_providers.dart';
import '../../detection/detection_providers.dart';
import '../../detection/domain/detection_period.dart';
import '../../detection/presentation/detection_controller.dart';
import '../../devices/devices_providers.dart';
import '../../devices/domain/device.dart';
import '../../devices/presentation/widgets/device_presentation.dart';

/// Colchón: peso actual y periodo de detección del bebé (RF-11, RF-12; APP-010).
class MattressPage extends ConsumerStatefulWidget {
  const MattressPage({required this.deviceId, super.key});

  final String deviceId;

  @override
  ConsumerState<MattressPage> createState() => _MattressPageState();
}

class _MattressPageState extends ConsumerState<MattressPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(detectionControllerProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final device = ref.watch(deviceByIdProvider(widget.deviceId));
    final loading = ref.watch(devicesProvider).isLoading;
    final now = ref.watch(nowProvider).value ?? DateTime.now().toUtc();

    ref.listen(detectionControllerProvider, (previous, next) {
      final messenger = ScaffoldMessenger.of(context);
      final failure = next.failure;
      final text = failure != null
          ? l10n.forFailure(failure)
          : switch (next.done) {
              DetectionActionDone.started => l10n.detectionStartedMessage,
              DetectionActionDone.stopped => l10n.detectionStoppedMessage,
              null => null,
            };
      if (text != null) {
        messenger.showSnackBar(SnackBar(content: Text(text)));
      }
    });

    if (device == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.mattressTitle)),
        body: Center(
          child: loading
              ? const CircularProgressIndicator.adaptive()
              : Text(l10n.deviceNotFound),
        ),
      );
    }

    final online = device.isOnline(now);
    final weight = device.weightKg;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mattressTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (!online) ...[
            MessageBanner(
              message: l10n.mattressOfflineNote,
              kind: BannerKind.info,
            ),
            const SizedBox(height: 16),
          ],
          _WeightTile(
            text: online && weight != null
                ? '${formatDecimal(weight)} kg'
                : l10n.levelUnknown,
          ),
          const SizedBox(height: 16),
          _DetectionCard(mattress: device, now: now),
        ],
      ),
    );
  }
}

class _WeightTile extends StatelessWidget {
  const _WeightTile({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.monitor_weight_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(l10n.mattressWeight, style: theme.textTheme.bodyMedium),
          ),
          Text(
            text,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta del periodo de detección. Sin lógica de negocio: el estado viene de
/// `activeDetectionProvider` y las acciones del controlador.
class _DetectionCard extends ConsumerStatefulWidget {
  const _DetectionCard({required this.mattress, required this.now});

  final Device mattress;
  final DateTime now;

  @override
  ConsumerState<_DetectionCard> createState() => _DetectionCardState();
}

class _DetectionCardState extends ConsumerState<_DetectionCard> {
  DetectionDuration _duration = DetectionDuration.unlimited;

  String _durationLabel(AppLocalizations l10n, DetectionDuration d) =>
      switch (d) {
        DetectionDuration.unlimited => l10n.detectionDurationUnlimited,
        DetectionDuration.oneHour => l10n.detectionDurationHours(1),
        DetectionDuration.twoHours => l10n.detectionDurationHours(2),
        DetectionDuration.eightHours => l10n.detectionDurationHours(8),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final active = ref.watch(activeDetectionProvider);
    final periods = ref.watch(detectionPeriodsProvider);
    final baby = ref.watch(activeBabyProvider);
    final busy = ref.watch(detectionControllerProvider).busy;
    final controller = ref.read(detectionControllerProvider.notifier);
    final hour =
        DateFormat('HH:mm', Localizations.localeOf(context).toString());

    final Widget body;
    if (periods.isLoading && !periods.hasValue) {
      body = const Center(child: CircularProgressIndicator.adaptive());
    } else if (periods.hasError && !periods.hasValue) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MessageBanner(message: l10n.detectionLoadError),
          const SizedBox(height: 12),
          PrimaryButton(
            label: l10n.commonRetry,
            tone: ButtonTone.tonal,
            onPressed: () => ref.invalidate(detectionPeriodsProvider),
          ),
        ],
      );
    } else if (active != null) {
      final since = hour.format(active.startsAt.toLocal());
      final end = active.endsAt;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusPill(active: true, label: l10n.detectionActive),
          const SizedBox(height: 12),
          Text(
            end == null
                ? l10n.detectionActiveSinceUnlimited(since)
                : l10n.detectionActiveSinceUntil(
                    since,
                    hour.format(end.toLocal()),
                  ),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: l10n.detectionStop,
            icon: Icons.stop_circle_outlined,
            tone: ButtonTone.destructive,
            busy: busy,
            onPressed: controller.stop,
          ),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusPill(active: false, label: l10n.detectionInactive),
          const SizedBox(height: 12),
          Text(
            baby == null
                ? l10n.detectionNeedsBaby
                : l10n.detectionHelp(baby.name),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in DetectionDuration.values)
                ChoiceChip(
                  label: Text(_durationLabel(l10n, d)),
                  selected: _duration == d,
                  onSelected:
                      busy ? null : (_) => setState(() => _duration = d),
                ),
            ],
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: l10n.detectionStart,
            icon: Icons.play_circle_outline_rounded,
            busy: busy,
            onPressed: baby == null
                ? null
                : () => controller.start(widget.mattress, _duration),
          ),
        ],
      );
    }

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.detectionTitle,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active, required this.label});

  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = active
        ? DesignTokens.successContainer
        : theme.colorScheme.surfaceContainerHighest;
    final fg =
        active ? DesignTokens.success : theme.colorScheme.onSurfaceVariant;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style:
              TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
    );
  }
}
