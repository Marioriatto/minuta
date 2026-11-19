import 'dart:io';

import 'package:colchon_minuta/core/errors/app_failure.dart';
import 'package:colchon_minuta/core/errors/result.dart';
import 'package:colchon_minuta/features/auth/data/supabase_auth_repository.dart';
import 'package:colchon_minuta/features/auth/domain/auth_snapshot.dart';
import 'package:colchon_minuta/features/auth/domain/sign_up_outcome.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class _MockClient extends Mock implements sb.SupabaseClient {}

class _MockAuth extends Mock implements sb.GoTrueClient {}

AppFailure? _failure<T>(Result<T> r) =>
    r.when<AppFailure?>(ok: (_) => null, err: (f) => f);

void main() {
  late _MockClient client;
  late _MockAuth auth;
  late SupabaseAuthRepository repo;

  setUp(() {
    client = _MockClient();
    auth = _MockAuth();
    when(() => client.auth).thenReturn(auth);
    repo = SupabaseAuthRepository(client);
  });

  group('signInWithPassword', () {
    test('éxito', () async {
      when(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => sb.AuthResponse());

      final r = await repo.signInWithPassword(email: 'a@b.co', password: 'x');
      expect(_failure(r), isNull);
    });

    test('credenciales inválidas', () async {
      when(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        const sb.AuthException(
          'Invalid login credentials',
          statusCode: '400',
          code: 'invalid_credentials',
        ),
      );

      final r = await repo.signInWithPassword(email: 'a@b.co', password: 'x');
      expect(_failure(r), isA<InvalidCredentialsFailure>());
    });

    test('sin red', () async {
      when(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const SocketException('sin red'));

      final r = await repo.signInWithPassword(email: 'a@b.co', password: 'x');
      expect(_failure(r), isA<NetworkFailure>());
    });
  });

  test('signUp sin sesión exige verificar el correo', () async {
    when(
      () => auth.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
        emailRedirectTo: any(named: 'emailRedirectTo'),
      ),
    ).thenAnswer((_) async => sb.AuthResponse());

    final r = await repo.signUp(email: 'a@b.co', password: 'larga-123');
    expect(
      r.when(ok: (v) => v, err: (_) => null),
      SignUpOutcome.needsEmailVerification,
    );
  });

  test('signOut delega en Supabase', () async {
    when(() => auth.signOut()).thenAnswer((_) async {});
    final r = await repo.signOut();
    expect(_failure(r), isNull);
    verify(() => auth.signOut()).called(1);
  });

  group('watchSession', () {
    test('emite el estado inicial y traduce recuperación de contraseña',
        () async {
      when(() => auth.currentSession).thenReturn(null);
      when(() => auth.onAuthStateChange).thenAnswer(
        (_) => Stream.fromIterable([
          const sb.AuthState(sb.AuthChangeEvent.passwordRecovery, null),
          const sb.AuthState(sb.AuthChangeEvent.signedOut, null),
        ]),
      );

      final events = await repo.watchSession().map((s) => s.event).toList();
      expect(events, [
        AuthEvent.signedOut,
        AuthEvent.passwordRecovery,
        AuthEvent.signedOut,
      ]);
    });
  });
}
