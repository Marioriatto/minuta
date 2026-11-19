import 'package:colchon_minuta/core/config/app_config.dart';
import 'package:colchon_minuta/core/config/app_config_provider.dart';
import 'package:colchon_minuta/features/auth/auth_providers.dart';
import 'package:colchon_minuta/features/auth/presentation/pages/sign_up_page.dart';
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
        home: SignUpPage(),
      ),
    );

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('registro: con el login social apagado no muestra Google',
      (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(_host(FakeAuthRepository(), social: false));
    expect(find.text('Continuar con Google'), findsNothing);
  });

  testWidgets('registro: Google crea la cuenta por OAuth', (tester) async {
    _tallScreen(tester);
    final repo = FakeAuthRepository();
    await tester.pumpWidget(_host(repo));

    expect(find.text('Continuar con Google'), findsOneWidget);
    await tester.tap(find.text('Continuar con Google'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['social:google']);
  });
}
