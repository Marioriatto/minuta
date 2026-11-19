import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../devices_providers.dart';
import '../../domain/device.dart';
import '../../domain/device_code.dart';

@immutable
class ClaimDeviceState {
  const ClaimDeviceState({
    this.busy = false,
    this.codeError,
    this.failure,
    this.claimed,
  });

  final bool busy;
  final DeviceCodeError? codeError;
  final AppFailure? failure;

  /// Módulo vinculado con éxito (la pantalla se cierra al recibirlo).
  final Device? claimed;
}

/// Vincular un módulo con su código (RF-06, APP-003).
class ClaimDeviceController extends Notifier<ClaimDeviceState> {
  bool _disposed = false;

  @override
  ClaimDeviceState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const ClaimDeviceState();
  }

  Future<void> submit({required String code, String? name}) async {
    final codeError = DeviceCode.validate(code);
    if (codeError != null) {
      state = ClaimDeviceState(codeError: codeError);
      return;
    }
    state = const ClaimDeviceState(busy: true);
    final result = await ref.read(claimDeviceProvider)(code: code, name: name);
    if (_disposed) return;
    result.when(
      ok: (device) {
        ref.read(devicesProvider.notifier).upsert(device);
        state = ClaimDeviceState(claimed: device);
      },
      err: (failure) => state = ClaimDeviceState(failure: failure),
    );
  }
}

final claimDeviceControllerProvider =
    NotifierProvider<ClaimDeviceController, ClaimDeviceState>(
  ClaimDeviceController.new,
);
