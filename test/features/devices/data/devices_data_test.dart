import 'package:colchon_minuta/core/errors/app_failure.dart';
import 'package:colchon_minuta/core/errors/result.dart';
import 'package:colchon_minuta/features/devices/data/device_mapper.dart';
import 'package:colchon_minuta/features/devices/data/devices_remote_source.dart';
import 'package:colchon_minuta/features/devices/data/devices_repository_impl.dart';
import 'package:colchon_minuta/features/devices/domain/device.dart';
import 'package:colchon_minuta/features/devices/domain/lights_settings.dart';
import 'package:colchon_minuta/features/devices/domain/thresholds.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

Map<String, dynamic> row({
  String kind = 'cradle',
  Object? config,
  Object? reported,
}) =>
    {
      'id': 'd1',
      'kind': kind,
      'name': 'Cuna de Emma',
      'config': config ?? {'thresholds': <String, dynamic>{}},
      'reported_state': reported ?? {'temperature_c': 24.1, 'humidity_pct': 50},
      'last_seen_at': '2026-11-19T18:00:00.123456+00:00',
      'firmware': 'sim-0.1.0',
    };

class FakeRemote implements DevicesRemoteSource {
  Object? error;
  final calls = <String>[];
  Map<String, Object?> lastLightsParams = {};

  T _maybeThrow<T>(T value) {
    if (error != null) throw error!;
    return value;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAll() async =>
      _maybeThrow([row(), row(kind: 'lights')]);

  @override
  Stream<List<Map<String, dynamic>>> stream() =>
      Stream.value([row(kind: 'mattress')]);

  @override
  Future<Map<String, dynamic>> claim({
    required String code,
    String? name,
  }) async {
    calls.add('claim:$code');
    return _maybeThrow(row(kind: 'lights'));
  }

  @override
  Future<Map<String, dynamic>> setLights({
    required String deviceId,
    required bool on,
    required int brightness,
    required int speed,
    int? minutes,
    bool keepTimer = false,
  }) async {
    lastLightsParams = {
      'on': on,
      'brightness': brightness,
      'speed': speed,
      'minutes': minutes,
      'keepTimer': keepTimer,
    };
    return _maybeThrow(row(kind: 'lights'));
  }

  @override
  Future<Map<String, dynamic>> setThresholds({
    required String deviceId,
    double? tempMin,
    double? tempMax,
    double? humMin,
    double? humMax,
  }) async {
    calls.add('thresholds:$tempMin:$tempMax:$humMin:$humMax');
    return _maybeThrow(row());
  }
}

void main() {
  group('DeviceMapper', () {
    test('mapea una fila completa', () {
      final d = DeviceMapper.fromRow(row());
      expect(d.kind, DeviceKind.cradle);
      expect(d.name, 'Cuna de Emma');
      expect(d.temperatureC, 24.1);
      expect(d.humidityPct, 50);
      expect(d.lastSeenAt, DateTime.utc(2026, 11, 19, 18, 0, 0, 123, 456));
      expect(d.firmware, 'sim-0.1.0');
    });

    test('tipo desconocido y campos nulos no fallan', () {
      final d = DeviceMapper.fromRow({
        'id': 'x',
        'kind': 'drone',
        'name': null,
        'config': null,
        'reported_state': null,
        'last_seen_at': null,
      });
      expect(d.kind, DeviceKind.unknown);
      expect(d.config, isEmpty);
      expect(d.lastSeenAt, isNull);
      expect(d.isOnline(DateTime.utc(2026)), isFalse);
    });

    test('en línea solo si habló en los últimos 30 s', () {
      final d = DeviceMapper.fromRow(row());
      final seen = d.lastSeenAt!;
      expect(d.isOnline(seen.add(const Duration(seconds: 30))), isTrue);
      expect(d.isOnline(seen.add(const Duration(seconds: 31))), isFalse);
    });
  });

  group('DevicesRepositoryImpl', () {
    test('list mapea todas las filas', () async {
      final repo = DevicesRepositoryImpl(FakeRemote());
      final result = await repo.list();
      final devices = (result as Ok<List<Device>>).value;
      expect(
        devices.map((d) => d.kind),
        [DeviceKind.cradle, DeviceKind.lights],
      );
    });

    test('watch mapea el flujo en vivo', () async {
      final repo = DevicesRepositoryImpl(FakeRemote());
      final first = await repo.watch().first;
      expect(first.single.kind, DeviceKind.mattress);
    });

    test('código inexistente se traduce a InvalidDeviceCodeFailure', () async {
      final remote = FakeRemote()
        ..error = const sb.PostgrestException(
          message: 'invalid_or_used_code',
          code: 'P0002',
        );
      final result = await DevicesRepositoryImpl(remote).claim(code: 'X');
      expect((result as Err<Device>).failure, isA<InvalidDeviceCodeFailure>());
    });

    test('módulo ajeno o inexistente se traduce a NotFoundFailure', () async {
      final remote = FakeRemote()
        ..error = const sb.PostgrestException(
          message: 'device_not_found',
          code: 'P0002',
        );
      final result = await DevicesRepositoryImpl(remote).setLights(
        const LightsChange(deviceId: 'd', on: true, brightness: 1, speed: 1),
      );
      expect((result as Err<Device>).failure, isA<NotFoundFailure>());
    });

    test('valores inválidos del servidor (22023) son ValidationFailure',
        () async {
      final remote = FakeRemote()
        ..error = const sb.PostgrestException(
          message: 'invalid_timer',
          code: '22023',
        );
      final result = await DevicesRepositoryImpl(remote).setLights(
        const LightsChange(deviceId: 'd', on: true, brightness: 1, speed: 1),
      );
      expect((result as Err<Device>).failure, isA<ValidationFailure>());
    });

    test('un error inesperado devuelve Err', () async {
      final remote = FakeRemote()..error = Exception('x');
      final result = await DevicesRepositoryImpl(remote).list();
      expect(result, isA<Err<List<Device>>>());
    });

    test('setLights pasa todos los parámetros', () async {
      final remote = FakeRemote();
      await DevicesRepositoryImpl(remote).setLights(
        const LightsChange(
          deviceId: 'd',
          on: true,
          brightness: 80,
          speed: 30,
          minutes: 15,
          keepTimer: true,
        ),
      );
      expect(remote.lastLightsParams, {
        'on': true,
        'brightness': 80,
        'speed': 30,
        'minutes': 15,
        'keepTimer': true,
      });
    });

    test('setThresholds envía los cuatro límites', () async {
      final remote = FakeRemote();
      await DevicesRepositoryImpl(remote).setThresholds(
        deviceId: 'd',
        thresholds: const Thresholds(tempMin: 18, tempMax: 26, humMax: 60),
      );
      expect(remote.calls, ['thresholds:18.0:26.0:null:60.0']);
    });
  });
}
