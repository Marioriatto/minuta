import 'package:colchon_minuta/features/babies/babies_providers.dart';
import 'package:colchon_minuta/features/dashboard/dashboard_providers.dart';
import 'package:colchon_minuta/features/dashboard/domain/dashboard_models.dart';
import 'package:colchon_minuta/features/dashboard/domain/home_modules.dart';
import 'package:colchon_minuta/features/dashboard/presentation/home_dashboard_page.dart';
import 'package:colchon_minuta/features/devices/devices_providers.dart';
import 'package:colchon_minuta/features/devices/domain/device.dart';
import 'package:colchon_minuta/l10n/generated/app_localizations.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_babies.dart';

final _now = DateTime.utc(2026, 11, 19, 12);

Widget _host({
  HomeModules modules = const HomeModules(),
  DashboardHistory history = const DashboardHistory(),
  List<ActivityEvent> activity = const [],
}) =>
    ProviderScope(
      overrides: [
        activeBabyProvider
            .overrideWithValue(makeBaby(name: 'Emma', weightKg: null)),
        homeModulesProvider.overrideWithValue(AsyncData(modules)),
        dashboardHistoryProvider.overrideWith((ref) async => history),
        recentActivityProvider.overrideWith((ref) async => activity),
        nowProvider.overrideWith((ref) => Stream.value(_now)),
      ],
      child: const MaterialApp(
        locale: Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeDashboardPage(),
      ),
    );

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('cuenta nueva: todo vacío, sin datos inventados', (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.text('Emma'), findsOneWidget);
    expect(find.textContaining('Sin pesar'), findsOneWidget);
    // Los tres módulos invitan a vincular.
    expect(find.text('Vincular'), findsNWidgets(3));
    // Gráficas en estado vacío, ninguna línea dibujada.
    expect(find.byType(LineChart), findsNothing);
    expect(find.textContaining('Aún no hay pesajes'), findsOneWidget);
    expect(find.text('Aún no hay lecturas de la cuna.'), findsNWidgets(2));
    expect(find.textContaining('Todavía no hay actividad'), findsOneWidget);
  });

  testWidgets('con módulos y lecturas muestra estado, gráficas y actividad',
      (tester) async {
    _tallScreen(tester);
    final cradle = Device(
      id: 'c1',
      kind: DeviceKind.cradle,
      name: null,
      config: const {
        'thresholds': {
          'temperature': {'min': 20, 'max': 26},
        },
      },
      reportedState: const {'temperature_c': 24.1, 'humidity_pct': 55.0},
      lastSeenAt: _now,
    );
    await tester.pumpWidget(
      _host(
        modules: HomeModules(cradle: cradle),
        history: DashboardHistory(
          temperature: [
            ChartPoint(_now.subtract(const Duration(hours: 2)), 23.5),
            ChartPoint(_now.subtract(const Duration(hours: 1)), 24.1),
          ],
        ),
        activity: [
          ActivityEvent(
            id: '1',
            type: 'presence_detected',
            occurredAt: _now,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('24,1 °C'), findsWidgets);
    expect(find.text('En línea'), findsOneWidget);
    expect(find.text('Vincular'), findsNWidgets(2)); // colchón y luces
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('Bebé detectado en el colchón'), findsOneWidget);
  });
}
