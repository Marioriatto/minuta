import 'package:colchon_minuta/core/config/app_config.dart';
import 'package:colchon_minuta/core/config/app_config_provider.dart';
import 'package:colchon_minuta/core/errors/app_failure.dart';
import 'package:colchon_minuta/core/errors/result.dart';
import 'package:colchon_minuta/features/auth/auth_providers.dart';
import 'package:colchon_minuta/features/auth/presentation/pages/login_page.dart';
import 'package:colchon_minuta/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_auth_repository.dart';

Widget _host(FakeAuthRepository repo, {bool social = true}) => ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        appConfigProvider.overrideWithValue(
          AppConfig.parse(
            environment: 'dev',
            supabaseUrl: 'https://prueba.supabase.co',
            supabaseAnonKey: 'clave-publica',
            socialLoginEnabled: social,
          ),
        ),
      ],
      child: const MaterialApp(
        locale: Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LoginPage(),
      ),
    );

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('muestra el logo de Minuta en lugar del título', (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(_host(FakeAuthRepository()));
    expect(find.text('Minuta'), findsOneWidget);
    expect(find.byIcon(Icons.child_care_rounded), findsOneWidget);
    expect(find.text('Entra para cuidar a tu bebé'), findsNothing);
  });

  testWidgets('con el login social apagado no muestra botones', (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(_host(FakeAuthRepository(), social: false));
    expect(find.text('Continuar con Google'), findsNothing);
    expect(find.text('Continuar con Apple'), findsNothing);
    expect(find.text('o continúa con'), findsNothing);
  });

  testWidgets('en Android muestra Google y no Apple', (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(_host(FakeAuthRepository()));
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Continuar con Apple'), findsNothing);
  });

  testWidgets(
    'en iOS muestra también Apple',
    (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(_host(FakeAuthRepository()));
      expect(find.text('Continuar con Google'), findsOneWidget);
      expect(find.text('Continuar con Apple'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('enviar vacío muestra errores y no llama al servidor',
      (tester) async {
    _tallScreen(tester);
    final repo = FakeAuthRepository();
    await tester.pumpWidget(_host(repo));

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();

    expect(find.text('Este campo es obligatorio.'), findsNWidgets(2));
    expect(repo.calls, isEmpty);
  });

  testWidgets('credenciales incorrectas muestran el mensaje', (tester) async {
    _tallScreen(tester);
    final repo = FakeAuthRepository()
      ..signInResult = const Err<void>(InvalidCredentialsFailure());
    await tester.pumpWidget(_host(repo));

    await tester.enterText(find.byType(TextField).at(0), 'maria@correo.com');
    await tester.enterText(find.byType(TextField).at(1), 'mala-clave');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
    expect(repo.calls, ['signIn:maria@correo.com']);
  });
}
