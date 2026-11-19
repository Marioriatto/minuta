import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/app_permission.dart';
import '../permissions_providers.dart';

@immutable
class PermissionsIntroState {
  const PermissionsIntroState({
    this.notifications = true,
    this.microphone = true,
    this.busy = false,
    this.failure,
  });

  final bool notifications;
  final bool microphone;
  final bool busy;
  final AppFailure? failure;
}

class PermissionsIntroController extends Notifier<PermissionsIntroState> {
  bool _disposed = false;

  @override
  PermissionsIntroState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const PermissionsIntroState();
  }

  void setNotifications(bool value) => state = PermissionsIntroState(
        notifications: value,
        microphone: state.microphone,
      );

  void setMicrophone(bool value) => state = PermissionsIntroState(
        notifications: state.notifications,
        microphone: value,
      );

  Future<void> submit() async {
    final selected = {
      if (state.notifications) AppPermission.notifications,
      if (state.microphone) AppPermission.microphone,
    };
    state = PermissionsIntroState(
      notifications: state.notifications,
      microphone: state.microphone,
      busy: true,
    );
    final result =
        await ref.read(completePermissionsIntroProvider)(selected: selected);
    if (_disposed) return;
    result.when(
      ok: (_) {
        // El router sale de esta pantalla al cambiar el estado.
        ref.read(permissionsIntroSeenProvider.notifier).acknowledged();
      },
      err: (failure) => state = PermissionsIntroState(
        notifications: state.notifications,
        microphone: state.microphone,
        failure: failure,
      ),
    );
  }
}

final permissionsIntroControllerProvider =
    NotifierProvider<PermissionsIntroController, PermissionsIntroState>(
  PermissionsIntroController.new,
);
