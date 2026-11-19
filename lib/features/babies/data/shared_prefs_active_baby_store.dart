import 'package:shared_preferences/shared_preferences.dart';

import '../domain/active_baby_store.dart';

class SharedPrefsActiveBabyStore implements ActiveBabyStore {
  String _key(String userId) => 'active_baby_id_v1_$userId';

  @override
  Future<String?> read(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(userId));
  }

  @override
  Future<void> write(String userId, String? babyId) async {
    final prefs = await SharedPreferences.getInstance();
    if (babyId == null) {
      await prefs.remove(_key(userId));
    } else {
      await prefs.setString(_key(userId), babyId);
    }
  }
}
