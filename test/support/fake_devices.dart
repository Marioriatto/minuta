import 'dart:async';

import 'package:colchon_minuta/core/errors/app_failure.dart';
import 'package:colchon_minuta/core/errors/result.dart';
import 'package:colchon_minuta/features/devices/devices_providers.dart';
import 'package:colchon_minuta/features/devices/domain/device.dart';
import 'package:colchon_minuta/features/devices/domain/devices_repository.dart';
import 'package:colchon_minuta/features/devices/domain/lights_settings.dart';
import 'package:colchon_minuta/features/devices/domain/thresholds.dart';

Device makeDevice({
  String id = 'd1',
  DeviceKind kind = DeviceKind.lights,
  String? name = 'Luces',
  Map<String, Object?> config = const {},
  Map<String, Object?> reportedState = const {},
  DateTime? lastSeenAt,
}) =>
    Device(
      id: id,
      kind: kind,
      name: name,
      config: config,
      reportedState: reportedState,
      lastSeenAt: lastSeenAt,
    );

/// Repositorio en memoria. Con [failWith] todas las operaciones fallan; con
/// [gate] las llamadas a `setLights` esperan hasta que se complete.
class FakeDevicesRepository implements DevicesRepository {
  FakeDevicesRepository([List<Device>? initial]) : store = [...?initial];

  final List<Device> store;
  AppFailure? failWith;
  Completer<void>? gate;
  final calls = <String>[];
  final lightsChanges = <LightsChange>[];

  @override
  Future<Result<List<Device>>> list() async {
    calls.add('list');
    if (failWith != null) return Err(failWith!);
    return Ok([...store]);
  }

  @override
  Stream<List<Device>> watch() => const Stream.empty();

  @override
  Future<Result<Device>> claim({required String code, String? name}) async {
    calls.add('claim:$code:$name');
    if (failWith != null) return Err(failWith!);
    final device = makeDevice(id: 'new${store.length + 1}', name: name);
    store.add(device);
    return Ok(device);
  }

  @override
  Future<Result<Device>> setLights(LightsChange change) async {
    lightsChanges.add(change);
    if (gate != null) await gate!.future;
    if (failWith != null) return Err(failWith!);
    return Ok(
      makeDevice(
        id: change.deviceId,
        config: {
          'on': change.on,
          'brightness': change.brightness,
          'speed': change.speed,
        },
      ),
    );
  }

  @override
  Future<Result<Device>> setThresholds({
    required String deviceId,
    required Thresholds thresholds,
  }) async {
    calls.add('thresholds:$deviceId:${thresholds.tempMax}');
    if (failWith != null) return Err(failWith!);
    return Ok(makeDevice(id: deviceId, kind: DeviceKind.cradle));
  }

  @override
  Future<Result<void>> buzz({
    required String deviceId,
    required int milliseconds,
  }) async {
    calls.add('buzz:$deviceId:$milliseconds');
    if (failWith != null) return Err(failWith!);
    return const Ok<void>(null);
  }
}

/// Lista de módulos fija para pruebas de controladores (sin sesión ni red).
class FakeDevicesNotifier extends DevicesNotifier {
  @override
  Future<List<Device>> build() async => const [];
}
