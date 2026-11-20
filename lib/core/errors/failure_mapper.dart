import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_failure.dart';

/// Traduce excepciones técnicas a [AppFailure]. Solo se usa en la capa de datos.
AppFailure mapToFailure(Object error) {
  if (error is AppFailure) return error;

  if (error is SocketException ||
      error is TimeoutException ||
      error is HandshakeException ||
      error is AuthRetryableFetchException) {
    return NetworkFailure(cause: error);
  }

  if (error is PostgrestException) {
    final code = error.code ?? '';
    // Errores de negocio que lanzan las funciones SQL con `raise exception`.
    if (error.message.contains('invalid_or_used_code')) {
      return InvalidDeviceCodeFailure(cause: error);
    }
    if (error.message.contains('device_not_found') ||
        error.message.contains('baby_not_found')) {
      return NotFoundFailure(cause: error);
    }
    // start_detection / stop_detection (migración detection_rpc).
    if (error.message.contains('detection_already_active') ||
        error.message.contains('detection_period_overlap')) {
      return DetectionFailure(DetectionProblem.alreadyActive, cause: error);
    }
    if (error.message.contains('no_active_detection')) {
      return DetectionFailure(DetectionProblem.notActive, cause: error);
    }
    final weighProblem = _weighProblem(error.message);
    if (weighProblem != null) {
      return MattressWeightFailure(weighProblem, cause: error);
    }
    if (code == '42501') {
      return ForbiddenFailure(cause: error); // RLS / permisos
    }
    if (code == 'PGRST301' || code == 'PGRST303') {
      return UnauthorizedFailure(cause: error); // JWT inválido o expirado
    }
    if (code == 'PGRST116') {
      return NotFoundFailure(cause: error);
    }
    if (code.startsWith('22') || code.startsWith('23')) {
      return ValidationFailure(cause: error); // datos / integridad
    }
    return ServerFailure(cause: error);
  }

  if (error is AuthException) return _mapAuth(error);

  return UnknownFailure(cause: error);
}

/// Errores de `weigh_baby` (ver la migración baby_weight_from_mattress).
MattressWeightProblem? _weighProblem(String message) {
  if (message.contains('mattress_not_linked')) {
    return MattressWeightProblem.notLinked;
  }
  if (message.contains('mattress_offline')) {
    return MattressWeightProblem.offline;
  }
  if (message.contains('no_weight_reading')) {
    return MattressWeightProblem.noReading;
  }
  return null;
}

AppFailure _mapAuth(AuthException error) {
  switch (error.code) {
    case 'invalid_credentials':
      return InvalidCredentialsFailure(cause: error);
    case 'email_not_confirmed':
      return EmailNotConfirmedFailure(cause: error);
    case 'user_already_exists':
    case 'email_exists':
      return EmailAlreadyRegisteredFailure(cause: error);
    case 'weak_password':
      return WeakPasswordFailure(cause: error);
    case 'over_request_rate_limit':
    case 'over_email_send_rate_limit':
      return RateLimitedFailure(cause: error);
  }

  // Respaldo para versiones del servidor/SDK que no envían `code`.
  final message = error.message.toLowerCase();
  if (message.contains('invalid login credentials')) {
    return InvalidCredentialsFailure(cause: error);
  }
  if (message.contains('email not confirmed')) {
    return EmailNotConfirmedFailure(cause: error);
  }
  if (message.contains('already registered')) {
    return EmailAlreadyRegisteredFailure(cause: error);
  }

  final status = error.statusCode;
  if (status == '400' || status == '422') {
    return ValidationFailure(cause: error);
  }
  if (status == '429') return RateLimitedFailure(cause: error);
  return UnauthorizedFailure(cause: error);
}
