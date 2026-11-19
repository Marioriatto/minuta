import 'package:colchon_minuta/core/errors/app_failure.dart';
import 'package:colchon_minuta/core/errors/result.dart';
import 'package:colchon_minuta/features/devices/domain/device.dart';
import 'package:colchon_minuta/features/devices/domain/devices_use_cases.dart';
import 'package:colchon_minuta/features/devices/domain/lights_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_devices.dart';

void main() {
  group('BuzzCradle', () {
    test('solo la cuna puede sonar y con duración válida', () async {
      final repo = FakeDevicesRepository();
      final buzz = BuzzCradle(repo);
      final lights = makeDevice(kind: DeviceKind.lights);
      final cradle = makeDevice(id: 'c1', kind: DeviceKind.cradle);

      Object? failureOf(Result<void> r) =>
          r.when(ok: (_) => null, err: (f) => f);

      expect(failureOf(await buzz(lights)), isA<ValidationFailure>());
      expect(
        failureOf(await buzz(cradle, milliseconds: 10)),
        isA<ValidationFailure>(),
      );
      expect(
        failureOf(await buzz(cradle, milliseconds: 9000)),
        isA<ValidationFailure>(),
      );
      expect(repo.calls, isEmpty);

      expect(failureOf(await buzz(cradle)), isNull);
      expect(repo.calls, ['buzz:c1:1000']);
    });
  });

  group('ClaimDevice', () {
    test('un código inválido no llega al servidor', () async {
      final repo = FakeDevicesRepository();
      final result = await ClaimDevice(repo)(code: 'ABC');
      expect(result, isA<Err<Device>>());
      expect((result as Err<Device>).failure, isA<ValidationFailure>());
      expect(repo.calls, isEmpty);
    });

    test('normaliza el código y recorta el nombre', () async {
      final repo = FakeDevicesRepository();
      await ClaimDevice(repo)(code: 'd05c-7563-7154-4754', name: '  Cuna  ');
      expect(repo.calls, ['claim:D05C756371544754:Cuna']);
    });

    test('un nombre vacío se envía como nulo', () async {
      final repo = FakeDevicesRepository();
      await ClaimDevice(repo)(code: 'D05C756371544754', name: '   ');
      expect(repo.calls, ['claim:D05C756371544754:null']);
    });
  });

  group('SetLights', () {
    LightsChange change({int brightness = 50, int speed = 50, int? minutes}) =>
        LightsChange(
          deviceId: 'd1',
          on: true,
          brightness: brightness,
          speed: speed,
          minutes: minutes,
        );

    test('rechaza valores fuera de rango sin llamar al servidor', () async {
      final repo = FakeDevicesRepository();
      final useCase = SetLights(repo);
      for (final bad in [
        change(brightness: 101),
        change(speed: -1),
        change(minutes: 0),
        change(minutes: 721),
      ]) {
        expect(await useCase(bad), isA<Err<Device>>());
      }
      expect(repo.lightsChanges, isEmpty);
    });

    test('envía un cambio válido', () async {
      final repo = FakeDevicesRepository();
      final result = await SetLights(repo)(change(minutes: 30));
      expect(result, isA<Ok<Device>>());
      expect(repo.lightsChanges.single.minutes, 30);
    });
  });
}
