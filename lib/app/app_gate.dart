import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_providers.dart';
import '../features/auth/domain/auth_snapshot.dart';
import '../features/babies/babies_providers.dart';
import '../features/permissions/permissions_providers.dart';

/// Estado global que decide en qué zona de la app está el usuario.
enum AppGate {
  loading,
  signedOut,
  recovery,
  needsPermissionsIntro,
  needsFirstProfile,
  profilesError,
  ready,
}

/// Combina la sesión de Supabase, la introducción de permisos y los perfiles. Está en la raíz
/// de la app porque depende de varias features.
final appGateProvider = Provider<AppGate>((ref) {
  final snapshot = ref.watch(authSnapshotProvider);
  return snapshot.when(
    loading: () => AppGate.loading,
    error: (_, __) => AppGate.signedOut,
    data: (s) => switch (s.event) {
      AuthEvent.signedOut => AppGate.signedOut,
      AuthEvent.passwordRecovery => AppGate.recovery,
      AuthEvent.signedIn => ref.watch(permissionsIntroSeenProvider).when(
            loading: () => AppGate.loading,
            // Si el almacenamiento local falla, no se bloquea al usuario.
            error: (_, __) => AppGate.ready,
            data: (seen) =>
                seen ? _profilesGate(ref) : AppGate.needsPermissionsIntro,
          ),
    },
  );
});

/// Sin al menos un perfil activo no hay dónde clasificar los datos (DB-001).
AppGate _profilesGate(Ref ref) {
  final babies = ref.watch(babiesProvider);
  // Primero `isLoading`: durante un reintento conserva el error anterior.
  if (babies.isLoading) return AppGate.loading;
  if (babies.hasError) return AppGate.profilesError;
  final hasActive = (babies.value ?? const []).any((b) => !b.isArchived);
  return hasActive ? AppGate.ready : AppGate.needsFirstProfile;
}
