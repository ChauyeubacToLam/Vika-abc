import 'package:shared_preferences/shared_preferences.dart';

import 'debug_types.dart';

class DebugPreferences {
  static const String key = 'vika_debug_mode';

  const DebugPreferences._();

  static Future<DebugMode> loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    return DebugModeCodec.fromStorage(prefs.getString(key));
  }

  static Future<void> saveMode(DebugMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, mode.storageValue);
  }
}
