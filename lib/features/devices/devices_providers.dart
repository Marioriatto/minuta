import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../auth/auth_providers.dart';
import 'data/devices_remote_source.dart';
import 'data/devices_repository_impl.dart';
import 'domain/device.dart';
import 'domain/devices_repository.dart';
import 'domain/devices_use_cases.dart';

/// Punto de composición de la feature (única conexión datos ↔ dominio).

final devicesRemoteProvider = Provider<DevicesRemoteSource>(
  (ref) => SupabaseDevicesRemoteSource(ref.watch(supabaseClientProvider)),
);

final devicesRepositoryProvider = Provider<DevicesRepository>(
  (ref) => DevicesRepositoryImpl(ref.watch(devicesRemoteProvider)),
);

final listDevicesProvider = Provider<ListDevices>(
  (ref) => ListDevices(ref.watch(devicesRepositoryProvider)),
);
final claimDeviceProvider = Provider<ClaimDevice>(
  (ref) => ClaimDevice(ref.watch(devicesRepositoryProvider)),
);
final setLightsProvider = Provider<SetLights>(
  (ref) => SetLights(ref.watch(devicesRepositoryProvider)),
);
final setThresholdsProvider = Provider<SetThresholds>(
  (ref) => SetThresholds(ref.watch(devicesRepositoryProvider)),
);
final buzzCradleProvider = Provider<BuzzCradle>(
  (ref) => BuzzCradle(ref.watch(devicesRepositoryProvider)),
);

/// Módulos de la cuenta: carga inicial + cambios en vivo (Realtime). Si la
/// conexión en vivo falla se conservan los últimos datos conocidos.
class DevicesNotifier extends AsyncNotifier<List<Device>> {
  @override
  Future<List<Device>> build() async {
    final userId =
        ref.watch(authSnapshotProvider.select((s) => s.value?.user?.id));
    if (userId == null) return const [];

    final repo = ref.watch(devicesRepositoryProvider);
    final first = await repo.list();
    final devices = first.when(ok: (d) => d, err: (f) => throw f);

    final sub = repo.watch().listen(
          (latest) => state = AsyncData(latest),
          onError: (Object _) {},
        );
    ref.onDispose(sub.cancel);
    return devices;
  }

  /// Aplica de inmediato el módulo devuelto por una operación confirmada.
  void upsert(Device device) {
    final current = [...?state.value];
    final index = current.indexWhere((d) => d.id == device.id);
    if (index >= 0) {
      current[index] = device;
    } else {
      current.add(device);
    }
    state = AsyncData(current);
  }
}

final devicesProvider =
    AsyncNotifierProvider<DevicesNotifier, List<Device>>(DevicesNotifier.new);

final deviceByIdProvider = Provider.family<Device?, String>((ref, id) {
  final devices = ref.watch(devicesProvider).value ?? const <Device>[];
  for (final d in devices) {
    if (d.id == id) return d;
  }
  return null;
});

/// Reloj que se actualiza cada 10 s: refresca "en línea" y los temporizadores.
final nowProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now().toUtc();
  yield* Stream.periodic(
    const Duration(seconds: 10),
    (_) => DateTime.now().toUtc(),
  );
});
