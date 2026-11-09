import 'app_failure.dart';
import 'failure_mapper.dart';

/// Resultado explícito para repositorios: evita lanzar excepciones hacia el dominio.
sealed class Result<T> {
  const Result();

  R when<R>({
    required R Function(T value) ok,
    required R Function(AppFailure failure) err,
  }) =>
      switch (this) {
        Ok<T>(:final value) => ok(value),
        Err<T>(:final failure) => err(failure),
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final AppFailure failure;
}

/// Ejecuta [body] y convierte cualquier excepción en [Err].
Future<Result<T>> runCatching<T>(Future<T> Function() body) async {
  try {
    return Ok(await body());
  } on Object catch (e) {
    return Err(mapToFailure(e));
  }
}
