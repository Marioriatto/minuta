import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import 'babies_repository.dart';
import 'baby.dart';
import 'baby_validators.dart';

class ListBabies {
  const ListBabies(this._repository);
  final BabiesRepository _repository;

  Future<Result<List<Baby>>> call() => _repository.list();
}

class CreateBaby {
  CreateBaby(this._repository, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final BabiesRepository _repository;
  final DateTime Function() _now;

  Future<Result<Baby>> call({
    required String name,
    required DateTime? birth,
  }) async {
    final draft = BabyValidators.buildDraft(
      name: name,
      birth: birth,
      today: _now(),
    );
    if (draft == null) return const Err(ValidationFailure());
    return _repository.create(draft);
  }
}

class UpdateBaby {
  UpdateBaby(this._repository, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final BabiesRepository _repository;
  final DateTime Function() _now;

  Future<Result<Baby>> call({
    required String id,
    required String name,
    required DateTime? birth,
  }) async {
    final draft = BabyValidators.buildDraft(
      name: name,
      birth: birth,
      today: _now(),
    );
    if (draft == null) return const Err(ValidationFailure());
    return _repository.update(id, draft);
  }
}

/// No permite archivar el único perfil activo: la app siempre necesita uno
/// donde clasificar los datos (DB-001).
class ArchiveBaby {
  const ArchiveBaby(this._repository);
  final BabiesRepository _repository;

  Future<Result<Baby>> call({
    required String id,
    required List<Baby> current,
  }) async {
    final active = current.where((b) => !b.isArchived).toList();
    final isLastActive = active.length <= 1 && active.any((b) => b.id == id);
    if (isLastActive) return const Err(LastActiveProfileFailure());
    return _repository.archive(id);
  }
}

class RestoreBaby {
  const RestoreBaby(this._repository);
  final BabiesRepository _repository;

  Future<Result<Baby>> call(String id) => _repository.restore(id);
}

/// "Pesar ahora": el colchón mide y el servidor guarda el peso (RF-11).
/// Solo perfiles activos: un archivado no está en el colchón.
class WeighBaby {
  const WeighBaby(this._repository);
  final BabiesRepository _repository;

  Future<Result<Baby>> call(Baby baby) {
    if (baby.isArchived) return Future.value(const Err(ValidationFailure()));
    return _repository.weigh(baby.id);
  }
}

class DeleteBaby {
  const DeleteBaby(this._repository);
  final BabiesRepository _repository;

  Future<Result<void>> call(String id) => _repository.delete(id);
}
