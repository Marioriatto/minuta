import '../../../core/errors/result.dart';
import 'alert.dart';

abstract interface class AlertsRepository {
  /// Últimas alertas del usuario, de la más reciente a la más vieja.
  Future<Result<List<Alert>>> list({int limit = AlertsRules.pageSize});

  /// Cambios en vivo (Realtime).
  Stream<List<Alert>> watch({int limit = AlertsRules.pageSize});

  /// Marca como leídas las alertas indicadas.
  Future<Result<void>> markRead(List<String> ids);

  /// Marca como leídas todas las alertas del usuario.
  Future<Result<void>> markAllRead();
}
