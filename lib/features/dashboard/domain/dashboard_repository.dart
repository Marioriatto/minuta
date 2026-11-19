import '../../../core/errors/result.dart';
import 'dashboard_models.dart';

abstract interface class DashboardRepository {
  /// Promedios horarios de [metrics] desde [since]. Si [babyId] no es nulo,
  /// solo las lecturas de ese bebé (el peso); si es nulo, todas las de la
  /// cuenta (el ambiente de la cuna no depende del bebé).
  Future<Result<List<HourlyReading>>> hourly({
    required Set<DashboardMetric> metrics,
    required DateTime since,
    String? babyId,
  });

  /// Últimos eventos del bebé [babyId] y los que no tienen bebé asociado
  /// (p. ej. cambios de luces), del más nuevo al más viejo.
  Future<Result<List<ActivityEvent>>> recentActivity({
    required String? babyId,
    required int limit,
  });
}
