import 'dart:async';

import 'package:colchon_minuta/core/errors/app_failure.dart';
import 'package:colchon_minuta/core/errors/result.dart';
import 'package:colchon_minuta/features/notifications/domain/push_gateway.dart';
import 'package:colchon_minuta/features/notifications/domain/push_tokens_repository.dart';
import 'package:colchon_minuta/features/notifications/domain/push_use_cases.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gateway implements PushGateway {
  _Gateway({
    this.available = true,
    this.granted = true,
    this.tokenValue = 'tok-123456789012345678',
  });
  final bool available;
  final bool granted;
  final String? tokenValue;

  @override
  bool get isAvailable => available;
  @override
  String get platform => 'android';
  @override
  Future<bool> requestPermission() async => granted;
  @override
  Future<String?> token() async => tokenValue;
  @override
  Stream<String> get tokenRefreshes => const Stream.empty();
  @override
  Stream<void> get alertOpened => const Stream.empty();
}

class _Repo implements PushTokensRepository {
  final calls = <String>[];
  AppFailure? failWith;

  @override
  Future<Result<void>> register({
    required String token,
    required String platform,
  }) async {
    calls.add('register:$token:$platform');
    return failWith != null ? Err(failWith!) : const Ok<void>(null);
  }

  @override
  Future<Result<void>> unregister(String token) async {
    calls.add('unregister:$token');
    return const Ok<void>(null);
  }
}

PushSyncOutcome? _outcome(Result<PushSyncOutcome> r) =>
    r.when(ok: (o) => o, err: (_) => null);

void main() {
  group('SyncPushToken', () {
    test('sin Firebase configurado no hace nada', () async {
      final repo = _Repo();
      final r = await SyncPushToken(_Gateway(available: false), repo)();
      expect(_outcome(r), PushSyncOutcome.unavailable);
      expect(repo.calls, isEmpty);
    });

    test('permiso denegado: no registra', () async {
      final repo = _Repo();
      final r = await SyncPushToken(_Gateway(granted: false), repo)();
      expect(_outcome(r), PushSyncOutcome.permissionDenied);
      expect(repo.calls, isEmpty);
    });

    test('sin token todavía', () async {
      final r = await SyncPushToken(_Gateway(tokenValue: null), _Repo())();
      expect(_outcome(r), PushSyncOutcome.noToken);
    });

    test('registra el token con la plataforma', () async {
      final repo = _Repo();
      final r = await SyncPushToken(_Gateway(), repo)();
      expect(_outcome(r), PushSyncOutcome.registered);
      expect(repo.calls, ['register:tok-123456789012345678:android']);
    });

    test('un error del servidor se propaga', () async {
      final repo = _Repo()..failWith = const NetworkFailure();
      final r = await SyncPushToken(_Gateway(), repo)();
      expect(r.when(ok: (_) => null, err: (f) => f), isA<NetworkFailure>());
    });
  });

  test('al cerrar sesión se desasocia el token (si hay push)', () async {
    final repo = _Repo();
    await UnregisterPushToken(_Gateway(available: false), repo)();
    expect(repo.calls, isEmpty);
    await UnregisterPushToken(_Gateway(), repo)();
    expect(repo.calls, ['unregister:tok-123456789012345678']);
  });
}
