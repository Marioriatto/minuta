import '../../../core/errors/result.dart';
import '../../../core/errors/run_catching.dart';
import '../domain/device.dart';
import '../domain/devices_repository.dart';
import '../domain/lights_settings.dart';
import '../domain/thresholds.dart';
import 'device_mapper.dart';
import 'devices_remote_source.dart';

class DevicesRepositoryImpl implements DevicesRepository {
  DevicesRepositoryImpl(this._remote);

  final DevicesRemoteSource _remote;

  @override
  Future<Result<List<Device>>> list() => runCatching(() async {
        final rows = await _remote.fetchAll();
        return rows.map(DeviceMapper.fromRow).toList();
      });

  @override
  Stream<List<Device>> watch() =>
      _remote.stream().map((rows) => rows.map(DeviceMapper.fromRow).toList());

  @override
  Future<Result<Device>> claim({required String code, String? name}) =>
      runCatching(
        () async => DeviceMapper.fromRow(
          await _remote.claim(code: code, name: name),
        ),
      );

  @override
  Future<Result<Device>> setLights(LightsChange change) => runCatching(
        () async => DeviceMapper.fromRow(
          await _remote.setLights(
            deviceId: change.deviceId,
            on: change.on,
            brightness: change.brightness,
            speed: change.speed,
            minutes: change.minutes,
            keepTimer: change.keepTimer,
          ),
        ),
      );

  @override
  Future<Result<Device>> setThresholds({
    required String deviceId,
    required Thresholds thresholds,
  }) =>
      runCatching(
        () async => DeviceMapper.fromRow(
          await _remote.setThresholds(
            deviceId: deviceId,
            tempMin: thresholds.tempMin,
            tempMax: thresholds.tempMax,
            humMin: thresholds.humMin,
            humMax: thresholds.humMax,
          ),
        ),
      );
}
