import 'package:shared_preferences/shared_preferences.dart';

import '../domain/permissions_intro_store.dart';

class SharedPrefsIntroStore implements PermissionsIntroStore {
  static const _key = 'permissions_intro_seen_v1';

  @override
  Future<bool> isSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  @override
  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
