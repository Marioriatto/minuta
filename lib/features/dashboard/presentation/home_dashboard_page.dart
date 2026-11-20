import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/ui/minuta_logo.dart';
import '../../../core/ui/surface_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../babies/babies_providers.dart';
import '../../babies/domain/baby.dart';
import '../../babies/presentation/widgets/baby_avatar.dart';
import '../../babies/presentation/widgets/baby_formatters.dart';
import '../../devices/devices_providers.dart';
import '../../devices/domain/device.dart';
import '../../devices/domain/lights_settings.dart';
import '../../devices/domain/thresholds.dart';
import '../../devices/presentation/widgets/device_presentation.dart';
import '../dashboard_providers.dart';
import '../domain/dashboard_models.dart';
import '../domain/home_modules.dart';
import 'widgets/activity_formatters.dart';
import 'widgets/trend_chart.dart';

/// Inicio: resumen del bebé activo, estado de los módulos, tendencias y
/// actividad reciente (RF-05, RF-10). Cada sección tiene su estado vacío:
/// una cuenta recién creada no ve datos inventados.
class HomeDashboardPage extends ConsumerWidget {
  const HomeDashboardPage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(dashboardHistoryProvider)
      ..invalidate(recentActivityProvider)
      ..invalidate(devicesProvider);
    await Future.wait([
      ref
          .read(dashboardHistoryProvider.future)
          .catchError((_) => const DashboardHistory()),
      ref
          .read(recentActivityProvider.future)
          .catchError((_) => const <ActivityEvent>[]),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final baby = ref.watch(activeBabyProvider);
    return Scaffold(
      appBar: AppBar(
        title: MinutaLogo(label: l10n.brandName, size: 30),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            DesignTokens.pagePadding,
            8,
            DesignTokens.pagePadding,
            32,
          ),
          children: [
            _BabyHeader(baby: baby),
            const SizedBox(height: 24),
            _SectionTitle(l10n.homeNowSection),
            const _ModulesSection(),
            const SizedBox(height: 24),
            _SectionTitle(l10n.homeTrendsSection),
            const _TrendsSection(),
            const SizedBox(height: 24),
            _SectionTitle(l10n.homeActivitySection),
            const _ActivitySection(),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
}

class _BabyHeader extends StatelessWidget {
  const _BabyHeader({required this.baby});
  final Baby? baby;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final b = baby;
    if (b == null) {
      return SurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Text(l10n.homeNoActiveBaby),
      );
    }
    final age = babyAgeText(l10n, b.ageOn(DateTime.now()));
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          BabyAvatar(name: b.name, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '$age · ${babyWeightText(context, b.weightKg)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

class _ModulesSection extends ConsumerWidget {
  const _ModulesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final modules = ref.watch(homeModulesProvider);
    final now = ref.watch(nowProvider).value ?? DateTime.now().toUtc();

    return modules.when(
      skipLoadingOnReload: true,
      loading: () => const _CardLoading(),
      error: (_, __) => _SectionError(
        onRetry: () => ref.invalidate(devicesProvider),
      ),
      data: (m) {
        final mattress = m.mattress;
        final cradle = m.cradle;
        final lights = m.lights;
        return Column(
          children: [
            _ModuleTile(
              kind: DeviceKind.mattress,
              device: mattress,
              notLinkedText: l10n.homeMattressNotLinked,
              now: now,
              status: mattress == null
                  ? null
                  : _mattressStatus(l10n, mattress, now),
              onTap: mattress == null
                  ? null
                  : () =>
                      context.push(AppRoutes.accessoriesMattress(mattress.id)),
            ),
            const SizedBox(height: 10),
            _ModuleTile(
              kind: DeviceKind.cradle,
              device: cradle,
              notLinkedText: l10n.homeCradleNotLinked,
              now: now,
              status: cradle == null ? null : _CradleStatus(device: cradle),
              onTap: cradle == null
                  ? null
                  : () => context.push(AppRoutes.accessoriesCradle(cradle.id)),
            ),
            const SizedBox(height: 10),
            _ModuleTile(
              kind: DeviceKind.lights,
              device: lights,
              notLinkedText: l10n.homeLightsNotLinked,
              now: now,
              status: lights == null
                  ? null
                  : Text(_lightsStatus(l10n, lights, now)),
              onTap: lights == null
                  ? null
                  : () => context.push(AppRoutes.accessoriesLights(lights.id)),
            ),
          ],
        );
      },
    );
  }

  Widget _mattressStatus(AppLocalizations l10n, Device mattress, DateTime now) {
    final text = switch (HomeModules.presenceOf(mattress, now)) {
      MattressPresence.occupied =>
        '${l10n.homeMattressOccupied} · ${formatDecimal(mattress.weightKg)} kg',
      MattressPresence.empty => l10n.homeMattressEmpty,
      MattressPresence.unknown => l10n.homeNoReadingYet,
    };
    return Text(text);
  }

  String _lightsStatus(AppLocalizations l10n, Device lights, DateTime now) {
    final settings = LightsSettings.fromConfig(lights.config);
    return settings.isOn(now)
        ? l10n.homeLightsOn(settings.brightness)
        : l10n.homeLightsOff;
  }
}

class _CradleStatus extends StatelessWidget {
  const _CradleStatus({required this.device});
  final Device device;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = device.temperatureC;
    final h = device.humidityPct;
    if (t == null && h == null) return Text(l10n.homeNoReadingYet);
    final thresholds = Thresholds.fromConfig(device.config);
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _LevelChip(
          text: '${formatDecimal(t)} °C',
          level: thresholds.temperatureLevel(t),
        ),
        _LevelChip(
          text: '${formatDecimal(h)} %',
          level: thresholds.humidityLevel(h),
        ),
      ],
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.text, required this.level});
  final String text;
  final MetricLevel level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = switch (level) {
      MetricLevel.ok => (DesignTokens.successContainer, DesignTokens.success),
      MetricLevel.high || MetricLevel.low => (
          DesignTokens.dangerContainer,
          DesignTokens.danger
        ),
      MetricLevel.unknown => (
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurfaceVariant,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.kind,
    required this.device,
    required this.notLinkedText,
    required this.now,
    this.status,
    this.onTap,
  });

  final DeviceKind kind;
  final Device? device;
  final String notLinkedText;
  final DateTime now;
  final Widget? status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final d = device;
    final muted = theme.colorScheme.onSurfaceVariant;

    return SurfaceCard(
      child: InkWell(
        onTap:
            d == null ? () => context.push(AppRoutes.accessoriesClaim) : onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  deviceKindIcon(kind),
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            d?.name ?? l10n.deviceKindLabel(kind),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (d != null) ...[
                          OnlineDot(online: d.isOnline(now)),
                          const SizedBox(width: 6),
                          Text(
                            d.isOnline(now)
                                ? l10n.deviceOnline
                                : l10n.deviceOffline,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: muted),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (d == null)
                      Text(
                        notLinkedText,
                        style:
                            theme.textTheme.bodySmall?.copyWith(color: muted),
                      )
                    else
                      DefaultTextStyle.merge(
                        style: theme.textTheme.bodyMedium,
                        child: status ?? const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
              if (d == null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => context.push(AppRoutes.accessoriesClaim),
                  child: Text(
                    l10n.homeLinkAction,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ] else if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendsSection extends ConsumerWidget {
  const _TrendsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final history = ref.watch(dashboardHistoryProvider);
    final day = DateFormat('d MMM', locale);
    final hour = DateFormat('HH:mm', locale);

    return history.when(
      skipLoadingOnReload: true,
      loading: () => const _CardLoading(height: 180),
      error: (_, __) => _SectionError(
        onRetry: () => ref.invalidate(dashboardHistoryProvider),
      ),
      data: (h) => Column(
        children: [
          TrendChart(
            title: l10n.homeWeightChartTitle,
            points: h.dailyWeight,
            emptyText: l10n.homeWeightChartEmpty,
            color: DesignTokens.primary,
            axisLabel: day.format,
            valueLabel: (v) => '${formatDecimal(v)} kg',
          ),
          const SizedBox(height: 10),
          TrendChart(
            title: l10n.homeTemperatureChartTitle,
            points: h.temperature,
            emptyText: l10n.homeEnvironmentChartEmpty,
            color: DesignTokens.danger,
            axisLabel: hour.format,
            valueLabel: (v) => '${formatDecimal(v)} °C',
          ),
          const SizedBox(height: 10),
          TrendChart(
            title: l10n.homeHumidityChartTitle,
            points: h.humidity,
            emptyText: l10n.homeEnvironmentChartEmpty,
            color: DesignTokens.accent,
            axisLabel: hour.format,
            valueLabel: (v) => '${formatDecimal(v)} %',
          ),
        ],
      ),
    );
  }
}

class _ActivitySection extends ConsumerWidget {
  const _ActivitySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final locale = Localizations.localeOf(context).toString();
    final when = DateFormat('d MMM · HH:mm', locale);
    final activity = ref.watch(recentActivityProvider);

    return activity.when(
      skipLoadingOnReload: true,
      loading: () => const _CardLoading(),
      error: (_, __) => _SectionError(
        onRetry: () => ref.invalidate(recentActivityProvider),
      ),
      data: (events) {
        if (events.isEmpty) {
          return SurfaceCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(Icons.history_rounded, size: 32, color: muted),
                const SizedBox(height: 8),
                Text(
                  l10n.homeActivityEmpty,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          );
        }
        return SurfaceCard(
          child: Column(
            children: [
              for (var i = 0; i < events.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    activityIcon(events[i].category),
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(activityLabel(l10n, events[i])),
                  subtitle: Text(when.format(events[i].occurredAt.toLocal())),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CardLoading extends StatelessWidget {
  const _CardLoading({this.height = 96});
  final double height;

  @override
  Widget build(BuildContext context) => SurfaceCard(
        child: SizedBox(
          height: height,
          child: const Center(child: CircularProgressIndicator.adaptive()),
        ),
      );
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(l10n.homeSectionError)),
          TextButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
        ],
      ),
    );
  }
}
