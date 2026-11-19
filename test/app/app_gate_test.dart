import 'package:colchon_minuta/app/app_gate.dart';
import 'package:colchon_minuta/core/errors/app_failure.dart';
import 'package:colchon_minuta/features/auth/auth_providers.dart';
import 'package:colchon_minuta/features/auth/domain/auth_snapshot.dart';
import 'package:colchon_minuta/features/auth/domain/auth_user.dart';
import 'package:colchon_minuta/features/babies/babies_providers.dart';
import 'package:colchon_minuta/features/babies/domain/baby.dart';
import 'package:colchon_minuta/features/permissions/permissions_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_babies.dart';

class _FakeSeen extends PermissionsIntroSeenNotifier {
  _FakeSeen(this.seen);
  final bool seen;

  @override
  Future<bool> build() async => seen;
}

Future<AppGate> _gateFor(
  AuthSnapshot snapshot, {
  bool seen = true,
  List<Baby> babies = const [],
  AppFailure? babiesError,
}) async {
  final container = ProviderContainer(
    overrides: [
      authSnapshotProvider.overrideWith((ref) => Stream.value(snapshot)),
      permissionsIntroSeenProvider.overrideWith(() => _FakeSeen(seen)),
      babiesProvider.overrideWith(
        () => FakeBabiesNotifier(babies, error: babiesError),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.listen(appGateProvider, (_, __) {});
  await container.read(authSnapshotProvider.future);
  await container.read(permissionsIntroSeenProvider.future);
  await container.read(babiesProvider.future).then<void>(
        (_) {},
        onError: (Object _) {},
      );
  return container.read(appGateProvider);
}

void main() {
  const user = AuthUser(id: 'u1', email: 'a@b.co');
  const signedIn = AuthSnapshot(AuthEvent.signedIn, user);

  test('sin sesión', () async {
    expect(
      await _gateFor(const AuthSnapshot(AuthEvent.signedOut)),
      AppGate.signedOut,
    );
  });

  test('recuperación de contraseña', () async {
    expect(
      await _gateFor(const AuthSnapshot(AuthEvent.passwordRecovery, user)),
      AppGate.recovery,
    );
  });

  test('con sesión y permisos pendientes', () async {
    expect(
      await _gateFor(signedIn, seen: false),
      AppGate.needsPermissionsIntro,
    );
  });

  test('sin perfiles: pide el primero', () async {
    expect(await _gateFor(signedIn), AppGate.needsFirstProfile);
  });

  test('solo perfiles archivados: pide uno activo', () async {
    final archived = makeBaby(archivedAt: DateTime(2026, 5, 1));
    expect(
      await _gateFor(signedIn, babies: [archived]),
      AppGate.needsFirstProfile,
    );
  });

  test('con un perfil activo: listo', () async {
    expect(await _gateFor(signedIn, babies: [makeBaby()]), AppGate.ready);
  });

  test('si no se pueden cargar los perfiles: pantalla de error', () async {
    expect(
      await _gateFor(signedIn, babiesError: const NetworkFailure()),
      AppGate.profilesError,
    );
  });
}
