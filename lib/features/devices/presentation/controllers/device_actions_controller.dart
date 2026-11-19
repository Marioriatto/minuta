import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../devices_providers.dart';
import '../../domain/lights_settings.dart';
import '../../domain/thresholds.dart';

enum DeviceActionDone { lights, thresholds }

@immutable
class DeviceActionState {
  const DeviceActionState({this.busy = false, this.failure, this.done});

  final bool busy;
  final AppFailure? failure;
  final DeviceActionDone? done;
}

/// Cambios de configuración de luces (RF-20/21/22) y umbrales (RF-18).
class DeviceActionsController extends Notifier<DeviceActionState> {
  bool _disposed = false;
  bool _sendingLights = false;
  LightsChange? _pendingLights;

  @override
  DeviceActionState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const DeviceActionState();
  }

  /// Si el usuario mueve un control mientras otro cambio viaja, solo se envía
  /// el más reciente al terminar el anterior (el último gana).
  Future<void> setLights(LightsChange change) async {
    _pendingLights = change;
    if (_sendingLights) return;
    _sendingLights = true;
    try {
      while (_pendingLights != null && !_disposed) {
        final next = _pendingLights!;
        _pendingLights = null;
        state = const DeviceActionState(busy: true);
        final result = await ref.read(setLightsProvider)(next);
        if (_disposed) return;
        result.when(
          ok: (device) {
            ref.read(devicesProvider.notifier).upsert(device);
            state = const DeviceActionState(done: DeviceActionDone.lights);
          },
          err: (failure) {
            _pendingLights = null;
            state = DeviceActionState(failure: failure);
          },
        );
      }
    } finally {
      _sendingLights = false;
    }
  }

  Future<void> setThresholds({
    required String deviceId,
    required Thresholds thresholds,
  }) async {
    state = const DeviceActionState(busy: true);
    final result = await ref.read(setThresholdsProvider)(
      deviceId: deviceId,
      thresholds: thresholds,
    );
    if (_disposed) return;
    result.when(
      ok: (device) {
        ref.read(devicesProvider.notifier).upsert(device);
        state = const DeviceActionState(done: DeviceActionDone.thresholds);
      },
      err: (failure) => state = DeviceActionState(failure: failure),
    );
  }
}

final deviceActionsControllerProvider =
    NotifierProvider<DeviceActionsController, DeviceActionState>(
  DeviceActionsController.new,
);
