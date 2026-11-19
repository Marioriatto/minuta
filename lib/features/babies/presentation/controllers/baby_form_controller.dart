import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../babies_providers.dart';
import '../../domain/baby_validators.dart';

@immutable
class BabyFormState {
  const BabyFormState({
    this.busy = false,
    this.nameError,
    this.birthError,
    this.failure,
    this.completed = false,
  });

  final bool busy;
  final BabyFieldError? nameError;
  final BabyFieldError? birthError;
  final AppFailure? failure;
  final bool completed;
}

class BabyFormController extends Notifier<BabyFormState> {
  bool _disposed = false;

  @override
  BabyFormState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const BabyFormState();
  }

  /// Crea un perfil (si [babyId] es nulo) o modifica el existente.
  /// El peso no se pide: lo mide el colchón con "Pesar ahora".
  Future<void> submit({
    required String name,
    required DateTime? birth,
    String? babyId,
  }) async {
    final today = DateTime.now();
    final nameError = BabyValidators.name(name);
    final birthError = BabyValidators.birth(birth, today: today);
    if (nameError != null || birthError != null) {
      state = BabyFormState(nameError: nameError, birthError: birthError);
      return;
    }

    state = const BabyFormState(busy: true);
    final result = babyId == null
        ? await ref.read(createBabyProvider)(name: name, birth: birth)
        : await ref.read(updateBabyProvider)(
            id: babyId,
            name: name,
            birth: birth,
          );
    if (_disposed) return;

    result.when(
      ok: (baby) {
        final hadNoActive = ref.read(activeBabiesProvider).isEmpty;
        ref.read(babiesProvider.notifier).upsert(baby);
        if (babyId == null && hadNoActive) {
          unawaited(ref.read(activeBabyIdProvider.notifier).select(baby.id));
        }
        state = const BabyFormState(completed: true);
      },
      err: (failure) => state = BabyFormState(failure: failure),
    );
  }
}

final babyFormControllerProvider =
    NotifierProvider<BabyFormController, BabyFormState>(BabyFormController.new);
