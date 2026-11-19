import 'package:permission_handler/permission_handler.dart';

import '../domain/app_permission.dart';
import '../domain/permissions_gateway.dart';

class PermissionHandlerGateway implements PermissionsGateway {
  Permission _map(AppPermission p) => switch (p) {
        AppPermission.notifications => Permission.notification,
        AppPermission.microphone => Permission.microphone,
      };

  AppPermissionStatus _status(PermissionStatus s) {
    if (s.isGranted || s.isLimited || s.isProvisional) {
      return AppPermissionStatus.granted;
    }
    if (s.isPermanentlyDenied || s.isRestricted) {
      return AppPermissionStatus.permanentlyDenied;
    }
    return AppPermissionStatus.denied;
  }

  @override
  Future<AppPermissionStatus> status(AppPermission permission) async =>
      _status(await _map(permission).status);

  @override
  Future<AppPermissionStatus> request(AppPermission permission) async =>
      _status(await _map(permission).request());

  @override
  Future<bool> openSystemSettings() => openAppSettings();
}
