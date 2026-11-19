import 'package:colchon_minuta/core/errors/app_failure.dart';
import 'package:colchon_minuta/core/errors/result.dart';
import 'package:colchon_minuta/features/dashboard/domain/dashboard_models.dart';
import 'package:colchon_minuta/features/dashboard/domain/dashboard_repository.dart';
import 'package:colchon_minuta/features/dashboard/domain/dashboard_use_cases.dart';
import 'package:colchon_minuta/features/dashboard/domain/home_modules.dart';
import 'package:colchon_minuta/features/devices/domain/device.dart';
import 'package:flutter_test/flutter_test.dart';

HourlyReading _r(DashboardMetric m, DateTime at, double v) =>
    HourlyReading(metric: m, bucketStart: at, average: v);

Device _device(
  DeviceKind kind, {
  String id = 'd',
  DateTime? seen,
  Map<String, Object?> state = const {},
}) =>
    Device(
      id: id,
      kind: kind,
      name: null,
      config: const {},
      reportedState: state,
      lastSeenAt: seen,
    );

class _FakeRepo implements DashboardRepository {
  final calls = <String>[];
  List<HourlyReading> readings = const [];
  AppFailure? failWith;

  @override
  Future<Result<List<HourlyReading>>> hourly({
    required Set<DashboardMetric> metrics,
    required DateTime since,
    String? babyId,
  }) async {
    calls.add('hourly:${metrics.map((m) => m.code).join('+')}:$babyId');
    if (failWith != null) return Err(failWith!);
    return Ok([
      for (final r in readings)
        if (metrics.contains(r.metric)) r,
    ]);
  }

  @override
  Future<Result<List<ActivityEvent>>> recentActivity({
    required String? babyId,
    required int limit,
  }) async {
    calls.add('activity:$babyId:$limit');
    return const Ok([]);
  }
}

void main() {
  group('DashboardSeries', () {
    test('cuenta nueva: sin lecturas no hay puntos (nada inventado)', () {
      expect(DashboardSeries.dailyWeight(const []), isEmpty);
      expect(
        DashboardSeries.hourly(const [], DashboardMetric.temperature),
        isEmpty,
      );
    });

    test('promedia el peso por día e ignora el colchón vacío', () {
      final day1 = DateTime(2026, 11, 18, 10);
      final day2 = DateTime(2026, 11, 19, 9);
      final points = DashboardSeries.dailyWeight([
        _r(DashboardMetric.weight, day1, 5.8),
        _r(DashboardMetric.weight, day1.add(const Duration(hours: 1)), 6.0),
        _r(DashboardMetric.weight, day1.add(const Duration(hours: 2)), 0.1),
        _r(DashboardMetric.weight, day2, 6.1),
        _r(DashboardMetric.temperature, day2, 24),
      ]);
      expect(points, [
        ChartPoint(DateTime(2026, 11, 18), 5.9),
        ChartPoint(DateTime(2026, 11, 19), 6.1),
      ]);
    });

    test('la serie horaria se ordena en el tiempo y filtra la métrica', () {
      final a = DateTime(2026, 11, 19, 8);
      final b = DateTime(2026, 11, 19, 7);
      final points = DashboardSeries.hourly(
        [
          _r(DashboardMetric.humidity, a, 55),
          _r(DashboardMetric.humidity, b, 50),
          _r(DashboardMetric.temperature, a, 24),
        ],
        DashboardMetric.humidity,
      );
      expect(points.map((p) => p.value), [50, 55]);
    });
  });

  test('categoría de los eventos', () {
    ActivityEvent e(String type) =>
        ActivityEvent(id: '1', type: type, occurredAt: DateTime.utc(2026));
    expect(e('presence_detected').category, ActivityCategory.mattress);
    expect(e('humidity_high').category, ActivityCategory.environment);
    expect(e('lights_changed').category, ActivityCategory.lights);
    expect(e('algo_nuevo').category, ActivityCategory.other);
  });

  group('HomeModules', () {
    final now = DateTime.utc(2026, 11, 19, 12);

    test('sin módulos vinculados todo queda vacío', () {
      final m = HomeModules.from(const []);
      expect(m.mattress, isNull);
      expect(m.cradle, isNull);
      expect(m.lights, isNull);
    });

    test('con dos del mismo tipo usa el que habló más reciente', () {
      final m = HomeModules.from([
        _device(
          DeviceKind.cradle,
          id: 'viejo',
          seen: now.subtract(const Duration(days: 1)),
        ),
        _device(DeviceKind.cradle, id: 'nuevo', seen: now),
        _device(DeviceKind.cradle, id: 'nunca'),
      ]);
      expect(m.cradle!.id, 'nuevo');
    });

    test('presencia según el peso actual y la conexión', () {
      MattressPresence p(double? kg, {bool online = true}) =>
          HomeModules.presenceOf(
            _device(
              DeviceKind.mattress,
              seen: online ? now : now.subtract(const Duration(minutes: 5)),
              state: {if (kg != null) 'weight_kg': kg},
            ),
            now,
          );
      expect(p(5.84), MattressPresence.occupied);
      expect(p(0.2), MattressPresence.empty);
      expect(p(null), MattressPresence.unknown);
      expect(p(5.84, online: false), MattressPresence.unknown);
    });
  });

  group('LoadDashboardHistory', () {
    test('sin bebé activo no pide el peso', () async {
      final repo = _FakeRepo();
      final r = await LoadDashboardHistory(repo)(babyId: null);
      expect(repo.calls, ['hourly:temperature+humidity:null']);
      expect(
        r.when(ok: (h) => h.hasWeight || h.hasEnvironment, err: (_) => true),
        isFalse,
      );
    });

    test('pide el peso del bebé y arma las series', () async {
      final at = DateTime.utc(2026, 11, 19, 10);
      final repo = _FakeRepo()
        ..readings = [
          _r(DashboardMetric.weight, at, 6),
          _r(DashboardMetric.temperature, at, 24.5),
        ];
      final r = await LoadDashboardHistory(repo, now: () => at)(babyId: 'b1');
      final h = r.when(ok: (h) => h, err: (_) => null)!;
      expect(repo.calls.last, 'hourly:weight:b1');
      expect(h.dailyWeight, hasLength(1));
      expect(h.temperature.single.value, 24.5);
      expect(h.humidity, isEmpty);
    });

    test('un error del servidor se propaga', () async {
      final repo = _FakeRepo()..failWith = const NetworkFailure();
      final r = await LoadDashboardHistory(repo)(babyId: 'b1');
      expect(
        r.when(ok: (_) => null, err: (f) => f),
        isA<NetworkFailure>(),
      );
    });
  });
}
