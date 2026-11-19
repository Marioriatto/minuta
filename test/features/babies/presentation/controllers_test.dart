import 'package:colchon_minuta/core/errors/app_failure.dart';
import 'package:colchon_minuta/features/auth/auth_providers.dart';
import 'package:colchon_minuta/features/auth/domain/auth_snapshot.dart';
import 'package:colchon_minuta/features/auth/domain/auth_user.dart';
import 'package:colchon_minuta/features/babies/babies_providers.dart';
import 'package:colchon_minuta/features/babies/domain/baby_validators.dart';
import 'package:colchon_minuta/features/babies/presentation/controllers/babies_actions_controller.dart';
import 'package:colchon_minuta/features/babies/presentation/controllers/baby_form_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_babies.dart';

Future<ProviderContainer> _container(
  FakeBabiesRepository repo,
  FakeActiveBabyStore store,
) async {
  final container = ProviderContainer(
    overrides: [
      babiesRepositoryProvider.overrideWithValue(repo),
      activeBabyStoreProvider.overrideWithValue(store),
      authSnapshotProvider.overrideWith(
        (ref) => Stream.value(
          const AuthSnapshot(
            AuthEvent.signedIn,
            AuthUser(id: 'u1', email: 'a@b.co'),
          ),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(authSnapshotProvider.future);
  await container.read(babiesProvider.future);
  return container;
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  late FakeActiveBabyStore store;
  setUp(() => store = FakeActiveBabyStore());

  group('BabyFormController', () {
    test('errores por campo sin llamar al repositorio', () async {
      final repo = FakeBabiesRepository();
      final c = await _container(repo, store);
      await c.read(babyFormControllerProvider.notifier).submit(
            name: '',
            birth: null,
          );
      final s = c.read(babyFormControllerProvider);
      expect(s.nameError, BabyFieldError.nameEmpty);
      expect(s.birthError, BabyFieldError.birthMissing);
      expect(repo.calls, ['list']);
    });

    test('primer perfil: se agrega y queda como activo', () async {
      final repo = FakeBabiesRepository();
      final c = await _container(repo, store);
      await c.read(babyFormControllerProvider.notifier).submit(
            name: 'Emma',
            birth: DateTime(2026, 3, 5),
          );
      await _settle();

      expect(c.read(babyFormControllerProvider).completed, isTrue);
      expect(c.read(activeBabiesProvider).map((b) => b.name), ['Emma']);
      expect(store.data['u1'], c.read(activeBabyProvider)!.id);
    });

    test('un segundo perfil no cambia el activo', () async {
      final repo = FakeBabiesRepository([makeBaby()]);
      final c = await _container(repo, store);
      await c.read(babyFormControllerProvider.notifier).submit(
            name: 'Leo',
            birth: DateTime(2026, 4, 1),
          );
      await _settle();

      expect(c.read(activeBabiesProvider), hasLength(2));
      expect(c.read(activeBabyProvider)!.id, 'b1');
      expect(store.data.containsKey('u1'), isFalse);
    });

    test('editar reemplaza el perfil en la lista', () async {
      final repo = FakeBabiesRepository([makeBaby()]);
      final c = await _container(repo, store);
      await c.read(babyFormControllerProvider.notifier).submit(
            babyId: 'b1',
            name: 'Emma Sofía',
            birth: DateTime(2026, 3, 5),
          );
      final babies = c.read(babiesProvider).value!;
      expect(babies, hasLength(1));
      expect(babies.single.name, 'Emma Sofía');
    });

    test('un error del servidor se muestra y no completa', () async {
      final repo = FakeBabiesRepository();
      final c = await _container(repo, store);
      repo.failWith = const ForbiddenFailure();
      await c.read(babyFormControllerProvider.notifier).submit(
            name: 'Emma',
            birth: DateTime(2026, 3, 5),
          );
      final s = c.read(babyFormControllerProvider);
      expect(s.failure, isA<ForbiddenFailure>());
      expect(s.completed, isFalse);
      expect(c.read(babiesProvider).value, isEmpty);
    });
  });

  group('BabiesActionsController', () {
    final a = makeBaby(id: 'a', registeredAt: DateTime(2026, 1, 1));
    final b =
        makeBaby(id: 'b', name: 'Leo', registeredAt: DateTime(2026, 2, 1));

    test('archivar con dos activos: queda archivado y avisa', () async {
      final c = await _container(FakeBabiesRepository([a, b]), store);
      await c.read(babiesActionsControllerProvider.notifier).archive(a);

      expect(c.read(babiesActionsControllerProvider).done, BabyAction.archived);
      expect(c.read(activeBabiesProvider).map((x) => x.id), ['b']);
      expect(c.read(archivedBabiesProvider).map((x) => x.id), ['a']);
      // El activo pasó al siguiente perfil disponible.
      expect(c.read(activeBabyProvider)!.id, 'b');
    });

    test('no deja archivar el último perfil activo', () async {
      final c = await _container(FakeBabiesRepository([a]), store);
      await c.read(babiesActionsControllerProvider.notifier).archive(a);

      expect(
        c.read(babiesActionsControllerProvider).failure,
        isA<LastActiveProfileFailure>(),
      );
      expect(c.read(activeBabiesProvider), hasLength(1));
    });

    test('restaurar y eliminar definitivamente', () async {
      final archived = makeBaby(id: 'z', archivedAt: DateTime(2026, 5, 1));
      final c = await _container(FakeBabiesRepository([a, archived]), store);
      final actions = c.read(babiesActionsControllerProvider.notifier);

      await actions.restore(archived);
      expect(c.read(activeBabiesProvider).map((x) => x.id), ['a', 'z']);

      await actions.delete(archived);
      expect(c.read(babiesActionsControllerProvider).done, BabyAction.deleted);
      expect(c.read(babiesProvider).value!.map((x) => x.id), ['a']);
    });

    test('elegir perfil activo se guarda en el teléfono', () async {
      final c = await _container(FakeBabiesRepository([a, b]), store);
      expect(c.read(activeBabyProvider)!.id, 'a');

      await c.read(babiesActionsControllerProvider.notifier).setActive(b);

      expect(store.data['u1'], 'b');
      expect(c.read(activeBabyProvider)!.id, 'b');
    });

    test('pesar ahora actualiza el peso y avisa', () async {
      final unweighed = makeBaby(id: 'a', weightKg: null);
      final repo = FakeBabiesRepository([unweighed])..weighReading = 6.1;
      final c = await _container(repo, store);
      await c.read(babiesActionsControllerProvider.notifier).weigh(unweighed);

      expect(c.read(babiesActionsControllerProvider).done, BabyAction.weighed);
      expect(c.read(babiesProvider).value!.single.weightKg, 6.1);
    });

    test('pesar con el colchón fuera de línea muestra el motivo', () async {
      final repo = FakeBabiesRepository([a]);
      final c = await _container(repo, store);
      repo.failWith =
          const MattressWeightFailure(MattressWeightProblem.offline);
      await c.read(babiesActionsControllerProvider.notifier).weigh(a);

      expect(
        c.read(babiesActionsControllerProvider).failure,
        isA<MattressWeightFailure>(),
      );
      expect(c.read(babiesProvider).value!.single.weightKg, 5.84);
    });

    test('un error al archivar no cambia la lista', () async {
      final repo = FakeBabiesRepository([a, b]);
      final c = await _container(repo, store);
      repo.failWith = const NetworkFailure();
      await c.read(babiesActionsControllerProvider.notifier).archive(a);

      expect(
        c.read(babiesActionsControllerProvider).failure,
        isA<NetworkFailure>(),
      );
      expect(c.read(activeBabiesProvider), hasLength(2));
    });
  });
}
