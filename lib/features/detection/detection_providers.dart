import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../auth/auth_providers.dart';
import '../devices/devices_providers.dart';
import 'data/detection_remote_source.dart';
import 'data/detection_repository_impl.dart';
import 'domain/detection_period.dart';
import 'domain/detection_repository.dart';
import 'domain/detection_use_cases.dart';

/// Punto de composición de la feature (única conexión datos ↔ dominio).

final detectionRemoteProvider = Provider<DetectionRemoteSource>(
  (ref) => SupabaseDetectionRemoteSource(ref.watch(supabaseClientProvider)),
);

final detectionRepositoryProvider = Provider<DetectionRepository>(
  (ref) => DetectionRepositoryImpl(ref.watch(detectionRemoteProvider)),
);

final startDetectionProvider = Provider<StartDetection>(
  (ref) => StartDetection(ref.watch(detectionRepositoryProvider)),
);
final stopDetectionProvider = Provider<StopDetection>(
  (ref) => StopDetection(ref.watch(detectionRepositoryProvider)),
);

/// Periodos recientes: carga inicial + cambios en vivo. Si la conexión en vivo
/// falla se conservan los últimos datos conocidos.
class DetectionPeriodsNotifier extends AsyncNotifier<List<DetectionPeriod>> {
  @override
  Future<List<DetectionPeriod>> build() async {
    final userId =
        ref.watch(authSnapshotProvider.select((s) => s.value?.user?.id));
    if (userId == null) return const [];

    final repo = ref.watch(detectionRepositoryProvider);
    final first = await repo.list();
    final periods = first.when(ok: (p) => p, err: (f) => throw f);

    final sub = repo.watch().listen(
          (latest) => state = AsyncData(latest),
          onError: (Object _) {},
        );
    ref.onDispose(sub.cancel);
    return periods;
  }

  /// Aplica de inmediato el periodo devuelto por una operación confirmada.
  void upsert(DetectionPeriod period) {
    final current = [...?state.value];
    final index = current.indexWhere((p) => p.id == period.id);
    if (index >= 0) {
      current[index] = period;
    } else {
      current.add(period);
    }
    state = AsyncData(current);
  }
}

final detectionPeriodsProvider =
    AsyncNotifierProvider<DetectionPeriodsNotifier, List<DetectionPeriod>>(
  DetectionPeriodsNotifier.new,
);

/// Periodo vigente ahora (se recalcula con el reloj de 10 s de `nowProvider`,
/// así que un periodo con duración se ve terminar solo).
final activeDetectionProvider = Provider<DetectionPeriod?>((ref) {
  final now = ref.watch(nowProvider).value ?? DateTime.now().toUtc();
  return DetectionRules.activeOf(
    ref.watch(detectionPeriodsProvider).value ?? const [],
    now,
  );
});
