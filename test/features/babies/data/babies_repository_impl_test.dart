import 'dart:io';

import 'package:colchon_minuta/core/errors/app_failure.dart';
import 'package:colchon_minuta/core/errors/result.dart';
import 'package:colchon_minuta/features/babies/data/babies_remote_source.dart';
import 'package:colchon_minuta/features/babies/data/babies_repository_impl.dart';
import 'package:colchon_minuta/features/babies/domain/baby.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeRemote implements BabiesRemoteSource {
  List<Map<String, dynamic>> rows = [];
  Object? error;
  Map<String, dynamic>? lastInsert;
  String? lastUpdateId;
  Map<String, dynamic>? lastChanges;
  String? lastDeleteId;
  String? lastWeighId;

  Map<String, dynamic> get _row => {
        'id': 'u1',
        'name': 'Emma',
        'birth': '2026-03-05',
        'weight': 5.84,
        'registered_at': '2026-03-06T10:00:00+00:00',
        'archived_at': null,
      };

  @override
  Future<List<Map<String, dynamic>>> fetchAll() async {
    if (error != null) throw error!;
    return rows;
  }

  @override
  Future<Map<String, dynamic>> insert(Map<String, dynamic> row) async {
    if (error != null) throw error!;
    lastInsert = row;
    return {..._row, ...row};
  }

  @override
  Future<Map<String, dynamic>> updateRow(
    String id,
    Map<String, dynamic> changes,
  ) async {
    if (error != null) throw error!;
    lastUpdateId = id;
    lastChanges = changes;
    return {..._row, ...changes};
  }

  @override
  Future<void> deleteRow(String id) async {
    if (error != null) throw error!;
    lastDeleteId = id;
  }

  @override
  Future<Map<String, dynamic>> weigh(String id) async {
    if (error != null) throw error!;
    lastWeighId = id;
    return {..._row, 'weight': '6.100'};
  }
}

AppFailure? _failure<T>(Result<T> r) =>
    r.when<AppFailure?>(ok: (_) => null, err: (f) => f);

void main() {
  late _FakeRemote remote;
  late BabiesRepositoryImpl repo;
  final fixedNow = DateTime.utc(2026, 11, 11, 15, 30);

  setUp(() {
    remote = _FakeRemote();
    repo = BabiesRepositoryImpl(remote, now: () => fixedNow);
  });

  test('list traduce filas (peso numérico o null, fecha sin hora)', () async {
    remote.rows = [
      {
        'id': 1,
        'name': 'Emma',
        'birth': '2026-03-05',
        'weight': 5.84,
        'registered_at': '2026-03-06T10:00:00+00:00',
        'archived_at': null,
      },
      {
        'id': 'abc',
        'name': 'Leo',
        'birth': '2025-12-31',
        'weight': null,
        'registered_at': '2026-03-07T10:00:00+00:00',
        'archived_at': '2026-05-01T00:00:00+00:00',
      },
    ];
    final babies = (await repo.list()).when(ok: (l) => l, err: (_) => null)!;
    expect(babies.map((b) => b.id), ['1', 'abc']);
    expect(babies[0].weightKg, 5.84);
    expect(babies[0].birth, DateTime(2026, 3, 5));
    expect(babies[0].isArchived, isFalse);
    expect(babies[1].weightKg, isNull);
    expect(babies[1].isArchived, isTrue);
  });

  test('create envía nombre y fecha, sin peso ni parent_id', () async {
    final r = await repo.create(
      BabyDraft(name: 'Emma', birth: DateTime(2026, 3, 5)),
    );
    expect(remote.lastInsert, {
      'name': 'Emma',
      'birth': '2026-03-05',
    });
    expect(remote.lastInsert!.containsKey('parent_id'), isFalse);
    expect(r.when(ok: (b) => b.name, err: (_) => null), 'Emma');
  });

  test('update modifica solo el perfil indicado', () async {
    await repo.update(
      'u1',
      BabyDraft(name: 'Leo', birth: DateTime(2026, 1, 9)),
    );
    expect(remote.lastUpdateId, 'u1');
    expect(remote.lastChanges, {
      'name': 'Leo',
      'birth': '2026-01-09',
    });
  });

  test('weigh llama a la RPC y devuelve el peso medido', () async {
    final r = await repo.weigh('u1');
    expect(remote.lastWeighId, 'u1');
    expect(r.when(ok: (b) => b.weightKg, err: (_) => null), 6.1);
  });

  test('archive guarda archived_at en UTC y restore lo pone en null', () async {
    final archived = await repo.archive('u1');
    expect(remote.lastChanges, {'archived_at': '2026-11-11T15:30:00.000Z'});
    expect(archived.when(ok: (b) => b.isArchived, err: (_) => false), isTrue);

    await repo.restore('u1');
    expect(remote.lastChanges, {'archived_at': null});
    expect(remote.lastChanges!.containsKey('archived_at'), isTrue);
  });

  test('delete borra por id', () async {
    await repo.delete('u1');
    expect(remote.lastDeleteId, 'u1');
  });

  group('errores', () {
    test('RLS → ForbiddenFailure', () async {
      remote.error = const PostgrestException(message: 'x', code: '42501');
      expect(_failure(await repo.list()), isA<ForbiddenFailure>());
    });

    test('sin filas → NotFoundFailure', () async {
      remote.error = const PostgrestException(message: 'x', code: 'PGRST116');
      expect(_failure(await repo.archive('u1')), isA<NotFoundFailure>());
    });

    test('errores de weigh_baby → MattressWeightFailure', () async {
      const cases = {
        'mattress_not_linked': MattressWeightProblem.notLinked,
        'mattress_offline': MattressWeightProblem.offline,
        'no_weight_reading': MattressWeightProblem.noReading,
      };
      for (final entry in cases.entries) {
        remote.error = PostgrestException(message: entry.key, code: 'P0001');
        final failure = _failure(await repo.weigh('u1'));
        expect(
          failure,
          isA<MattressWeightFailure>()
              .having((f) => f.problem, 'problem', entry.value),
        );
      }
    });

    test('sin red → NetworkFailure', () async {
      remote.error = const SocketException('sin red');
      expect(
        _failure(
          await repo.create(
            BabyDraft(name: 'a', birth: DateTime(2026, 1, 1)),
          ),
        ),
        isA<NetworkFailure>(),
      );
    });
  });
}
