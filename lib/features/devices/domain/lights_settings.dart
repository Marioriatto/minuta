/// Reglas del sistema de luces (RF-20, RF-21, RF-22).
abstract final class LightsRules {
  static const minTimerMinutes = 1;
  static const maxTimerMinutes = 720;
  static const timerPresets = [15, 30, 60, 120];

  static bool isValidTimer(int? minutes) =>
      minutes == null ||
      (minutes >= minTimerMinutes && minutes <= maxTimerMinutes);

  static bool isValidLevel(int value) => value >= 0 && value <= 100;
}

/// Configuración deseada de las luces, tal como la guarda el servidor.
class LightsSettings {
  const LightsSettings({
    this.on = false,
    this.brightness = 50,
    this.speed = 50,
    this.timerMinutes,
    this.endsAt,
  });

  factory LightsSettings.fromConfig(Map<String, Object?> config) {
    int level(Object? v, int fallback) =>
        v is num ? v.round().clamp(0, 100) : fallback;
    final endsAt = config['ends_at'];
    final minutes = config['timer_minutes'];
    return LightsSettings(
      on: config['on'] == true,
      brightness: level(config['brightness'], 50),
      speed: level(config['speed'], 50),
      timerMinutes: minutes is num ? minutes.round() : null,
      endsAt: endsAt is String ? DateTime.tryParse(endsAt)?.toUtc() : null,
    );
  }

  final bool on;
  final int brightness;
  final int speed;
  final int? timerMinutes;
  final DateTime? endsAt;

  /// Encendidas de verdad: el temporizador vencido las considera apagadas
  /// aunque la base aún no lo haya reflejado (el job corre cada minuto).
  bool isOn(DateTime now) {
    final end = endsAt;
    return on && (end == null || now.isBefore(end));
  }

  /// Tiempo que falta para apagarse, o null si no hay temporizador activo.
  Duration? remaining(DateTime now) {
    final end = endsAt;
    if (!isOn(now) || end == null) return null;
    return end.difference(now);
  }
}

/// Un cambio pedido por el usuario sobre las luces.
class LightsChange {
  const LightsChange({
    required this.deviceId,
    required this.on,
    required this.brightness,
    required this.speed,
    this.minutes,
    this.keepTimer = false,
  });

  final String deviceId;
  final bool on;
  final int brightness;
  final int speed;

  /// Duración del temporizador a partir de ahora (null = sin temporizador).
  final int? minutes;

  /// Conserva el temporizador en curso (para cambios de brillo o velocidad).
  final bool keepTimer;
}
