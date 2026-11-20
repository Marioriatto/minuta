import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../babies/babies_providers.dart';
import '../../devices/domain/device.dart';
import '../detection_providers.dart';
import '../domain/detection_period.dart';

enum DetectionActionDone { started, stopped }

@immutable
class DetectionActionState {
  const DetectionActionState({this.busy = false, this.failure, this.done});

  final bool busy;
  final AppFailure? failure;
  final DetectionActionDone? done;
}

/// Iniciar / detener el periodo de detección (RF-12, APP-010).
class DetectionController extends Notifier<DetectionActionState> {
  bool _disposed = false;

  @override
  DetectionActionState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const DetectionActionState();
  }

  Future<void> start(Device mattress, DetectionDuration duration) async {
    if (state.busy) return;
    state = const DetectionActionState(busy: true);
    final result = await ref.read(startDetectionProvider)(
      mattress: mattress,
      baby: ref.read(activeBabyProvider),
      duration: duration,
    );
    if (_disposed) return;
    result.when(
      ok: (period) {
        ref.read(detectionPeriodsProvider.notifier).upsert(period);
        state = const DetectionActionState(done: DetectionActionDone.started);
      },
      err: (failure) => state = DetectionActionState(failure: failure),
    );
  }

  Future<void> stop() async {
    if (state.busy) return;
    state = const DetectionActionState(busy: true);
    final result = await ref.read(stopDetectionProvider)();
    if (_disposed) return;
    result.when(
      ok: (period) {
        ref.read(detectionPeriodsProvider.notifier).upsert(period);
        state = const DetectionActionState(done: DetectionActionDone.stopped);
      },
      err: (failure) => state = DetectionActionState(failure: failure),
    );
  }
}

final detectionControllerProvider =
    NotifierProvider<DetectionController, DetectionActionState>(
  DetectionController.new,
);
