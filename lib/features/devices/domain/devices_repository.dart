import '../../../core/errors/result.dart';
import 'device.dart';
import 'lights_settings.dart';
import 'thresholds.dart';

abstract interface class DevicesRepository {
  Future<Result<List<Device>>> list();

  /// Cambios en vivo de los módulos de la cuenta (Realtime).
  Stream<List<Device>> watch();

  /// Vincula un módulo con su código (RF-06); aplica los valores de fábrica (RF-07).
  Future<Result<Device>> claim({required String code, String? name});

  Future<Result<Device>> setLights(LightsChange change);

  Future<Result<Device>> setThresholds({
    required String deviceId,
    required Thresholds thresholds,
  });
}
