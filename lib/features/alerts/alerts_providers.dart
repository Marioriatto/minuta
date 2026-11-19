import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../auth/auth_providers.dart';
import 'data/alerts_remote_source.dart';
import 'data/alerts_repository_impl.dart';
import 'domain/alert.dart';
import 'domain/alerts_repository.dart';
import 'domain/alerts_use_cases.dart';

/// Punto de composición de la feature (única conexión datos ↔ dominio).

final alertsRemoteProvider = Provider<AlertsRemoteSource>(
  (ref) => SupabaseAlertsRemoteSource(ref.watch(supabaseClientProvider)),
);

final alertsRepositoryProvider = Provider<AlertsRepository>(
  (ref) => AlertsRepositoryImpl(ref.watch(alertsRemoteProvider)),
);

final listAlertsProvider = Provider<ListAlerts>(
  (ref) => ListAlerts(ref.watch(alertsRepositoryProvider)),
);
final markAlertsReadProvider = Provider<MarkAlertsRead>(
  (ref) => MarkAlertsRead(ref.watch(alertsRepositoryProvider)),
);
final markAllAlertsReadProvider = Provider<MarkAllAlertsRead>(
  (ref) => MarkAllAlertsRead(ref.watch(alertsRepositoryProvider)),
);

/// Alertas del usuario: carga inicial + cambios en vivo. Si la conexión en
/// vivo falla se conservan los últimos datos conocidos.
class AlertsNotifier extends AsyncNotifier<List<Alert>> {
  @override
  Future<List<Alert>> build() async {
    final userId =
        ref.watch(authSnapshotProvider.select((s) => s.value?.user?.id));
    if (userId == null) return const [];

    final first = await ref.watch(listAlertsProvider)();
    final alerts = first.when(ok: (a) => a, err: (f) => throw f);

    final sub = ref.watch(alertsRepositoryProvider).watch().listen(
          (latest) => state = AsyncData(latest),
          onError: (Object _) {},
        );
    ref.onDispose(sub.cancel);
    return alerts;
  }

  /// Refleja de inmediato una marca de leída confirmada por el servidor.
  void applyRead(Set<String>? ids, DateTime at) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final a in current)
        if (ids == null || ids.contains(a.id)) a.markedRead(at) else a,
    ]);
  }
}

final alertsProvider =
    AsyncNotifierProvider<AlertsNotifier, List<Alert>>(AlertsNotifier.new);

/// Contador para la insignia de la pestaña Alertas.
final unreadAlertsCountProvider = Provider<int>(
  (ref) => AlertsRules.unreadCount(ref.watch(alertsProvider).value ?? const []),
);
