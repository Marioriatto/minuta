import 'package:colchon_minuta/core/errors/app_failure.dart';
import 'package:colchon_minuta/core/ui/state_view.dart';
import 'package:colchon_minuta/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

StateView<List<int>> _view(AsyncValue<List<int>> v, {VoidCallback? onRetry}) =>
    StateView<List<int>>(
      value: v,
      isEmpty: (d) => d.isEmpty,
      onRetry: onRetry,
      builder: (_, d) => Text('datos:${d.length}'),
    );

void main() {
  testWidgets('cargando muestra indicador', (t) async {
    await t.pumpWidget(_host(_view(const AsyncValue.loading())));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('datos muestra el contenido', (t) async {
    await t.pumpWidget(_host(_view(const AsyncValue.data([1, 2]))));
    expect(find.text('datos:2'), findsOneWidget);
  });

  testWidgets('vacío muestra mensaje por defecto', (t) async {
    await t.pumpWidget(_host(_view(const AsyncValue.data([]))));
    expect(find.text('No hay nada que mostrar todavía.'), findsOneWidget);
  });

    testWidgets('NetworkFailure muestra sin conexión y permite reintentar',
      (t) async {
    var retried = 0;
    await t.pumpWidget(
      _host(
        _view(
          const AsyncValue.error(NetworkFailure(), StackTrace.empty),
          onRetry: () => retried++,
        ),
      ),
    );
    expect(find.text('Sin conexión'), findsOneWidget);
    await t.tap(find.text('Reintentar'));
    expect(retried, 1);
  });

  testWidgets('otro error muestra título genérico y mensaje localizado',
      (t) async {
    await t.pumpWidget(
      _host(
        _view(const AsyncValue.error(ForbiddenFailure(), StackTrace.empty)),
      ),
    );
    expect(find.text('Algo salió mal'), findsOneWidget);
    expect(
      find.text('No tienes permiso para realizar esta acción.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsNothing);
  });
  }
