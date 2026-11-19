/// Plataforma de mensajería push del teléfono (FCM en Android). Aislada para
/// que el dominio y los tests no dependan de Firebase.
abstract interface class PushGateway {
  /// `false` si el teléfono no tiene push configurado (p. ej. sin
  /// google-services.json): la app sigue funcionando sin notificaciones.
  bool get isAvailable;

  /// 'android' o 'ios'.
  String get platform;

  /// Pide permiso para mostrar notificaciones. `true` si lo concedió.
  Future<bool> requestPermission();

  /// Token del dispositivo, o null si aún no hay.
  Future<String?> token();

  /// Nuevos tokens cuando FCM los rota.
  Stream<String> get tokenRefreshes;

  /// Se emite cuando el usuario toca una notificación de alerta (con la app
  /// abierta, en segundo plano o al arrancarla desde la notificación).
  Stream<void> get alertOpened;
}

/// Sin push: se usa si Firebase no está configurado y en los tests.
class NoPushGateway implements PushGateway {
  const NoPushGateway();

  @override
  bool get isAvailable => false;

  @override
  String get platform => 'android';

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<String?> token() async => null;

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();

  @override
  Stream<void> get alertOpened => const Stream.empty();
}
