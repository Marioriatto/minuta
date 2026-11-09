/// Errores de dominio. La capa de datos traduce excepciones técnicas a esto;
/// la presentación solo conoce estos tipos (y los muestra localizados).
sealed class AppFailure implements Exception {
  const AppFailure({this.cause});

  /// Excepción original, solo para logs; nunca se muestra al usuario.
  final Object? cause;
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure({super.cause});
}

final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure({super.cause});
}

/// Típicamente un rechazo por RLS.
final class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure({super.cause});
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure({super.cause});
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure({super.cause});
}

final class ServerFailure extends AppFailure {
  const ServerFailure({super.cause});
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure({super.cause});
}
