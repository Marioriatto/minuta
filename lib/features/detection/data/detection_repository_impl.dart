import '../../../core/errors/result.dart';
import '../../../core/errors/run_catching.dart';
import '../domain/detection_period.dart';
import '../domain/detection_repository.dart';
import 'detection_remote_source.dart';

class DetectionRepositoryImpl implements DetectionRepository {
  DetectionRepositoryImpl(this._remote);

  final DetectionRemoteSource _remote;

  @override
  Future<Result<List<DetectionPeriod>>> list() => runCatching(() async {
        final rows = await _remote.fetch(limit: DetectionRules.recentLimit);
        return rows.map(DetectionMapper.fromRow).toList();
      });

  @override
  Stream<List<DetectionPeriod>> watch() => _remote
      .stream(limit: DetectionRules.recentLimit)
      .map((rows) => rows.map(DetectionMapper.fromRow).toList());

  @override
  Future<Result<DetectionPeriod>> start({
    required String deviceId,
    required String babyId,
    int? minutes,
  }) =>
      runCatching(() async {
        final row = await _remote.start(
          deviceId: deviceId,
          babyId: babyId,
          minutes: minutes,
        );
        return DetectionMapper.fromRow(row);
      });

  @override
  Future<Result<DetectionPeriod>> stop() => runCatching(
        () async => DetectionMapper.fromRow(await _remote.stop()),
      );
}

abstract final class DetectionMapper {
  static DetectionPeriod fromRow(Map<String, dynamic> row) {
    final endsAt = row['ends_at'];
    return DetectionPeriod(
      id: row['id'].toString(),
      babyId: row['baby_id'] as String?,
      deviceId: row['device_id'] as String?,
      startsAt: DateTime.parse(row['starts_at'] as String).toUtc(),
      endsAt: endsAt is String ? DateTime.parse(endsAt).toUtc() : null,
    );
  }
}
