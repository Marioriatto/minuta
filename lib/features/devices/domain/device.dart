enum DeviceKind {
  mattress,
  cradle,
  lights,
  feeder,
  toy,
  room,
  unknown;

  static DeviceKind fromCode(String code) => switch (code) {
        'mattress' => mattress,
        'cradle' => cradle,
        'lights' => lights,
        'feeder' => feeder,
        'toy' => toy,
        'room' => room,
        _ => unknown,
      };

  /// Tipos con pantalla propia en esta versión de la app.
  bool get hasControls => this == mattress || this == cradle || this == lights;
}

/// Un módulo está en línea si habló con el servidor hace poco.
const deviceOnlineWindow = Duration(seconds: 30);

/// Módulo físico vinculado a la cuenta (RF-06, RF-08).
class Device {
  const Device({
    required this.id,
    required this.kind,
    required this.name,
    required this.config,
    required this.reportedState,
    this.lastSeenAt,
    this.firmware,
  });

  final String id;
  final DeviceKind kind;
  final String? name;

  /// Estado DESEADO: lo escribe la app (luces, umbrales...).
  final Map<String, Object?> config;

  /// Estado REAL: últimos valores medidos por el módulo.
  final Map<String, Object?> reportedState;
  final DateTime? lastSeenAt;
  final String? firmware;

  bool isOnline(DateTime now) {
    final seen = lastSeenAt;
    return seen != null && now.difference(seen) <= deviceOnlineWindow;
  }

  double? get temperatureC => _asDouble(reportedState['temperature_c']);
  double? get humidityPct => _asDouble(reportedState['humidity_pct']);

  /// Peso que mide ahora el colchón (kg).
  double? get weightKg => _asDouble(reportedState['weight_kg']);
}

double? _asDouble(Object? value) => value is num ? value.toDouble() : null;
