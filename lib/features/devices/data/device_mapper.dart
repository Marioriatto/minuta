import '../domain/device.dart';

abstract final class DeviceMapper {
  static Device fromRow(Map<String, dynamic> row) => Device(
        id: row['id'] as String,
        kind: DeviceKind.fromCode(row['kind'] as String? ?? ''),
        name: row['name'] as String?,
        config: _object(row['config']),
        reportedState: _object(row['reported_state']),
        lastSeenAt: _time(row['last_seen_at']),
        firmware: row['firmware'] as String?,
      );

  static Map<String, Object?> _object(Object? value) =>
      value is Map ? Map<String, Object?>.from(value) : const {};

  static DateTime? _time(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;
}
