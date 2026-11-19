import '../../../core/errors/result.dart';
import 'push_gateway.dart';
import 'push_tokens_repository.dart';

enum PushSyncOutcome { registered, unavailable, permissionDenied, noToken }

/// Tras iniciar sesión: pide permiso y registra el token del teléfono.
class SyncPushToken {
  const SyncPushToken(this._gateway, this._repo);
  final PushGateway _gateway;
  final PushTokensRepository _repo;

  Future<Result<PushSyncOutcome>> call() async {
    if (!_gateway.isAvailable) return const Ok(PushSyncOutcome.unavailable);
    if (!await _gateway.requestPermission()) {
      return const Ok(PushSyncOutcome.permissionDenied);
    }
    final token = await _gateway.token();
    if (token == null) return const Ok(PushSyncOutcome.noToken);
    final result =
        await _repo.register(token: token, platform: _gateway.platform);
    return result.when(
      ok: (_) => const Ok(PushSyncOutcome.registered),
      err: (failure) => Err(failure),
    );
  }

  /// Token nuevo que entrega FCM al rotarlo.
  Future<Result<void>> refresh(String token) =>
      _repo.register(token: token, platform: _gateway.platform);
}

/// Antes de cerrar sesión: el teléfono deja de recibir alertas de la cuenta.
class UnregisterPushToken {
  const UnregisterPushToken(this._gateway, this._repo);
  final PushGateway _gateway;
  final PushTokensRepository _repo;

  Future<Result<void>> call() async {
    if (!_gateway.isAvailable) return const Ok<void>(null);
    final token = await _gateway.token();
    if (token == null) return const Ok<void>(null);
    return _repo.unregister(token);
  }
}
