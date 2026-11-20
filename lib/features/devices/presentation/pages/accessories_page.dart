import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/ui/icon_badge.dart';
import '../../../../core/ui/primary_button.dart';
import '../../../../core/ui/state_view.dart';
import '../../../../core/ui/surface_card.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../devices_providers.dart';
import '../../domain/device.dart';
import '../../domain/lights_settings.dart';
import '../widgets/device_presentation.dart';

/// Pestaña Ampliaciones: módulos vinculados y acceso a sus funciones (RF-08).
class AccessoriesPage extends ConsumerWidget {
  const AccessoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final devices = ref.watch(devicesProvider);
    final now = ref.watch(nowProvider).value ?? DateTime.now().toUtc();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navAccessories)),
      body: StateView<List<Device>>(
        value: devices,
        onRetry: () => ref.invalidate(devicesProvider),
        builder: (context, list) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (list.isEmpty)
              _EmptyBlock(l10n: l10n)
            else
              SurfaceCard(
                child: Column(
                  children: [
                    for (var i = 0; i < list.length; i++) ...[
                      if (i > 0) const Divider(),
                      _DeviceTile(device: list[i], now: now),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: l10n.accessoriesAdd,
              tone: ButtonTone.tonal,
              icon: Icons.add_rounded,
              onPressed: () => context.push(AppRoutes.accessoriesClaim),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const IconBadge(icon: Icons.grid_view_rounded, size: 72),
          const SizedBox(height: 16),
          Text(
            l10n.accessoriesEmptyTitle,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.accessoriesEmptyBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.now});

  final Device device;
  final DateTime now;

  String _detail(AppLocalizations l10n) {
    switch (device.kind) {
      case DeviceKind.mattress:
        final kg = device.weightKg;
        return kg == null
            ? l10n.deviceMattressNoData
            : l10n.deviceMattressReading(formatDecimal(kg));
      case DeviceKind.cradle:
        final t = device.temperatureC;
        final h = device.humidityPct;
        return (t == null || h == null)
            ? l10n.deviceCradleNoData
            : l10n.deviceCradleReading(formatDecimal(t), formatDecimal(h));
      case DeviceKind.lights:
        final s = LightsSettings.fromConfig(device.config);
        return s.isOn(now)
            ? l10n.deviceLightsOn(s.brightness)
            : l10n.deviceLightsOff;
      default:
        return l10n.deviceSoon;
    }
  }

  String? _route() => switch (device.kind) {
        DeviceKind.mattress => AppRoutes.accessoriesMattress(device.id),
        DeviceKind.cradle => AppRoutes.accessoriesCradle(device.id),
        DeviceKind.lights => AppRoutes.accessoriesLights(device.id),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final online = device.isOnline(now);
    final route = _route();
    return ListTile(
      leading: IconBadge(icon: deviceKindIcon(device.kind), size: 44),
      title: Text(
        device.name ?? l10n.deviceKindLabel(device.kind),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Row(
        children: [
          OnlineDot(online: online),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${online ? l10n.deviceOnline : l10n.deviceOffline} · '
              '${_detail(l10n)}',
            ),
          ),
        ],
      ),
      trailing: route == null ? null : const Icon(Icons.chevron_right_rounded),
      onTap: route == null ? null : () => context.push(route),
    );
  }
}
