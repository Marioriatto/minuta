import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/result.dart';
import '../../babies_providers.dart';
import '../../domain/baby.dart';

enum BabyAction { archived, restored, deleted, weighed }

@immutable
class BabiesActionsState {
  const BabiesActionsState({this.busyId, this.failure, this.done});

  /// Perfil sobre el que hay una operación en curso.
  final String? busyId;
  final AppFailure? failure;

  /// Última operación terminada con éxito (para avisar al usuario).
  final BabyAction? done;
}

/// Archivar, restaurar, eliminar, pesar y elegir el perfil activo.
class BabiesActionsController extends Notifier<BabiesActionsState> {
  bool _disposed = false;

  @override
  BabiesActionsState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const BabiesActionsState();
  }

  Future<void> setActive(Baby baby) =>
      ref.read(activeBabyIdProvider.notifier).select(baby.id);

  Future<void> archive(Baby baby) async {
    final current = ref.read(babiesProvider).value ?? const <Baby>[];
    state = BabiesActionsState(busyId: baby.id);
    final result = await ref.read(archiveBabyProvider)(
      id: baby.id,
      current: current,
    );
    _finishWithBaby(result, BabyAction.archived);
  }

  Future<void> restore(Baby baby) async {
    state = BabiesActionsState(busyId: baby.id);
    final result = await ref.read(restoreBabyProvider)(baby.id);
    _finishWithBaby(result, BabyAction.restored);
  }

  /// "Pesar ahora": guarda el peso que mide el colchón (RF-11).
  Future<void> weigh(Baby baby) async {
    state = BabiesActionsState(busyId: baby.id);
    final result = await ref.read(weighBabyProvider)(baby);
    _finishWithBaby(result, BabyAction.weighed);
  }

  Future<void> delete(Baby baby) async {
    state = BabiesActionsState(busyId: baby.id);
    final result = await ref.read(deleteBabyProvider)(baby.id);
    if (_disposed) return;
    result.when(
      ok: (_) {
        ref.read(babiesProvider.notifier).remove(baby.id);
        state = const BabiesActionsState(done: BabyAction.deleted);
      },
      err: (failure) => state = BabiesActionsState(failure: failure),
    );
  }

  void _finishWithBaby(Result<Baby> result, BabyAction action) {
    if (_disposed) return;
    result.when(
      ok: (baby) {
        ref.read(babiesProvider.notifier).upsert(baby);
        state = BabiesActionsState(done: action);
      },
      err: (failure) => state = BabiesActionsState(failure: failure),
    );
  }
}

final babiesActionsControllerProvider =
    NotifierProvider<BabiesActionsController, BabiesActionsState>(
  BabiesActionsController.new,
);
