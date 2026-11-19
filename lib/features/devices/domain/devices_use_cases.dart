import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import 'device.dart';
import 'device_code.dart';
import 'devices_repository.dart';
import 'lights_settings.dart';
import 'thresholds.dart';

class ListDevices {
  const ListDevices(this._repo);
  final DevicesRepository _repo;
  Future<Result<List<Device>>> call() => _repo.list();
}

/// Vincula un módulo (RF-06, APP-003). El código se normaliza antes de enviarlo.
class ClaimDevice {
  const ClaimDevice(this._repo);
  final DevicesRepository _repo;

  Future<Result<Device>> call({required String code, String? name}) {
    if (DeviceCode.validate(code) != null) {
      return Future.value(const Err(ValidationFailure()));
    }
    final trimmed = name?.trim();
    return _repo.claim(
      code: DeviceCode.normalize(code),
      name: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
    );
  }
}

class SetLights {
  const SetLights(this._repo);
  final DevicesRepository _repo;

  Future<Result<Device>> call(LightsChange change) {
    final valid = LightsRules.isValidLevel(change.brightness) &&
        LightsRules.isValidLevel(change.speed) &&
        LightsRules.isValidTimer(change.minutes);
    if (!valid) return Future.value(const Err(ValidationFailure()));
    return _repo.setLights(change);
  }
}

/// Pitido del buzzer de la cuna. Solo para cunas y con una duración razonable
/// (el firmware además lo limita a 5 s).
class BuzzCradle {
  const BuzzCradle(this._repo);
  final DevicesRepository _repo;

  static const defaultMs = 1000;
  static const minMs = 100;
  static const maxMs = 5000;

  Future<Result<void>> call(Device device, {int milliseconds = defaultMs}) {
    if (device.kind != DeviceKind.cradle ||
        milliseconds < minMs ||
        milliseconds > maxMs) {
      return Future.value(const Err(ValidationFailure()));
    }
    return _repo.buzz(deviceId: device.id, milliseconds: milliseconds);
  }
}

class SetThresholds {
  const SetThresholds(this._repo);
  final DevicesRepository _repo;

  Future<Result<Device>> call({
    required String deviceId,
    required Thresholds thresholds,
  }) =>
      _repo.setThresholds(deviceId: deviceId, thresholds: thresholds);
}
