import 'package:colchon_minuta/core/errors/app_failure.dart';
import 'package:colchon_minuta/core/errors/result.dart';
import 'package:colchon_minuta/features/babies/babies_providers.dart';
import 'package:colchon_minuta/features/babies/domain/active_baby_store.dart';
import 'package:colchon_minuta/features/babies/domain/babies_repository.dart';
import 'package:colchon_minuta/features/babies/domain/baby.dart';

Baby makeBaby({
  String id = 'b1',
  String name = 'Emma',
  DateTime? birth,
  double? weightKg = 5.84,
  DateTime? registeredAt,
  DateTime? archivedAt,
}) =>
    Baby(
      id: id,
      name: name,
      birth: birth ?? DateTime(2026, 3, 5),
      weightKg: weightKg,
      registeredAt: registeredAt ?? DateTime(2026, 3, 6),
      archivedAt: archivedAt,
    );

/// Repositorio en memoria. Con [failWith] todas las operaciones fallan.
class FakeBabiesRepository implements BabiesRepository {
  FakeBabiesRepository([List<Baby>? initial]) : store = [...?initial];

  final List<Baby> store;
  AppFailure? failWith;
  final calls = <String>[];

  Baby _replace(String id, Baby Function(Baby) change) {
    final i = store.indexWhere((b) => b.id == id);
    store[i] = change(store[i]);
    return store[i];
  }

  Baby _from(
    Baby b, {
    DateTime? archivedAt,
    bool keepArchive = true,
    double? weightKg,
  }) =>
      Baby(
        id: b.id,
        name: b.name,
        birth: b.birth,
        weightKg: weightKg ?? b.weightKg,
        registeredAt: b.registeredAt,
        archivedAt: keepArchive ? (archivedAt ?? b.archivedAt) : archivedAt,
      );

  @override
  Future<Result<List<Baby>>> list() async {
    calls.add('list');
    if (failWith != null) return Err(failWith!);
    return Ok([...store]);
  }

  @override
  Future<Result<Baby>> create(BabyDraft draft) async {
    calls.add('create:${draft.name}');
    if (failWith != null) return Err(failWith!);
    final baby = Baby(
      id: 'new${store.length + 1}',
      name: draft.name,
      birth: draft.birth,
      registeredAt: DateTime(2026, 6, store.length + 1),
    );
    store.add(baby);
    return Ok(baby);
  }

  @override
  Future<Result<Baby>> update(String id, BabyDraft draft) async {
    calls.add('update:$id');
    if (failWith != null) return Err(failWith!);
    return Ok(
      _replace(
        id,
        (b) => Baby(
          id: b.id,
          name: draft.name,
          birth: draft.birth,
          weightKg: b.weightKg,
          registeredAt: b.registeredAt,
          archivedAt: b.archivedAt,
        ),
      ),
    );
  }

  @override
  Future<Result<Baby>> archive(String id) async {
    calls.add('archive:$id');
    if (failWith != null) return Err(failWith!);
    return Ok(_replace(id, (b) => _from(b, archivedAt: DateTime(2026, 7, 1))));
  }

  @override
  Future<Result<Baby>> restore(String id) async {
    calls.add('restore:$id');
    if (failWith != null) return Err(failWith!);
    return Ok(_replace(id, (b) => _from(b, keepArchive: false)));
  }

  /// Peso que "mide" el colchón falso en [weigh].
  double weighReading = 6.1;

  @override
  Future<Result<Baby>> weigh(String id) async {
    calls.add('weigh:$id');
    if (failWith != null) return Err(failWith!);
    return Ok(_replace(id, (b) => _from(b, weightKg: weighReading)));
  }

  @override
  Future<Result<void>> delete(String id) async {
    calls.add('delete:$id');
    if (failWith != null) return Err(failWith!);
    store.removeWhere((b) => b.id == id);
    return const Ok<void>(null);
  }
}

class FakeActiveBabyStore implements ActiveBabyStore {
  final data = <String, String?>{};

  @override
  Future<String?> read(String userId) async => data[userId];

  @override
  Future<void> write(String userId, String? babyId) async =>
      data[userId] = babyId;
}

/// Notifier de perfiles con datos fijos (o un error) para pruebas de UI/gate.
class FakeBabiesNotifier extends BabiesNotifier {
  FakeBabiesNotifier(this.items, {this.error});

  final List<Baby> items;
  final AppFailure? error;

  @override
  Future<List<Baby>> build() async {
    if (error != null) throw error!;
    return items;
  }
}

class FakeActiveBabyIdNotifier extends ActiveBabyIdNotifier {
  FakeActiveBabyIdNotifier(this.id);

  final String? id;

  @override
  Future<String?> build() async => id;
}
