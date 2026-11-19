import 'app_permission.dart';

abstract interface class PermissionsGateway {
  Future<AppPermissionStatus> status(AppPermission permission);
  Future<AppPermissionStatus> request(AppPermission permission);
  Future<bool> openSystemSettings();
}
