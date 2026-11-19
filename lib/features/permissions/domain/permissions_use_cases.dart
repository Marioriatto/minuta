import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import 'app_permission.dart';
import 'permissions_gateway.dart';
import 'permissions_intro_store.dart';

/// Solicita los permisos elegidos y marca la introducción como vista.
/// Que el usuario deniegue un permiso no bloquea: puede cambiarlo luego en los
/// ajustes del sistema. Un error del sistema sí se reporta para poder reintentar.
class CompletePermissionsIntro {
  const CompletePermissionsIntro({
    required PermissionsGateway gateway,
    required PermissionsIntroStore store,
  })  : _gateway = gateway,
        _store = store;

  final PermissionsGateway _gateway;
  final PermissionsIntroStore _store;

  Future<Result<Map<AppPermission, AppPermissionStatus>>> call({
    required Set<AppPermission> selected,
  }) async {
    try {
      final results = <AppPermission, AppPermissionStatus>{};
      for (final permission in selected) {
        results[permission] = await _gateway.request(permission);
      }
      await _store.markSeen();
      return Ok(results);
    } on Object catch (e) {
      return Err(UnknownFailureFor.wrap(e));
    }
  }
}

class GetPermissionStatuses {
  const GetPermissionStatuses(this._gateway);
  final PermissionsGateway _gateway;

  Future<Map<AppPermission, AppPermissionStatus>> call() async => {
        for (final p in AppPermission.values) p: await _gateway.status(p),
      };
}
