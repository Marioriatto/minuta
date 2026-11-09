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
    if (code == '42501') return ForbiddenFailure(cause: error); // RLS / permisos
    if (code == 'PGRST301' || code == 'PGRST303') {
      return UnauthorizedFailure(cause: error); // JWT inválido o expirado
    }
    if (code == 'PGRST116') return NotFoundFailure(cause: error);
    if (code.startsWith('22') || code.startsWith('23')) {
      return ValidationFailure(cause: error); // datos / integridad
    }
    return ServerFailure(cause: error);
  }

  if (error is AuthException) {
    final status = error.statusCode;
    if (status == '400' || status == '422') {
      return ValidationFailure(cause: error);
    }
    return UnauthorizedFailure(cause: error);
  }

  return UnknownFailure(cause: error);
}
