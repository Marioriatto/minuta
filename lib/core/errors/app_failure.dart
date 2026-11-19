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

/// Correo o contraseña incorrectos al iniciar sesión.
final class InvalidCredentialsFailure extends AppFailure {
  const InvalidCredentialsFailure({super.cause});
}

final class EmailNotConfirmedFailure extends AppFailure {
  const EmailNotConfirmedFailure({super.cause});
}

final class EmailAlreadyRegisteredFailure extends AppFailure {
  const EmailAlreadyRegisteredFailure({super.cause});
}

final class WeakPasswordFailure extends AppFailure {
  const WeakPasswordFailure({super.cause});
}

final class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure({super.cause});
}

/// Se intentó archivar el único perfil activo.
final class LastActiveProfileFailure extends AppFailure {
  const LastActiveProfileFailure({super.cause});
}

/// Código de vinculación inexistente o ya usado (RF-06).
final class InvalidDeviceCodeFailure extends AppFailure {
  const InvalidDeviceCodeFailure({super.cause});
}

enum MattressWeightProblem {
  /// No hay colchón vinculado a la cuenta.
  notLinked,

  /// El colchón no ha reportado en los últimos 30 s.
  offline,

  /// El colchón está vacío o la lectura no es válida.
  noReading,
}

/// "Pesar ahora" no pudo tomar el peso del colchón (RF-11).
final class MattressWeightFailure extends AppFailure {
  const MattressWeightFailure(this.problem, {super.cause});
  final MattressWeightProblem problem;
}

/// Envuelve cualquier error inesperado en un [UnknownFailure] sin depender de
/// ninguna librería externa (usable desde el dominio).
abstract final class UnknownFailureFor {
  static AppFailure wrap(Object error) =>
      error is AppFailure ? error : UnknownFailure(cause: error);
}
