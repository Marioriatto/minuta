import 'package:colchon_minuta/core/errors/app_failure.dart';
import 'package:colchon_minuta/core/errors/result.dart';
import 'package:colchon_minuta/features/permissions/domain/app_permission.dart';
import 'package:colchon_minuta/features/permissions/domain/permissions_gateway.dart';
import 'package:colchon_minuta/features/permissions/domain/permissions_intro_store.dart';
import 'package:colchon_minuta/features/permissions/domain/permissions_use_cases.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGateway implements PermissionsGateway {
  _FakeGateway({this.throwOnRequest = false});

  final bool throwOnRequest;
  final requested = <AppPermission>[];

  @override
  Future<AppPermissionStatus> request(AppPermission permission) async {
    if (throwOnRequest) throw StateError('fallo del sistema');
    requested.add(permission);
    return permission == AppPermission.notifications
        ? AppPermissionStatus.granted
        : AppPermissionStatus.denied;
  }

  @override
  Future<AppPermissionStatus> status(AppPermission permission) async =>
      AppPermissionStatus.denied;

  @override
  Future<bool> openSystemSettings() async => true;
}

class _FakeStore implements PermissionsIntroStore {
  bool seen = false;

  @override
  Future<bool> isSeen() async => seen;

  @override
  Future<void> markSeen() async => seen = true;
}

void main() {
  test('solo solicita lo elegido y marca la introducción como vista', () async {
    final gateway = _FakeGateway();
    final store = _FakeStore();
    final useCase = CompletePermissionsIntro(gateway: gateway, store: store);

    final result = await useCase(selected: {AppPermission.notifications});

    expect(gateway.requested, [AppPermission.notifications]);
    expect(store.seen, isTrue);
    expect(result, isA<Ok<Map<AppPermission, AppPermissionStatus>>>());
  });

  test('que se deniegue un permiso no bloquea al usuario', () async {
    final store = _FakeStore();
    final useCase =
        CompletePermissionsIntro(gateway: _FakeGateway(), store: store);

    final result = await useCase(selected: AppPermission.values.toSet());

    final map = result.when(ok: (m) => m, err: (_) => null)!;
    expect(map[AppPermission.microphone], AppPermissionStatus.denied);
    expect(store.seen, isTrue);
  });

  test('si el sistema falla, devuelve error y no marca como visto', () async {
    final store = _FakeStore();
    final useCase = CompletePermissionsIntro(
      gateway: _FakeGateway(throwOnRequest: true),
      store: store,
    );

    final result = await useCase(selected: {AppPermission.microphone});

    expect(
      result.when<AppFailure?>(ok: (_) => null, err: (f) => f),
      isA<UnknownFailure>(),
    );
    expect(store.seen, isFalse);
  });

  test('GetPermissionStatuses consulta todos los permisos', () async {
    final statuses = await GetPermissionStatuses(_FakeGateway())();
    expect(statuses.keys, AppPermission.values);
  });
}
