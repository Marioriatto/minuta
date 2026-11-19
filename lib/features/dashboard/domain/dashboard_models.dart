/// Métricas que reporta el hardware (columna `metric` de `readings`).
enum DashboardMetric {
  weight('weight'),
  temperature('temperature'),
  humidity('humidity');

  const DashboardMetric(this.code);
  final String code;

  static DashboardMetric? fromCode(String code) {
    for (final m in values) {
      if (m.code == code) return m;
    }
    return null;
  }
}

/// Promedio de una métrica en una hora (tabla `readings_hourly`).
class HourlyReading {
  const HourlyReading({
    required this.metric,
    required this.bucketStart,
    required this.average,
  });

  final DashboardMetric metric;
  final DateTime bucketStart;
  final double average;
}

/// Un punto de una gráfica.
class ChartPoint {
  const ChartPoint(this.at, this.value);
  final DateTime at;
  final double value;

  @override
  bool operator ==(Object other) =>
      other is ChartPoint && other.at == at && other.value == value;

  @override
  int get hashCode => Object.hash(at, value);

  @override
  String toString() => 'ChartPoint($at, $value)';
}

/// Grupo de un evento para elegir ícono y texto.
enum ActivityCategory {
  mattress,
  environment,
  lights,
  feeding,
  toy,
  room,
  other
}

/// Un evento registrado por una ampliación (tabla `events`, RF-02).
class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.type,
    required this.occurredAt,
    this.description,
  });

  final String id;

  /// Código de `event_types` (p. ej. `presence_detected`).
  final String type;
  final DateTime occurredAt;
  final String? description;

  ActivityCategory get category => switch (type) {
        'presence_detected' ||
        'absence_detected' ||
        'movement_detected' ||
        'detection_started' ||
        'detection_ended' =>
          ActivityCategory.mattress,
        'temperature_high' ||
        'temperature_low' ||
        'humidity_high' ||
        'humidity_low' =>
          ActivityCategory.environment,
        'lights_changed' => ActivityCategory.lights,
        'feeding_started' ||
        'feeding_completed' ||
        'feeding_reminder' =>
          ActivityCategory.feeding,
        'toy_motion' ||
        'toy_session_started' ||
        'toy_session_ended' =>
          ActivityCategory.toy,
        'door_opened' || 'room_motion' => ActivityCategory.room,
        _ => ActivityCategory.other,
      };
}

/// Historial para las gráficas del inicio. Listas vacías = aún no hay datos.
class DashboardHistory {
  const DashboardHistory({
    this.dailyWeight = const [],
    this.temperature = const [],
    this.humidity = const [],
  });

  /// Peso promedio por día del bebé activo (últimos 14 días).
  final List<ChartPoint> dailyWeight;

  /// Temperatura y humedad por hora (últimas 24 h).
  final List<ChartPoint> temperature;
  final List<ChartPoint> humidity;

  bool get hasWeight => dailyWeight.isNotEmpty;
  bool get hasEnvironment => temperature.isNotEmpty || humidity.isNotEmpty;
}

/// Reglas puras para armar las series a partir de las lecturas horarias.
abstract final class DashboardSeries {
  static const weightDays = 14;
  static const environmentHours = 24;

  /// Por debajo de esto el colchón está vacío: no es el peso del bebé.
  static const minBabyWeightKg = 1.0;

  /// Promedia el peso por día local, ignorando horas con el colchón vacío.
  static List<ChartPoint> dailyWeight(Iterable<HourlyReading> readings) {
    final sums = <DateTime, (double, int)>{};
    for (final r in readings) {
      if (r.metric != DashboardMetric.weight) continue;
      if (r.average < minBabyWeightKg) continue;
      final local = r.bucketStart.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final (sum, n) = sums[day] ?? (0.0, 0);
      sums[day] = (sum + r.average, n + 1);
    }
    final days = sums.keys.toList()..sort();
    return [
      for (final d in days)
        ChartPoint(
          d,
          double.parse((sums[d]!.$1 / sums[d]!.$2).toStringAsFixed(3)),
        ),
    ];
  }

  /// Serie horaria de una métrica, ordenada en el tiempo.
  static List<ChartPoint> hourly(
    Iterable<HourlyReading> readings,
    DashboardMetric metric,
  ) {
    final points = [
      for (final r in readings)
        if (r.metric == metric) ChartPoint(r.bucketStart.toLocal(), r.average),
    ]..sort((a, b) => a.at.compareTo(b.at));
    return points;
  }
}
