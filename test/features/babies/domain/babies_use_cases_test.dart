import 'package:colchon_minuta/core/errors/app_failure.dart';
import 'package:colchon_minuta/core/errors/result.dart';
import 'package:colchon_minuta/features/babies/domain/babies_use_cases.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_babies.dart';

AppFailure? _failure<T>(Result<T> r) =>
    r.when<AppFailure?>(ok: (_) => null, err: (f) => f);

void main() {
  late FakeBabiesRepository repo;
  final fixedNow = DateTime(2026, 11, 11);
  setUp(() => repo = FakeBabiesRepository());

  group('CreateBaby', () {
    test('datos inválidos no llegan al repositorio', () async {
      final r = await CreateBaby(repo, now: () => fixedNow)(
        name: '',
        birth: DateTime(2026, 3, 5),
      );
      expect(_failure(r), isA<ValidationFailure>());
      expect(repo.calls, isEmpty);
    });

    test('fecha futura respecto al reloj inyectado es inválida', () async {
      final r = await CreateBaby(repo, now: () => fixedNow)(
        name: 'Emma',
        birth: DateTime(2026, 12, 1),
      );
      expect(_failure(r), isA<ValidationFailure>());
    });

    test('guarda el borrador normalizado', () async {
      final r = await CreateBaby(repo, now: () => fixedNow)(
        name: '  Emma ',
        birth: DateTime(2026, 3, 5),
      );
      final baby = r.when(ok: (b) => b, err: (_) => null)!;
      expect(baby.name, 'Emma');
      expect(baby.weightKg, isNull, reason: 'el peso lo pone el colchón');
      expect(repo.calls, ['create:Emma']);
    });
  });

  test('UpdateBaby valida antes de modificar', () async {
    repo = FakeBabiesRepository([makeBaby()]);
    final useCase = UpdateBaby(repo, now: () => fixedNow);
    expect(
      _failure(
        await useCase(
          id: 'b1',
          name: 'Emma',
          birth: null,
        ),
      ),
      isA<ValidationFailure>(),
    );
    expect(repo.calls, isEmpty);

    final ok = await useCase(
      id: 'b1',
      name: 'Emma Sofía',
      birth: DateTime(2026, 3, 5),
    );
    expect(ok.when(ok: (b) => b.name, err: (_) => null), 'Emma Sofía');
  });

  group('ArchiveBaby', () {
    test('no permite archivar el único perfil activo', () async {
      final only = makeBaby();
      repo = FakeBabiesRepository([only]);
      final r = await ArchiveBaby(repo)(id: 'b1', current: [only]);
      expect(_failure(r), isA<LastActiveProfileFailure>());
      expect(repo.calls, isEmpty);
    });

    test('archiva si queda otro perfil activo', () async {
      final a = makeBaby(id: 'a');
      final b = makeBaby(id: 'b', name: 'Leo');
      repo = FakeBabiesRepository([a, b]);
      final r = await ArchiveBaby(repo)(id: 'a', current: [a, b]);
      expect(r.when(ok: (x) => x.isArchived, err: (_) => false), isTrue);
    });

    test('los perfiles ya archivados no cuentan como activos', () async {
      final active = makeBaby(id: 'a');
      final archived = makeBaby(id: 'z', archivedAt: DateTime(2026, 5, 1));
      repo = FakeBabiesRepository([active, archived]);
      final r = await ArchiveBaby(repo)(id: 'a', current: [active, archived]);
      expect(_failure(r), isA<LastActiveProfileFailure>());
    });
  });

  group('WeighBaby', () {
    test('guarda el peso que mide el colchón', () async {
      final baby = makeBaby(weightKg: null);
      repo = FakeBabiesRepository([baby])..weighReading = 6.1;
      final r = await WeighBaby(repo)(baby);
      expect(r.when(ok: (b) => b.weightKg, err: (_) => null), 6.1);
      expect(repo.calls, ['weigh:b1']);
    });

    test('un perfil archivado no se pesa', () async {
      final archived = makeBaby(archivedAt: DateTime(2026, 5, 1));
      repo = FakeBabiesRepository([archived]);
      final r = await WeighBaby(repo)(archived);
      expect(_failure(r), isA<ValidationFailure>());
      expect(repo.calls, isEmpty);
    });

    test('propaga el motivo si el colchón no puede pesar', () async {
      final baby = makeBaby();
      repo = FakeBabiesRepository([baby])
        ..failWith = const MattressWeightFailure(MattressWeightProblem.offline);
      final r = await WeighBaby(repo)(baby);
      expect(_failure(r), isA<MattressWeightFailure>());
    });
  });

  test('restaurar y eliminar delegan en el repositorio', () async {
    final archived = makeBaby(archivedAt: DateTime(2026, 5, 1));
    repo = FakeBabiesRepository([archived]);
    final restored = await RestoreBaby(repo)('b1');
    expect(restored.when(ok: (b) => b.isArchived, err: (_) => true), isFalse);
    await DeleteBaby(repo)('b1');
    expect(repo.store, isEmpty);
  });
}
