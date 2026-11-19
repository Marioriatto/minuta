import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../auth/auth_providers.dart';
import '../babies/babies_providers.dart';
import '../devices/devices_providers.dart';
import 'data/dashboard_remote_source.dart';
import 'data/dashboard_repository_impl.dart';
import 'domain/dashboard_models.dart';
import 'domain/dashboard_repository.dart';
import 'domain/dashboard_use_cases.dart';
import 'domain/home_modules.dart';

/// Punto de composición de la feature (única conexión datos ↔ dominio).

final dashboardRemoteProvider = Provider<DashboardRemoteSource>(
  (ref) => SupabaseDashboardRemoteSource(ref.watch(supabaseClientProvider)),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepositoryImpl(ref.watch(dashboardRemoteProvider)),
);

final loadDashboardHistoryProvider = Provider<LoadDashboardHistory>(
  (ref) => LoadDashboardHistory(ref.watch(dashboardRepositoryProvider)),
);

final loadRecentActivityProvider = Provider<LoadRecentActivity>(
  (ref) => LoadRecentActivity(ref.watch(dashboardRepositoryProvider)),
);

String? _userId(Ref ref) =>
    ref.watch(authSnapshotProvider.select((s) => s.value?.user?.id));

String? _activeBabyId(Ref ref) =>
    ref.watch(activeBabyProvider.select((b) => b?.id));

/// Resumen de módulos para el inicio, derivado de la lista en vivo.
final homeModulesProvider = Provider<AsyncValue<HomeModules>>(
  (ref) => ref.watch(devicesProvider).whenData(HomeModules.from),
);

/// Gráficas del inicio. Se recalcula al cambiar de usuario o de bebé activo;
/// "deslizar para actualizar" lo invalida.
final dashboardHistoryProvider =
    FutureProvider.autoDispose<DashboardHistory>((ref) async {
  if (_userId(ref) == null) return const DashboardHistory();
  final result =
      await ref.watch(loadDashboardHistoryProvider)(babyId: _activeBabyId(ref));
  return result.when(ok: (h) => h, err: (f) => throw f);
});

/// Actividad reciente del inicio.
final recentActivityProvider =
    FutureProvider.autoDispose<List<ActivityEvent>>((ref) async {
  if (_userId(ref) == null) return const [];
  final result =
      await ref.watch(loadRecentActivityProvider)(babyId: _activeBabyId(ref));
  return result.when(ok: (e) => e, err: (f) => throw f);
});
