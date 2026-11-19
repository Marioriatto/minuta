import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/ui/failure_l10n.dart';
import '../../../core/ui/state_view.dart';
import '../../../core/ui/surface_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../dashboard/domain/dashboard_models.dart';
import '../../dashboard/presentation/widgets/activity_formatters.dart';
import '../../devices/presentation/widgets/device_presentation.dart';
import '../alerts_providers.dart';
import '../domain/alert.dart';
import 'alerts_actions_controller.dart';

/// Pestaña Alertas (RF-03, APP-001): lista en vivo, de la más reciente a la
/// más vieja; tocar una la marca como leída.
class AlertsPage extends ConsumerWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final alerts = ref.watch(alertsProvider);
    final unread = ref.watch(unreadAlertsCountProvider);
    final actions = ref.watch(alertsActionsControllerProvider);

    ref.listen(alertsActionsControllerProvider, (_, next) {
      final failure = next.failure;
      if (failure != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.forFailure(failure))));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navAlerts),
        actions: [
          if (unread > 0)
            IconButton(
              tooltip: l10n.alertsMarkAll,
              onPressed: actions.busy
                  ? null
                  : () => ref
                      .read(alertsActionsControllerProvider.notifier)
                      .markAllRead(),
              icon: const Icon(Icons.done_all_rounded),
            ),
        ],
      ),
      body: StateView<List<Alert>>(
        value: alerts,
        onRetry: () => ref.invalidate(alertsProvider),
        builder: (context, list) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(alertsProvider);
            await ref.read(alertsProvider.future).catchError((_) => <Alert>[]);
          },
          child: list.isEmpty
              ? const _EmptyAlerts()
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(DesignTokens.pagePadding),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _AlertCard(alert: list[i]),
                ),
        ),
      ),
    );
  }
}

class _EmptyAlerts extends StatelessWidget {
  const _EmptyAlerts();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    // ListView para que "deslizar para actualizar" funcione también vacío.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 48),
        Icon(Icons.notifications_none_rounded, size: 56, color: muted),
        const SizedBox(height: 16),
        Text(
          l10n.alertsEmptyTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.alertsEmptyBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
      ],
    );
  }
}

class _AlertCard extends ConsumerWidget {
  const _AlertCard({required this.alert});
  final Alert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final (fg, bg, icon, severityText) = switch (alert.severity) {
      AlertSeverity.critical => (
          DesignTokens.danger,
          DesignTokens.dangerContainer,
          Icons.error_outline_rounded,
          l10n.alertSeverityCritical,
        ),
      AlertSeverity.warning => (
          DesignTokens.warning,
          DesignTokens.warningContainer,
          Icons.warning_amber_rounded,
          l10n.alertSeverityWarning,
        ),
      AlertSeverity.info => (
          theme.colorScheme.primary,
          theme.colorScheme.primaryContainer,
          Icons.info_outline_rounded,
          l10n.alertSeverityInfo,
        ),
    };
    final title = activityLabel(
      l10n,
      ActivityEvent(
        id: alert.id,
        type: alert.type,
        occurredAt: alert.occurredAt,
      ),
    );
    final detail = _detail(l10n, alert);
    final when =
        DateFormat('d MMM · HH:mm', locale).format(alert.occurredAt.toLocal());

    return Semantics(
      label: alert.isRead ? null : l10n.alertUnread,
      child: SurfaceCard(
        child: InkWell(
          onTap: () => ref
              .read(alertsActionsControllerProvider.notifier)
              .markRead(alert),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: fg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight:
                              alert.isRead ? FontWeight.w600 : FontWeight.w800,
                        ),
                      ),
                      if (detail != null) ...[
                        const SizedBox(height: 2),
                        Text(detail, style: theme.textTheme.bodyMedium),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '$severityText · $when',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!alert.isRead)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 6, left: 8),
                    decoration:
                        BoxDecoration(color: fg, shape: BoxShape.circle),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Valor medido y límite en las alertas de ambiente.
  static String? _detail(AppLocalizations l10n, Alert a) {
    final value = a.value;
    if (value == null) return null;
    return switch (a.type) {
      'temperature_high' =>
        l10n.alertDetailTemperature(formatDecimal(value), formatDecimal(a.max)),
      'temperature_low' =>
        l10n.alertDetailTemperature(formatDecimal(value), formatDecimal(a.min)),
      'humidity_high' =>
        l10n.alertDetailHumidity(formatDecimal(value), formatDecimal(a.max)),
      'humidity_low' =>
        l10n.alertDetailHumidity(formatDecimal(value), formatDecimal(a.min)),
      _ => null,
    };
  }
}
