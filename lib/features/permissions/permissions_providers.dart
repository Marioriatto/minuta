import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/permission_handler_gateway.dart';
import 'data/shared_prefs_intro_store.dart';
import 'domain/app_permission.dart';
import 'domain/permissions_gateway.dart';
import 'domain/permissions_intro_store.dart';
import 'domain/permissions_use_cases.dart';

/// Punto de composición de la feature (única conexión datos ↔ dominio).

final permissionsGatewayProvider = Provider<PermissionsGateway>(
  (ref) => PermissionHandlerGateway(),
);

final permissionsIntroStoreProvider = Provider<PermissionsIntroStore>(
  (ref) => SharedPrefsIntroStore(),
);

final completePermissionsIntroProvider = Provider<CompletePermissionsIntro>(
  (ref) => CompletePermissionsIntro(
    gateway: ref.watch(permissionsGatewayProvider),
    store: ref.watch(permissionsIntroStoreProvider),
  ),
);

final getPermissionStatusesProvider = Provider<GetPermissionStatuses>(
  (ref) => GetPermissionStatuses(ref.watch(permissionsGatewayProvider)),
);

/// ¿Ya se mostró la introducción de permisos en este dispositivo?
class PermissionsIntroSeenNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.read(permissionsIntroStoreProvider).isSeen();

  /// Se llama tras completar la introducción (el caso de uso ya persistió).
  void acknowledged() => state = const AsyncData(true);
}

final permissionsIntroSeenProvider =
    AsyncNotifierProvider<PermissionsIntroSeenNotifier, bool>(
  PermissionsIntroSeenNotifier.new,
);

final permissionStatusesProvider =
    FutureProvider.autoDispose<Map<AppPermission, AppPermissionStatus>>(
  (ref) => ref.watch(getPermissionStatusesProvider)(),
);
