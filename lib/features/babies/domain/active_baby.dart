import 'baby.dart';

/// Perfil activo: el guardado si sigue activo; si no, el más antiguo.
Baby? resolveActiveBaby(List<Baby> babies, String? storedId) {
  final active = babies.where((b) => !b.isArchived).toList();
  if (active.isEmpty) return null;
  for (final b in active) {
    if (b.id == storedId) return b;
  }
  active.sort((a, b) => a.registeredAt.compareTo(b.registeredAt));
  return active.first;
}
