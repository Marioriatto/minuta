import 'dart:async';

import 'package:colchon_minuta/core/errors/app_failure.dart';
import 'package:colchon_minuta/core/errors/result.dart';
import 'package:colchon_minuta/features/auth/auth_providers.dart';
import 'package:colchon_minuta/features/auth/domain/auth_snapshot.dart';
import 'package:colchon_minuta/features/auth/domain/auth_user.dart';
import 'package:colchon_minuta/features/babies/babies_providers.dart';
import 'package:colchon_minuta/features/babies/domain/baby.dart';
import 'package:colchon_minuta/features/detection/data/detection_remote_source.dart';
import 'package:colchon_minuta/features/detection/data/detection_repository_impl.dart';
import 'package:colchon_minuta/features/detection/detection_providers.dart';
import 'package:colchon_minuta/features/detection/domain/detection_period.dart';
import 'package:colchon_minuta/features/detection/domain/detection_repository.dart';
import 'package:colchon_minuta/features/detection/domain/detection_use_cases.dart';
import 'package:colchon_minuta/features/detection/presentation/detection_controller.dart';
import 'package:colchon_minuta/features/devices/devices_providers.dart';
import 'package:colchon_minuta/features/devices/domain/device.dart';
import 'package:colchon_minuta/features/mattress/presentation/mattress_page.dart';
import 'package:colchon_minuta/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_babies.dart';
import '../../support/fake_devices.dart';

final _now = DateTime.utc(2026, 11, 19, 21, 40);

DetectionPeriod period({
  String id = 'p1',
  DateTime? startsAt,
  DateTime? endsAt,
}) =>
    DetectionPeriod(
      id: id,
      babyId: 'b1',
      deviceId: 'm1',
      startsAt: startsAt ?? _now.subtract(const Duration(minutes: 5)),
      endsAt: endsAt,
    );

Device mattress({DateTime? lastSeenAt}) => makeDevice(
      id: 'm1',
      kind: DeviceKind.mattress,
      name: null,
      reportedState: const {'weight_kg': 5.84},
      lastSeenAt: lastSeenAt ?? _now.subtract(const Duration(seconds: 5)),
    );

class FakeDetectionRepository implements DetectionRepository {
  FakeDetectionRepository([List<DetectionPeriod>? initial])
      : store = [...?initial];

  final List<DetectionPeriod> store;
  final calls = <String>[];
  AppFailure? failWith;

  @override
  Future<Result<List<DetectionPeriod>>> list() async =>
      failWith != null ? Err(failWith!) : Ok([...store]);

  @override
  Stream<List<DetectionPeriod>> watch() => const Stream.empty();

  @override
  Future<Result<DetectionPeriod>> start({
    required String deviceId,
    required String babyId,
    int? minutes,
  }) async {
    calls.add('start:$deviceId:$babyId:$minutes');
    if (failWith != null) return Err(failWith!);
    final p = period(
      id: 'new',
      startsAt: _now,
      endsAt: minutes == null ? null : _now.add(Duration(minutes: minutes)),
    );
    store.add(p);
    return Ok(p);
  }

  @override
  Future<Result<DetectionPeriod>> stop() async {
    calls.add('stop');
    if (failWith != null) return Err(failWith!);
    final i = store.indexWhere((p) => p.isActive(_now));
    final closed = DetectionPeriod(
      id: store[i].id,
      babyId: store[i].babyId,
      deviceId: store[i].deviceId,
      startsAt: store[i].startsAt,
      endsAt: _now,
    );
    store[i] = closed;
    return Ok(closed);
  }
}

class _FakeRemote implements DetectionRemoteSource {
  final calls = <String>[];

  @override
  Future<List<Map<String, dynamic>>> fetch({required int limit}) async => [
        {
          'id': 'aa',
          'baby_id': 'b1',
          'device_id': 'm1',
          'starts_at': '2026-11-19T21:00:00+00:00',
          'ends_at': null,
        },
        {
          'id': 'bb',
          'baby_id': null,
          'device_id': null,
          'starts_at': '2026-11-18T21:00:00+00:00',
          'ends_at': '2026-11-18T23:00:00+00:00',
        },
      ];

  @override
  Stream<List<Map<String, dynamic>>> stream({required int limit}) =>
      const Stream.empty();

  @override
  Future<Map<String, dynamic>> start({
    required String deviceId,
    required String babyId,
    int? minutes,
  }) async {
    calls.add('start:$minutes');
    return {
      'id': 'cc',
      'baby_id': babyId,
      'device_id': deviceId,
      'starts_at': '2026-11-19T21:40:00+00:00',
      'ends_at': '2026-11-19T22:40:00+00:00',
    };
  }

  @override
  Future<Map<String, dynamic>> stop() async => throw const NetworkFailure();
}

class _Devices extends DevicesNotifier {
  _Devices(this.items);
  final List<Device> items;

  @override
  Future<List<Device>> build() async => items;
}

List<Override> _overrides(
  FakeDetectionRepository repo, {
  List<Device>? devices,
  List<Baby>? babies,
}) =>
    [
      detectionRepositoryProvider.overrideWithValue(repo),
      authSnapshotProvider.overrideWith(
        (ref) => Stream.value(
          const AuthSnapshot(AuthEvent.signedIn, AuthUser(id: 'u1')),
        ),
      ),
      nowProvider.overrideWith((ref) => Stream.value(_now)),
      devicesProvider.overrideWith(() => _Devices(devices ?? [mattress()])),
      babiesProvider
          .overrideWith(() => FakeBabiesNotifier(babies ?? [makeBaby()])),
      activeBabyIdProvider.overrideWith(() => FakeActiveBabyIdNotifier('b1')),
    ];

Future<ProviderContainer> _container(
  FakeDetectionRepository repo, {
  List<Baby>? babies,
}) async {
  final c = ProviderContainer(overrides: _overrides(repo, babies: babies));
  addTearDown(c.dispose);
  await c.read(authSnapshotProvider.future);
  await c.read(nowProvider.future);
  await c.read(babiesProvider.future);
  await c.read(activeBabyIdProvider.future);
  await c.read(detectionPeriodsProvider.future);
  return c;
}

void main() {
  group('dominio', () {
    test('vigencia: sin límite, con límite y vencido', () {
      expect(period().isActive(_now), isTrue);
      expect(period().hasLimit, isFalse);
      expect(
        period(endsAt: _now.add(const Duration(hours: 1))).isActive(_now),
        isTrue,
      );
      expect(period(endsAt: _now).isActive(_now), isFalse);
      expect(
        period(startsAt: _now.add(const Duration(minutes: 1))).isActive(_now),
        isFalse,
      );
    });

    test('activeOf elige el vigente más reciente', () {
      final old = period(
        id: 'old',
        startsAt: _now.subtract(const Duration(days: 1)),
        endsAt: _now.subtract(const Duration(hours: 20)),
      );
      final a =
          period(id: 'a', startsAt: _now.subtract(const Duration(hours: 2)));
      final b =
          period(id: 'b', startsAt: _now.subtract(const Duration(hours: 1)));
      expect(DetectionRules.activeOf([old, a, b], _now)?.id, 'b');
      expect(DetectionRules.activeOf([old], _now), isNull);
    });

    test('las duraciones caben en el máximo del servidor', () {
      for (final d in DetectionDuration.values) {
        final m = d.minutes;
        if (m != null) expect(m, lessThanOrEqualTo(DetectionRules.maxMinutes));
      }
      expect(DetectionDuration.unlimited.minutes, isNull);
    });

    test('iniciar exige colchón y bebé activo, sin llamar al servidor',
        () async {
      final repo = FakeDetectionRepository();
      final start = StartDetection(repo);

      final noMattress = await start(
        mattress: makeDevice(kind: DeviceKind.cradle),
        baby: makeBaby(),
        duration: DetectionDuration.unlimited,
      );
      expect(
        noMattress.when(ok: (_) => null, err: (f) => f),
        isA<MattressWeightFailure>(),
      );

      final noBaby = await start(
        mattress: mattress(),
        baby: null,
        duration: DetectionDuration.unlimited,
      );
      expect(
        noBaby.when(ok: (_) => null, err: (f) => f),
        isA<DetectionFailure>().having(
          (f) => f.problem,
          'problem',
          DetectionProblem.noActiveBaby,
        ),
      );
      expect(repo.calls, isEmpty);

      await start(
        mattress: mattress(),
        baby: makeBaby(),
        duration: DetectionDuration.twoHours,
      );
      expect(repo.calls, ['start:m1:b1:120']);
    });
  });

  group('datos', () {
    test('mapea filas (con y sin fin) y propaga errores', () async {
      final remote = _FakeRemote();
      final repo = DetectionRepositoryImpl(remote);

      final list = (await repo.list()).when(ok: (l) => l, err: (_) => null)!;
      expect(list.first.endsAt, isNull);
      expect(list.first.startsAt, DateTime.utc(2026, 11, 19, 21));
      expect(list.last.babyId, isNull);
      expect(list.last.endsAt, DateTime.utc(2026, 11, 18, 23));

      final started =
          await repo.start(deviceId: 'm1', babyId: 'b1', minutes: 60);
      expect(started.when(ok: (p) => p.hasLimit, err: (_) => null), isTrue);
      expect(remote.calls, ['start:60']);

      final stopped = await repo.stop();
      expect(
        stopped.when(ok: (_) => null, err: (f) => f),
        isA<NetworkFailure>(),
      );
    });
  });

  group('controlador', () {
    test('inicia con el bebé activo y se ve vigente', () async {
      final repo = FakeDetectionRepository();
      final c = await _container(repo);
      expect(c.read(activeDetectionProvider), isNull);

      await c
          .read(detectionControllerProvider.notifier)
          .start(mattress(), DetectionDuration.oneHour);
      expect(repo.calls, ['start:m1:b1:60']);
      expect(
        c.read(detectionControllerProvider).done,
        DetectionActionDone.started,
      );
      expect(c.read(activeDetectionProvider)?.id, 'new');
    });

    test('detiene el vigente', () async {
      final repo = FakeDetectionRepository([period()]);
      final c = await _container(repo);
      expect(c.read(activeDetectionProvider), isNotNull);

      await c.read(detectionControllerProvider.notifier).stop();
      expect(
        c.read(detectionControllerProvider).done,
        DetectionActionDone.stopped,
      );
      expect(c.read(activeDetectionProvider), isNull);
    });

    test('un fallo del servidor queda en el estado', () async {
      final repo = FakeDetectionRepository();
      final c = await _container(repo);
      repo.failWith = const DetectionFailure(DetectionProblem.alreadyActive);
      await c
          .read(detectionControllerProvider.notifier)
          .start(mattress(), DetectionDuration.unlimited);
      final s = c.read(detectionControllerProvider);
      expect(s.failure, isA<DetectionFailure>());
      expect(s.busy, isFalse);
    });
  });

  group('pantalla del colchón', () {
    Widget host(
      FakeDetectionRepository repo, {
      List<Device>? devices,
      List<Baby>? babies,
    }) =>
        ProviderScope(
          overrides: _overrides(repo, devices: devices, babies: babies),
          child: const MaterialApp(
            locale: Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MattressPage(deviceId: 'm1'),
          ),
        );

    testWidgets('sin detección: peso, duraciones e iniciar', (tester) async {
      final repo = FakeDetectionRepository();
      await tester.pumpWidget(host(repo));
      await tester.pumpAndSettle();

      // Mismo formato que Inicio: un decimal.
      expect(find.text('5,8 kg'), findsOneWidget);
      expect(find.text('Detección detenida'), findsOneWidget);
      expect(find.textContaining('Emma'), findsOneWidget);

      await tester.tap(find.text('2 horas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar detección'));
      await tester.pumpAndSettle();

      expect(repo.calls, ['start:m1:b1:120']);
      expect(find.text('Detección activa'), findsOneWidget);
      expect(find.text('Detener detección'), findsOneWidget);
    });

    testWidgets('con detección activa: detener', (tester) async {
      final repo = FakeDetectionRepository([period()]);
      await tester.pumpWidget(host(repo));
      await tester.pumpAndSettle();

      expect(find.textContaining('sin límite de tiempo'), findsOneWidget);
      await tester.tap(find.text('Detener detección'));
      await tester.pumpAndSettle();

      expect(repo.calls, ['stop']);
      expect(find.text('Detección detenida'), findsOneWidget);
    });

    testWidgets('sin perfil de bebé no deja iniciar', (tester) async {
      final repo = FakeDetectionRepository();
      await tester.pumpWidget(host(repo, babies: const []));
      await tester.pumpAndSettle();

      expect(find.textContaining('Crea un perfil'), findsOneWidget);
      await tester.tap(find.text('Iniciar detección'));
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);
    });

    testWidgets('colchón sin conexión: aviso y peso sin datos', (tester) async {
      final repo = FakeDetectionRepository();
      await tester.pumpWidget(
        host(
          repo,
          devices: [
            mattress(lastSeenAt: _now.subtract(const Duration(hours: 1))),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('no responde'), findsOneWidget);
      expect(find.text('Sin datos'), findsOneWidget);
    });
  });
}
