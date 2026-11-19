import 'package:colchon_minuta/features/babies/babies_providers.dart';
import 'package:colchon_minuta/features/babies/domain/baby.dart';
import 'package:colchon_minuta/features/babies/presentation/pages/babies_page.dart';
import 'package:colchon_minuta/features/babies/presentation/pages/baby_form_page.dart';
import 'package:colchon_minuta/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_babies.dart';

Widget _host(Widget home, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

List<Override> _babies(List<Baby> list, {String? activeId}) => [
      babiesProvider.overrideWith(() => FakeBabiesNotifier(list)),
      activeBabyIdProvider
          .overrideWith(() => FakeActiveBabyIdNotifier(activeId)),
    ];

void main() {
  group('BabyFormPage', () {
    testWidgets('primer perfil: título y salida para cambiar de cuenta',
        (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(_host(const BabyFormPage(isFirst: true)));

      expect(find.text('Cuéntanos de tu bebé'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('enviar vacío muestra los errores de nombre y fecha',
        (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(_host(const BabyFormPage(isFirst: true)));

      await tester.tap(find.text('Crear perfil'));
      await tester.pump();

      expect(find.text('Escribe un nombre.'), findsOneWidget);
      expect(find.text('Elige la fecha de nacimiento.'), findsOneWidget);
    });

    testWidgets('no pide el peso: avisa que lo mide el colchón',
        (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(_host(const BabyFormPage(isFirst: true)));

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.textContaining('El peso lo mide el colchón'), findsOneWidget);
    });

    testWidgets('edición: precarga los datos del perfil', (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(
        _host(
          const BabyFormPage(babyId: 'b1'),
          overrides: _babies([makeBaby(name: 'Emma', weightKg: 5.84)]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Emma'), findsOneWidget);
      expect(find.widgetWithText(TextField, '5,84'), findsNothing);
      expect(find.text('Guardar'), findsOneWidget);
    });

    testWidgets('edición de un perfil inexistente', (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(
        _host(const BabyFormPage(babyId: 'nope'), overrides: _babies([])),
      );
      await tester.pumpAndSettle();

      expect(find.text('No encontramos lo que buscas.'), findsOneWidget);
    });
  });

  group('BabiesPage', () {
    final emma = makeBaby(id: 'b1', registeredAt: DateTime(2026, 1, 1));
    final leo = makeBaby(
      id: 'b2',
      name: 'Leo',
      registeredAt: DateTime(2026, 2, 1),
    );
    final old = makeBaby(
      id: 'b3',
      name: 'Sol',
      archivedAt: DateTime(2026, 5, 1),
    );

    testWidgets('muestra activos, el perfil activo y archivados',
        (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(
        _host(
          const BabiesPage(),
          overrides: _babies([emma, leo, old], activeId: 'b2'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Activos'), findsOneWidget);
      expect(find.text('Archivados'), findsOneWidget);
      expect(find.text('Emma'), findsOneWidget);
      expect(find.text('Leo'), findsOneWidget);
      expect(find.text('Sol'), findsOneWidget);
      expect(find.text('Activo'), findsOneWidget);
      expect(find.text('Agregar bebé'), findsOneWidget);
    });

    testWidgets('con un solo perfil activo no se puede archivar',
        (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(
        _host(const BabiesPage(), overrides: _babies([emma])),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Debe quedar al menos un perfil activo.'),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Archivar'), findsNothing);
    });

    testWidgets('perfil sin pesar: lo indica y ofrece Pesar ahora',
        (tester) async {
      _tallScreen(tester);
      final unweighed = makeBaby(id: 'b9', name: 'Ana', weightKg: null);
      await tester.pumpWidget(
        _host(const BabiesPage(), overrides: _babies([unweighed])),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Sin pesar'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Pesar ahora'), findsOneWidget);
    });

    testWidgets('un perfil archivado no ofrece Pesar ahora', (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(
        _host(const BabiesPage(), overrides: _babies([emma, old])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();
      expect(find.text('Pesar ahora'), findsNothing);
    });

    testWidgets('con dos perfiles activos sí se ofrece archivar',
        (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(
        _host(const BabiesPage(), overrides: _babies([emma, leo])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      expect(find.text('Archivar'), findsOneWidget);
    });

    testWidgets('un perfil archivado se puede restaurar o eliminar con aviso',
        (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(
        _host(const BabiesPage(), overrides: _babies([emma, old])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();
      expect(find.text('Restaurar'), findsOneWidget);
      expect(find.text('Eliminar definitivamente'), findsOneWidget);

      await tester.tap(find.text('Eliminar definitivamente'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar el perfil de Sol?'), findsOneWidget);
      expect(
        find.textContaining('todo su historial'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar el perfil de Sol?'), findsNothing);
    });
  });
}
