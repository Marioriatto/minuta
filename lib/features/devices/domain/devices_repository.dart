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

  /// Hace sonar el buzzer de la cuna [milliseconds] ms. El puente lo recoge
  /// en su siguiente consulta (~3 s).
  Future<Result<void>> buzz({
    required String deviceId,
    required int milliseconds,
  });
}
