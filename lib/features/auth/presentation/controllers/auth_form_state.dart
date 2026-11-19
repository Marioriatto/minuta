import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/auth_validators.dart';

/// Estado común de los formularios de cuenta.
@immutable
class AuthFormState {
  const AuthFormState({
    this.busy = false,
    this.emailError,
    this.passwordError,
    this.confirmError,
    this.failure,
    this.completed = false,
  });

  final bool busy;
  final FieldError? emailError;
  final FieldError? passwordError;
  final FieldError? confirmError;
  final AppFailure? failure;

  /// La operación terminó bien (la pantalla decide qué mostrar o a dónde ir).
  final bool completed;
}
