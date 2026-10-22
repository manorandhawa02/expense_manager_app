import 'package:shared_preferences/shared_preferences.dart';

class ProfileStorage {
  static const String _nameKey = 'expense_manager_profile_name';

  static Future<String> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nameKey) ?? 'Mano';
  }

  static Future<void> saveName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name.trim());
  }
}