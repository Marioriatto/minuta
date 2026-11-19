import '../../../core/errors/result.dart';
import '../../../core/errors/run_catching.dart';
import '../domain/alert.dart';
import '../domain/alerts_repository.dart';
import 'alerts_remote_source.dart';

class AlertsRepositoryImpl implements AlertsRepository {
  AlertsRepositoryImpl(this._remote);

  final AlertsRemoteSource _remote;

  @override
  Future<Result<List<Alert>>> list({int limit = AlertsRules.pageSize}) =>
      runCatching(() async {
        final rows = await _remote.fetch(limit: limit);
        return rows.map(AlertMapper.fromRow).toList();
      });

  @override
  Stream<List<Alert>> watch({int limit = AlertsRules.pageSize}) => _remote
      .stream(limit: limit)
      .map((rows) => AlertsRules.sorted(rows.map(AlertMapper.fromRow)));

  @override
  Future<Result<void>> markRead(List<String> ids) => runCatching<void>(
        () => _remote.markRead([for (final id in ids) int.parse(id)]),
      );

  @override
  Future<Result<void>> markAllRead() =>
      runCatching<void>(() => _remote.markRead(null));
}

abstract final class AlertMapper {
  static Alert fromRow(Map<String, dynamic> row) {
    final payload = row['payload'];
    final readAt = row['read_at'];
    return Alert(
      id: row['id'].toString(),
      type: row['type'] as String? ?? '',
      severity: AlertSeverity.fromCode(row['severity'] as String?),
      occurredAt: DateTime.parse(row['occurred_at'] as String).toUtc(),
      readAt: readAt is String ? DateTime.parse(readAt).toUtc() : null,
      payload: payload is Map ? Map<String, Object?>.from(payload) : const {},
    );
  }
}
