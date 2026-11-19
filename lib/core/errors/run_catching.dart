import 'failure_mapper.dart';
import 'result.dart';

/// Ejecuta [body] y convierte cualquier excepción en [Err]. Solo para la capa
/// de datos (depende del mapeo de excepciones de Supabase).
Future<Result<T>> runCatching<T>(Future<T> Function() body) async {
  try {
    return Ok(await body());
  } on Object catch (e) {
    return Err(mapToFailure(e));
  }
}
