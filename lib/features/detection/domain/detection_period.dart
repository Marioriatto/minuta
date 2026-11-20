/// Periodo en que el bebé está en el colchón y el sistema vigila movimiento y
/// ausencia (RF-12, APP-010). `endsAt == null` = sin límite (se detiene a mano).
class DetectionPeriod {
  const DetectionPeriod({
    required this.id,
    required this.babyId,
    required this.deviceId,
    required this.startsAt,
    this.endsAt,
  });

  final String id;
  final String? babyId;
  final String? deviceId;
  final DateTime startsAt;
  final DateTime? endsAt;

  bool isActive(DateTime now) {
    final end = endsAt;
    return !startsAt.isAfter(now) && (end == null || end.isAfter(now));
  }

  bool get hasLimit => endsAt != null;
}

/// Duraciones que ofrece la app al iniciar un periodo.
enum DetectionDuration {
  unlimited(null),
  oneHour(60),
  twoHours(120),
  eightHours(480);

  const DetectionDuration(this.minutes);

  /// `null` = sin límite.
  final int? minutes;
}

abstract final class DetectionRules {
  /// Cuántos periodos recientes se cargan (el vigente siempre es el último).
  static const recentLimit = 20;

  /// Máximo que acepta el servidor (`start_detection`): 24 h.
  static const maxMinutes = 1440;

  /// Periodo vigente en [now] (el más reciente si hubiera varios).
  static DetectionPeriod? activeOf(
    Iterable<DetectionPeriod> periods,
    DateTime now,
  ) {
    DetectionPeriod? best;
    for (final p in periods) {
      if (!p.isActive(now)) continue;
      if (best == null || p.startsAt.isAfter(best.startsAt)) best = p;
    }
    return best;
  }
}
