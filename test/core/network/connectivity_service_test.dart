import 'package:colchon_minuta/core/network/connectivity_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isOnlineFrom', () {
    test('sin interfaces o solo none → offline', () {
      expect(isOnlineFrom(const []), isFalse);
      expect(isOnlineFrom(const [ConnectivityResult.none]), isFalse);
    });

    test('cualquier interfaz distinta de none → online', () {
      expect(isOnlineFrom(const [ConnectivityResult.wifi]), isTrue);
      expect(
        isOnlineFrom(const [ConnectivityResult.none, ConnectivityResult.mobile]),
        isTrue,
      );
    });
  });
}
