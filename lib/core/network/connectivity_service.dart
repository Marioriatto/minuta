import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ojo: indica que hay interfaz de red, no que el backend sea alcanzable.
/// Los fallos reales de red siguen llegando como NetworkFailure.
abstract interface class ConnectivityService {
  Future<bool> isOnline();
  Stream<bool> watchOnline();
}

bool isOnlineFrom(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

class ConnectivityPlusService implements ConnectivityService {
  ConnectivityPlusService([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isOnline() async =>
      isOnlineFrom(await _connectivity.checkConnectivity());

  @override
  Stream<bool> watchOnline() =>
      _connectivity.onConnectivityChanged.map(isOnlineFrom).distinct();
}

final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityPlusService(),
);

final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final service = ref.watch(connectivityServiceProvider);
  yield await service.isOnline();
  yield* service.watchOnline();
});
