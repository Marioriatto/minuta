/// Recuerda, por dispositivo, si ya se mostró la pantalla inicial de permisos.
abstract interface class PermissionsIntroStore {
  Future<bool> isSeen();
  Future<void> markSeen();
}
