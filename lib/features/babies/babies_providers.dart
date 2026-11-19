import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../auth/auth_providers.dart';
import 'data/babies_remote_source.dart';
import 'data/babies_repository_impl.dart';
import 'data/shared_prefs_active_baby_store.dart';
import 'domain/active_baby.dart';
import 'domain/active_baby_store.dart';
import 'domain/babies_repository.dart';
import 'domain/babies_use_cases.dart';
import 'domain/baby.dart';

/// Punto de composición de la feature (única conexión datos ↔ dominio).

final babiesRemoteProvider = Provider<BabiesRemoteSource>(
  (ref) => SupabaseBabiesRemoteSource(ref.watch(supabaseClientProvider)),
);

final babiesRepositoryProvider = Provider<BabiesRepository>(
  (ref) => BabiesRepositoryImpl(ref.watch(babiesRemoteProvider)),
);

final activeBabyStoreProvider = Provider<ActiveBabyStore>(
  (ref) => SharedPrefsActiveBabyStore(),
);

final listBabiesProvider = Provider<ListBabies>(
  (ref) => ListBabies(ref.watch(babiesRepositoryProvider)),
);
final createBabyProvider = Provider<CreateBaby>(
  (ref) => CreateBaby(ref.watch(babiesRepositoryProvider)),
);
final updateBabyProvider = Provider<UpdateBaby>(
  (ref) => UpdateBaby(ref.watch(babiesRepositoryProvider)),
);
final archiveBabyProvider = Provider<ArchiveBaby>(
  (ref) => ArchiveBaby(ref.watch(babiesRepositoryProvider)),
);
final restoreBabyProvider = Provider<RestoreBaby>(
  (ref) => RestoreBaby(ref.watch(babiesRepositoryProvider)),
);
final deleteBabyProvider = Provider<DeleteBaby>(
  (ref) => DeleteBaby(ref.watch(babiesRepositoryProvider)),
);
final weighBabyProvider = Provider<WeighBaby>(
  (ref) => WeighBaby(ref.watch(babiesRepositoryProvider)),
);

String? _userId(Ref ref) =>
    ref.watch(authSnapshotProvider.select((s) => s.value?.user?.id));

/// Todos los perfiles del usuario (activos y archivados). Se reconstruye al
/// cambiar de usuario; las altas/ediciones se aplican localmente con
/// [upsert]/[remove] tras confirmarlas el servidor.
class BabiesNotifier extends AsyncNotifier<List<Baby>> {
  @override
  Future<List<Baby>> build() async {
    final userId = _userId(ref);
    if (userId == null) return const [];
    final result = await ref.watch(listBabiesProvider)();
    return result.when(ok: (babies) => babies, err: (failure) => throw failure);
  }

  void upsert(Baby baby) {
    final current = [...?state.value];
    final index = current.indexWhere((b) => b.id == baby.id);
    if (index >= 0) {
      current[index] = baby;
    } else {
      current.add(baby);
    }
    state = AsyncData(current);
  }

  void remove(String id) {
    state = AsyncData([...?state.value]..removeWhere((b) => b.id == id));
  }
}

final babiesProvider =
    AsyncNotifierProvider<BabiesNotifier, List<Baby>>(BabiesNotifier.new);

final activeBabiesProvider = Provider<List<Baby>>(
  (ref) => [
    for (final b in ref.watch(babiesProvider).value ?? const <Baby>[])
      if (!b.isArchived) b,
  ],
);

final archivedBabiesProvider = Provider<List<Baby>>(
  (ref) => [
    for (final b in ref.watch(babiesProvider).value ?? const <Baby>[])
      if (b.isArchived) b,
  ],
);

/// Id del perfil activo elegido por el usuario (guardado en el teléfono).
class ActiveBabyIdNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final userId = _userId(ref);
    if (userId == null) return null;
    return ref.watch(activeBabyStoreProvider).read(userId);
  }

  Future<void> select(String? babyId) async {
    final userId = ref.read(authSnapshotProvider).value?.user?.id;
    if (userId == null) return;
    await ref.read(activeBabyStoreProvider).write(userId, babyId);
    state = AsyncData(babyId);
  }
}

final activeBabyIdProvider =
    AsyncNotifierProvider<ActiveBabyIdNotifier, String?>(
  ActiveBabyIdNotifier.new,
);

/// Perfil con el que se muestran los datos en todas las secciones (DB-001).
/// `null` solo si no hay ningún perfil activo.
final activeBabyProvider = Provider<Baby?>(
  (ref) => resolveActiveBaby(
    ref.watch(babiesProvider).value ?? const <Baby>[],
    ref.watch(activeBabyIdProvider).value,
  ),
);
