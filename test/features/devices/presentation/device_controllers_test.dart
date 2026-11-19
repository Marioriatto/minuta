import 'dart:async';

import 'package:colchon_minuta/core/errors/app_failure.dart';
import 'package:colchon_minuta/features/devices/devices_providers.dart';
import 'package:colchon_minuta/features/devices/domain/device_code.dart';
import 'package:colchon_minuta/features/devices/domain/lights_settings.dart';
import 'package:colchon_minuta/features/devices/domain/thresholds.dart';
import 'package:colchon_minuta/features/devices/presentation/controllers/claim_device_controller.dart';
import 'package:colchon_minuta/features/devices/presentation/controllers/device_actions_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_devices.dart';

ProviderContainer _container(FakeDevicesRepository repo) {
  final c = ProviderContainer(
    overrides: [
      devicesRepositoryProvider.overrideWithValue(repo),
      devicesProvider.overrideWith(FakeDevicesNotifier.new),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

LightsChange _change(int brightness) => LightsChange(
      deviceId: 'd1',
      on: true,
      brightness: brightness,
      speed: 50,
    );

void main() {
  group('ClaimDeviceController', () {
    test('código vacío muestra error de campo sin llamar al servidor',
        () async {
      final repo = FakeDevicesRepository();
      final c = _container(repo);
      await c.read(claimDeviceControllerProvider.notifier).submit(code: '');
      final s = c.read(claimDeviceControllerProvider);
      expect(s.codeError, DeviceCodeError.empty);
      expect(repo.calls, isEmpty);
    });

    test('vincula con éxito', () async {
      final repo = FakeDevicesRepository();
      final c = _container(repo);
      await c
          .read(claimDeviceControllerProvider.notifier)
          .submit(code: 'D05C-7563-7154-4754', name: 'Luces');
      final s = c.read(claimDeviceControllerProvider);
      expect(s.claimed, isNotNull);
      expect(s.failure, isNull);
      expect(repo.calls.single, startsWith('claim:D05C756371544754'));
    });

    test('un fallo del servidor queda en el estado', () async {
      final repo = FakeDevicesRepository()
        ..failWith = const InvalidDeviceCodeFailure();
      final c = _container(repo);
      await c
          .read(claimDeviceControllerProvider.notifier)
          .submit(code: 'D05C756371544754');
      final s = c.read(claimDeviceControllerProvider);
      expect(s.failure, isA<InvalidDeviceCodeFailure>());
      expect(s.claimed, isNull);
      expect(s.busy, isFalse);
    });
  });

  group('DeviceActionsController', () {
    test('guarda umbrales', () async {
      final repo = FakeDevicesRepository();
      final c = _container(repo);
      await c.read(deviceActionsControllerProvider.notifier).setThresholds(
            deviceId: 'd1',
            thresholds: const Thresholds(tempMax: 26),
          );
      final s = c.read(deviceActionsControllerProvider);
      expect(s.done, DeviceActionDone.thresholds);
      expect(repo.calls.single, 'thresholds:d1:26.0');
    });

    test('un fallo de luces queda en el estado', () async {
      final repo = FakeDevicesRepository()..failWith = const NetworkFailure();
      final c = _container(repo);
      await c
          .read(deviceActionsControllerProvider.notifier)
          .setLights(_change(10));
      expect(
        c.read(deviceActionsControllerProvider).failure,
        isA<NetworkFailure>(),
      );
    });

    test('mientras un cambio viaja solo se envía el más reciente', () async {
      final repo = FakeDevicesRepository()..gate = Completer<void>();
      final c = _container(repo);
      final notifier = c.read(deviceActionsControllerProvider.notifier);

      final first = notifier.setLights(_change(10));
      await Future<void>.delayed(Duration.zero);
      final second = notifier.setLights(_change(20));
      final third = notifier.setLights(_change(30));
      repo.gate!.complete();
      await Future.wait([first, second, third]);

      expect(repo.lightsChanges.map((l) => l.brightness), [10, 30]);
      expect(
        c.read(deviceActionsControllerProvider).done,
        DeviceActionDone.lights,
      );
    });
  });
}
