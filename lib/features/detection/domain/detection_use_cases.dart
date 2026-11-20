import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../babies/domain/baby.dart';
import '../../devices/domain/device.dart';
import 'detection_period.dart';
import 'detection_repository.dart';

/// Inicia el periodo de detección (RF-12). Valida en el cliente lo que el
/// servidor también valida, para no viajar en vano.
class StartDetection {
  const StartDetection(this._repo);
  final DetectionRepository _repo;

  Future<Result<DetectionPeriod>> call({
    required Device mattress,
    required Baby? baby,
    required DetectionDuration duration,
  }) async {
    if (mattress.kind != DeviceKind.mattress) {
      return const Err(
        MattressWeightFailure(MattressWeightProblem.notLinked),
      );
    }
    if (baby == null || baby.isArchived) {
      return const Err(DetectionFailure(DetectionProblem.noActiveBaby));
    }
    return _repo.start(
      deviceId: mattress.id,
      babyId: baby.id,
      minutes: duration.minutes,
    );
  }
}

/// Detiene el periodo vigente.
class StopDetection {
  const StopDetection(this._repo);
  final DetectionRepository _repo;

  Future<Result<DetectionPeriod>> call() => _repo.stop();
}
