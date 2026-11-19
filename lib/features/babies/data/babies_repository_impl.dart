import '../../../core/errors/result.dart';
import '../../../core/errors/run_catching.dart';
import '../domain/babies_repository.dart';
import '../domain/baby.dart';
import 'babies_remote_source.dart';
import 'baby_mapper.dart';

class BabiesRepositoryImpl implements BabiesRepository {
  BabiesRepositoryImpl(this._remote, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final BabiesRemoteSource _remote;
  final DateTime Function() _now;

  @override
  Future<Result<List<Baby>>> list() => runCatching(() async {
        final rows = await _remote.fetchAll();
        return rows.map(BabyMapper.fromRow).toList();
      });

  @override
  Future<Result<Baby>> create(BabyDraft draft) => runCatching(
        () async => BabyMapper.fromRow(
          await _remote.insert(BabyMapper.toRow(draft)),
        ),
      );

  @override
  Future<Result<Baby>> update(String id, BabyDraft draft) => runCatching(
        () async => BabyMapper.fromRow(
          await _remote.updateRow(id, BabyMapper.toRow(draft)),
        ),
      );

  @override
  Future<Result<Baby>> archive(String id) => runCatching(
        () async => BabyMapper.fromRow(
          await _remote.updateRow(id, {
            'archived_at': _now().toUtc().toIso8601String(),
          }),
        ),
      );

  @override
  Future<Result<Baby>> restore(String id) => runCatching(
        () async => BabyMapper.fromRow(
          await _remote.updateRow(id, {'archived_at': null}),
        ),
      );

  @override
  Future<Result<Baby>> weigh(String id) => runCatching(
        () async => BabyMapper.fromRow(await _remote.weigh(id)),
      );

  @override
  Future<Result<void>> delete(String id) => runCatching<void>(() async {
        await _remote.deleteRow(id);
      });
}
