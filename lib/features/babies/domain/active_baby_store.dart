/// Guarda en el teléfono qué perfil está activo, por usuario.
abstract interface class ActiveBabyStore {
  Future<String?> read(String userId);
  Future<void> write(String userId, String? babyId);
}
