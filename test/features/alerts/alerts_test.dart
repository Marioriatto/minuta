import 'dart:async';

import 'package:colchon_minuta/core/errors/app_failure.dart';
import 'package:colchon_minuta/core/errors/result.dart';
import 'package:colchon_minuta/features/alerts/alerts_providers.dart';
import 'package:colchon_minuta/features/alerts/data/alerts_remote_source.dart';
import 'package:colchon_minuta/features/alerts/data/alerts_repository_impl.dart';
import 'package:colchon_minuta/features/alerts/domain/alert.dart';
import 'package:colchon_minuta/features/alerts/domain/alerts_repository.dart';
import 'package:colchon_minuta/features/alerts/domain/alerts_use_cases.dart';
import 'package:colchon_minuta/features/alerts/presentation/alerts_actions_controller.dart';
import 'package:colchon_minuta/features/alerts/presentation/alerts_page.dart';
import 'package:colchon_minuta/features/auth/auth_providers.dart';
import 'package:colchon_minuta/features/auth/domain/auth_snapshot.dart';
import 'package:colchon_minuta/features/auth/domain/auth_user.dart';
import 'package:colchon_minuta/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Alert alert(
  String id, {
  String type = 'absence_detected',
  AlertSeverity severity = AlertSeverity.critical,
  DateTime? at,
  bool read = false,
  Map<String, Object?> payload = const {},
}) =>
    Alert(
      id: id,
      type: type,
      severity: severity,
      occurredAt: at ?? DateTime.utc(2026, 11, 19, 12),
      readAt: read ? DateTime.utc(2026, 11, 19, 13) : null,
      payload: payload,
    );

class FakeAlertsRepository implements AlertsRepository {
  FakeAlertsRepository([List<Alert>? initial]) : store = [...?initial];
  final List<Alert> store;
  final calls = <String>[];
  AppFailure? failWith;

  @override
  Future<Result<List<Alert>>> list({int limit = AlertsRules.pageSize}) async {
    if (failWith != null) return Err(failWith!);
    return Ok([...store]);
  }

  @override
  Stream<List<Alert>> watch({int limit = AlertsRules.pageSize}) =>
      const Stream.empty();

  @override
  Future<Result<void>> markRead(List<String> ids) async {
    calls.add('read:${ids.join(',')}');
    return failWith != null ? Err(failWith!) : const Ok<void>(null);
  }

  @override
  Future<Result<void>> markAllRead() async {
    calls.add('readAll');
    return failWith != null ? Err(failWith!) : const Ok<void>(null);
  }
}

class _FakeRemote implements AlertsRemoteSource {
  List<int>? lastIds = const [-1];

  @override
  Future<List<Map<String, dynamic>>> fetch({required int limit}) async => [
        {
          'id': 7,
          'type': 'temperature_high',
          'severity': 'warning',
          'payload': {'value': 27.4, 'max': 26},
          'occurred_at': '2026-11-19T12:00:00+00:00',
          'read_at': null,
        },
        {
          'id': 8,
          'type': 'raro',
          'severity': 'desconocida',
          'payload': null,
          'occurred_at': '2026-11-19T13:00:00+00:00',
          'read_at': '2026-11-19T14:00:00+00:00',
        },
      ];

  @override
  Stream<List<Map<String, dynamic>>> stream({required int limit}) =>
      const Stream.empty();

  @override
  Future<void> markRead(List<int>? ids) async => lastIds = ids;
}

List<Override> _signedIn(FakeAlertsRepository repo) => [
      alertsRepositoryProvider.overrideWithValue(repo),
      authSnapshotProvider.overrideWith(
        (ref) => Stream.value(
          const AuthSnapshot(AuthEvent.signedIn, AuthUser(id: 'u1')),
        ),
      ),
    ];

void main() {
  group('dominio', () {
    test('severidad desde el código; solo warning y critical notifican', () {
      expect(AlertSeverity.fromCode('critical'), AlertSeverity.critical);
      expect(AlertSeverity.fromCode('warning'), AlertSeverity.warning);
      expect(AlertSeverity.fromCode('x'), AlertSeverity.info);
      expect(AlertSeverity.info.notifies, isFalse);
      expect(AlertSeverity.warning.notifies, isTrue);
    });

    test('orden: más reciente primero y contador de no leídas', () {
      final list = AlertsRules.sorted([
        alert('1', at: DateTime.utc(2026, 11, 19, 8)),
        alert('2', at: DateTime.utc(2026, 11, 19, 9), read: true),
        alert('3', at: DateTime.utc(2026, 11, 19, 7)),
      ]);
      expect(list.map((a) => a.id), ['2', '1', '3']);
      expect(AlertsRules.unreadCount(list), 2);
    });

    test('marcar leídas no reenvía las que ya lo están', () async {
      final repo = FakeAlertsRepository();
      await MarkAlertsRead(repo)([alert('1', read: true)]);
      expect(repo.calls, isEmpty);
      await MarkAlertsRead(repo)([alert('1', read: true), alert('2')]);
      expect(repo.calls, ['read:2']);
    });

    test('marcar todas no llama si no hay no leídas', () async {
      final repo = FakeAlertsRepository();
      await MarkAllAlertsRead(repo)([alert('1', read: true)]);
      expect(repo.calls, isEmpty);
      await MarkAllAlertsRead(repo)([alert('1')]);
      expect(repo.calls, ['readAll']);
    });
  });

  group('datos', () {
    test('mapea filas, tolera valores raros y convierte ids', () async {
      final remote = _FakeRemote();
      final repo = AlertsRepositoryImpl(remote);
      final list = (await repo.list()).when(ok: (l) => l, err: (_) => null)!;
      expect(list.first.severity, AlertSeverity.warning);
      expect(list.first.value, 27.4);
      expect(list.first.max, 26);
      expect(list.first.isRead, isFalse);
      expect(list.last.severity, AlertSeverity.info);
      expect(list.last.payload, isEmpty);
      expect(list.last.isRead, isTrue);

      await repo.markRead(['7', '8']);
      expect(remote.lastIds, [7, 8]);
      await repo.markAllRead();
      expect(remote.lastIds, isNull);
    });
  });

  group('controlador', () {
    test('marcar una la refleja como leída y baja el contador', () async {
      final repo = FakeAlertsRepository([alert('1'), alert('2')]);
      final c = ProviderContainer(overrides: _signedIn(repo));
      addTearDown(c.dispose);
      await c.read(authSnapshotProvider.future);
      await c.read(alertsProvider.future);
      expect(c.read(unreadAlertsCountProvider), 2);

      final first = c.read(alertsProvider).value!.first;
      await c.read(alertsActionsControllerProvider.notifier).markRead(first);
      expect(c.read(unreadAlertsCountProvider), 1);

      await c.read(alertsActionsControllerProvider.notifier).markAllRead();
      expect(c.read(unreadAlertsCountProvider), 0);
      expect(repo.calls, ['read:${first.id}', 'readAll']);
    });

    test('un fallo queda en el estado y no cambia la lista', () async {
      final repo = FakeAlertsRepository([alert('1')]);
      final c = ProviderContainer(overrides: _signedIn(repo));
      addTearDown(c.dispose);
      await c.read(authSnapshotProvider.future);
      await c.read(alertsProvider.future);
      repo.failWith = const NetworkFailure();
      await c.read(alertsActionsControllerProvider.notifier).markAllRead();
      expect(
        c.read(alertsActionsControllerProvider).failure,
        isA<NetworkFailure>(),
      );
      expect(c.read(unreadAlertsCountProvider), 1);
    });
  });

  group('pantalla', () {
    Widget host(FakeAlertsRepository repo) => ProviderScope(
          overrides: _signedIn(repo),
          child: const MaterialApp(
            locale: Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AlertsPage(),
          ),
        );

    testWidgets('cuenta nueva: estado vacío y sin "marcar todas"',
        (tester) async {
      await tester.pumpWidget(host(FakeAlertsRepository()));
      await tester.pumpAndSettle();
      expect(find.text('Sin alertas'), findsOneWidget);
      expect(find.byIcon(Icons.done_all_rounded), findsNothing);
    });

    testWidgets('lista con severidad, detalle y marcar como leída',
        (tester) async {
      final repo = FakeAlertsRepository([
        alert('1'),
        alert(
          '2',
          type: 'temperature_high',
          severity: AlertSeverity.warning,
          at: DateTime.utc(2026, 11, 19, 10),
          payload: {'value': 27.4, 'max': 26},
        ),
      ]);
      await tester.pumpWidget(host(repo));
      await tester.pumpAndSettle();

      expect(find.text('Se dejó de detectar al bebé'), findsOneWidget);
      expect(find.text('Temperatura alta en la cuna'), findsOneWidget);
      expect(find.text('27,4 °C · límite 26,0 °C'), findsOneWidget);
      expect(find.textContaining('Crítica'), findsOneWidget);
      expect(find.textContaining('Advertencia'), findsOneWidget);

      await tester.tap(find.text('Se dejó de detectar al bebé'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['read:1']);

      await tester.tap(find.byIcon(Icons.done_all_rounded));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'readAll');
      expect(find.byIcon(Icons.done_all_rounded), findsNothing);
    });
  });
}
