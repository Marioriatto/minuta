import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../auth/auth_providers.dart';
import 'data/supabase_push_tokens_repository.dart';
import 'domain/push_gateway.dart';
import 'domain/push_tokens_repository.dart';
import 'domain/push_use_cases.dart';

/// Punto de composición de la feature (única conexión datos ↔ dominio).

/// Se sobrescribe en `main` con el gateway de Firebase si está configurado.
final pushGatewayProvider =
    Provider<PushGateway>((ref) => const NoPushGateway());

final pushTokensRepositoryProvider = Provider<PushTokensRepository>(
  (ref) => SupabasePushTokensRepository(ref.watch(supabaseClientProvider)),
);

final syncPushTokenProvider = Provider<SyncPushToken>(
  (ref) => SyncPushToken(
    ref.watch(pushGatewayProvider),
    ref.watch(pushTokensRepositoryProvider),
  ),
);

final unregisterPushTokenProvider = Provider<UnregisterPushToken>(
  (ref) => UnregisterPushToken(
    ref.watch(pushGatewayProvider),
    ref.watch(pushTokensRepositoryProvider),
  ),
);

/// Mantiene el token registrado mientras haya sesión: lo registra al entrar
/// y cuando FCM lo rota. Se activa vigilándolo desde la raíz de la app.
final pushRegistrationProvider = Provider<void>((ref) {
  final userId =
      ref.watch(authSnapshotProvider.select((s) => s.value?.user?.id));
  final gateway = ref.watch(pushGatewayProvider);
  if (userId == null || !gateway.isAvailable) return;

  final sync = ref.watch(syncPushTokenProvider);
  unawaited(sync());
  final sub = gateway.tokenRefreshes.listen((t) => unawaited(sync.refresh(t)));
  ref.onDispose(sub.cancel);
});

/// Toques en notificaciones de alerta (para abrir la pestaña Alertas).
final alertOpenedProvider = StreamProvider<void>(
  (ref) => ref.watch(pushGatewayProvider).alertOpened,
);
