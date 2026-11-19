import '../../../core/errors/result.dart';
import '../../../core/errors/run_catching.dart';
import '../domain/dashboard_models.dart';
import '../domain/dashboard_repository.dart';
import 'dashboard_remote_source.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl(this._remote);

  final DashboardRemoteSource _remote;

  @override
  Future<Result<List<HourlyReading>>> hourly({
    required Set<DashboardMetric> metrics,
    required DateTime since,
    String? babyId,
  }) =>
      runCatching(() async {
        final rows = await _remote.hourly(
          metrics: [for (final m in metrics) m.code],
          since: since,
          babyId: babyId,
        );
        return [
          for (final row in rows)
            if (_hourly(row) case final reading?) reading,
        ];
      });

  @override
  Future<Result<List<ActivityEvent>>> recentActivity({
    required String? babyId,
    required int limit,
  }) =>
      runCatching(() async {
        final rows = await _remote.recentEvents(babyId: babyId, limit: limit);
        return [
          for (final row in rows)
            ActivityEvent(
              id: row['id'].toString(),
              type: row['type'] as String,
              description: row['description'] as String?,
              occurredAt: DateTime.parse(row['occurred_at'] as String).toUtc(),
            ),
        ];
      });

  /// Filas con una métrica desconocida o sin valor se ignoran.
  static HourlyReading? _hourly(Map<String, dynamic> row) {
    final metric = DashboardMetric.fromCode(row['metric'] as String? ?? '');
    final value = row['avg_value'];
    final start = row['bucket_start'];
    if (metric == null || value is! num || start is! String) return null;
    return HourlyReading(
      metric: metric,
      bucketStart: DateTime.parse(start).toUtc(),
      average: value.toDouble(),
    );
  }
}
