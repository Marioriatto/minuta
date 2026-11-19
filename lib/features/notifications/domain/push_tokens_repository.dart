import '../../../core/errors/result.dart';

abstract interface class PushTokensRepository {
  /// Asocia el token del teléfono al usuario actual (RF-03).
  Future<Result<void>> register({
    required String token,
    required String platform,
  });

  /// Lo desasocia (al cerrar sesión) para no recibir alertas de otra cuenta.
  Future<Result<void>> unregister(String token);
}
