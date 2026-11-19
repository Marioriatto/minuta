import '../../../core/errors/result.dart';
import 'baby.dart';

abstract interface class BabiesRepository {
  /// Perfiles del usuario (activos y archivados), del más antiguo al más nuevo.
  Future<Result<List<Baby>>> list();

  Future<Result<Baby>> create(BabyDraft draft);

  Future<Result<Baby>> update(String id, BabyDraft draft);

  Future<Result<Baby>> archive(String id);

  Future<Result<Baby>> restore(String id);

  /// Borrado definitivo: elimina también el historial (cascada en la base).
  Future<Result<void>> delete(String id);

  /// Guarda en el perfil el peso que mide ahora el colchón (RF-11).
  /// Falla con `MattressWeightFailure` si el colchón no puede pesar.
  Future<Result<Baby>> weigh(String id);
}
