import '../../../core/errors/result.dart';
import 'alert.dart';
import 'alerts_repository.dart';

class ListAlerts {
  const ListAlerts(this._repo);
  final AlertsRepository _repo;

  Future<Result<List<Alert>>> call() async {
    final result = await _repo.list();
    return result.when(
      ok: (alerts) => Ok(AlertsRules.sorted(alerts)),
      err: (failure) => Err(failure),
    );
  }
}

/// Marca alertas como leídas. Las ya leídas no se envían al servidor.
class MarkAlertsRead {
  const MarkAlertsRead(this._repo);
  final AlertsRepository _repo;

  Future<Result<void>> call(Iterable<Alert> alerts) {
    final ids = [for (final a in alerts) if (!a.isRead) a.id];
    if (ids.isEmpty) return Future.value(const Ok<void>(null));
    return _repo.markRead(ids);
  }
}

class MarkAllAlertsRead {
  const MarkAllAlertsRead(this._repo);
  final AlertsRepository _repo;

  Future<Result<void>> call(Iterable<Alert> current) {
    if (AlertsRules.unreadCount(current) == 0) {
      return Future.value(const Ok<void>(null));
    }
    return _repo.markAllRead();
  }
}
