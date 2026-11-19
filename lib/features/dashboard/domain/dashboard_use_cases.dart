import '../../../core/errors/result.dart';
import 'dashboard_models.dart';
import 'dashboard_repository.dart';

/// Historial para las gráficas del inicio (RF-05).
class LoadDashboardHistory {
  LoadDashboardHistory(this._repository, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final DashboardRepository _repository;
  final DateTime Function() _now;

  Future<Result<DashboardHistory>> call({required String? babyId}) async {
    final now = _now().toUtc();

    final environment = await _repository.hourly(
      metrics: const {DashboardMetric.temperature, DashboardMetric.humidity},
      since: now.subtract(
        const Duration(hours: DashboardSeries.environmentHours),
      ),
    );
    if (environment case Err(:final failure)) return Err(failure);
    final env = (environment as Ok<List<HourlyReading>>).value;

    // Sin bebé activo no hay peso que mostrar.
    var weight = const <HourlyReading>[];
    if (babyId != null) {
      final result = await _repository.hourly(
        metrics: const {DashboardMetric.weight},
        since: now.subtract(const Duration(days: DashboardSeries.weightDays)),
        babyId: babyId,
      );
      if (result case Err(:final failure)) return Err(failure);
      weight = (result as Ok<List<HourlyReading>>).value;
    }

    return Ok(
      DashboardHistory(
        dailyWeight: DashboardSeries.dailyWeight(weight),
        temperature: DashboardSeries.hourly(env, DashboardMetric.temperature),
        humidity: DashboardSeries.hourly(env, DashboardMetric.humidity),
      ),
    );
  }
}

/// Actividad reciente para el inicio (RF-02, RF-10).
class LoadRecentActivity {
  const LoadRecentActivity(this._repository);
  final DashboardRepository _repository;

  static const limit = 8;

  Future<Result<List<ActivityEvent>>> call({required String? babyId}) =>
      _repository.recentActivity(babyId: babyId, limit: limit);
}
