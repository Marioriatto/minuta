import '../../../core/errors/result.dart';
import 'detection_period.dart';

abstract interface class DetectionRepository {
  /// Periodos recientes de la cuenta (RLS: solo los del usuario).
  Future<Result<List<DetectionPeriod>>> list();

  /// Cambios en vivo (Realtime).
  Stream<List<DetectionPeriod>> watch();

  /// Abre un periodo para [babyId] con el colchón [deviceId].
  /// [minutes] `null` = sin límite.
  Future<Result<DetectionPeriod>> start({
    required String deviceId,
    required String babyId,
    int? minutes,
  });

  /// Cierra el periodo vigente.
  Future<Result<DetectionPeriod>> stop();
}
