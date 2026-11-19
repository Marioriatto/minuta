import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../alerts_providers.dart';
import '../domain/alert.dart';

@immutable
class AlertsActionsState {
  const AlertsActionsState({this.busy = false, this.failure});
  final bool busy;
  final AppFailure? failure;
}

/// Marcar alertas como leídas (una o todas).
class AlertsActionsController extends Notifier<AlertsActionsState> {
  bool _disposed = false;

  @override
  AlertsActionsState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const AlertsActionsState();
  }

  Future<void> markRead(Alert alert) async {
    if (alert.isRead) return;
    final result = await ref.read(markAlertsReadProvider)([alert]);
    if (_disposed) return;
    result.when(
      ok: (_) {
        ref
            .read(alertsProvider.notifier)
            .applyRead({alert.id}, DateTime.now().toUtc());
        state = const AlertsActionsState();
      },
      err: (failure) => state = AlertsActionsState(failure: failure),
    );
  }

  Future<void> markAllRead() async {
    final current = ref.read(alertsProvider).value ?? const <Alert>[];
    state = const AlertsActionsState(busy: true);
    final result = await ref.read(markAllAlertsReadProvider)(current);
    if (_disposed) return;
    result.when(
      ok: (_) {
        ref.read(alertsProvider.notifier).applyRead(null, DateTime.now().toUtc());
        state = const AlertsActionsState();
      },
      err: (failure) => state = AlertsActionsState(failure: failure),
    );
  }
}

final alertsActionsControllerProvider =
    NotifierProvider<AlertsActionsController, AlertsActionsState>(
  AlertsActionsController.new,
);
