/// Gravedad de una alerta (columna `severity`). Solo warning y critical
/// generan notificación push; info solo se lista.
enum AlertSeverity {
  info,
  warning,
  critical;

  static AlertSeverity fromCode(String? code) => switch (code) {
        'critical' => critical,
        'warning' => warning,
        _ => info,
      };

  bool get notifies => this != info;
}

/// Alerta generada a partir de un evento de una ampliación (RF-03).
class Alert {
  const Alert({
    required this.id,
    required this.type,
    required this.severity,
    required this.occurredAt,
    this.readAt,
    this.payload = const {},
  });

  final String id;

  /// Código de `event_types` (p. ej. `absence_detected`).
  final String type;
  final AlertSeverity severity;
  final DateTime occurredAt;
  final DateTime? readAt;

  /// Datos del evento: valor medido y límites en las de ambiente.
  final Map<String, Object?> payload;

  bool get isRead => readAt != null;

  double? get value => _num(payload['value']);
  double? get min => _num(payload['min']);
  double? get max => _num(payload['max']);

  Alert markedRead(DateTime at) => Alert(
        id: id,
        type: type,
        severity: severity,
        occurredAt: occurredAt,
        readAt: readAt ?? at,
        payload: payload,
      );
}

double? _num(Object? v) => v is num ? v.toDouble() : null;

/// Reglas puras sobre la lista de alertas.
abstract final class AlertsRules {
  /// Cuántas se cargan y se escuchan en vivo.
  static const pageSize = 100;

  static int unreadCount(Iterable<Alert> alerts) =>
      alerts.where((a) => !a.isRead).length;

  /// Más reciente primero; a igual hora, la de mayor id.
  static List<Alert> sorted(Iterable<Alert> alerts) => [...alerts]
    ..sort((a, b) {
      final byTime = b.occurredAt.compareTo(a.occurredAt);
      return byTime != 0 ? byTime : b.id.compareTo(a.id);
    });
}
