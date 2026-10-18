import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class GroupStorage {
  static const String _storageKey = 'expense_manager_groups';

  static Future<List<Map<String, dynamic>>> getGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString(_storageKey);

    if (savedData == null) return [];

    final List<dynamic> decoded = jsonDecode(savedData) as List<dynamic>;

    return decoded.map((item) {
      return Map<String, dynamic>.from(item as Map);
    }).toList();
  }

  static Future<void> addGroup({
    required String name,
    required List<String> members,
  }) async {
    final groups = await getGroups();

    final newGroup = <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'name': name.trim(),
      'members': members,
      'createdAt': DateTime.now().toIso8601String(),
    };

    groups.insert(0, newGroup);

    await _saveGroups(groups);
  }

  static Future<bool> deleteGroup(String id) async {
    final groups = await getGroups();
    final originalLength = groups.length;

    groups.removeWhere(
      (group) => group['id']?.toString() == id,
    );

    if (groups.length == originalLength) return false;

    await _saveGroups(groups);
    return true;
  }

  static Future<void> _saveGroups(
    List<Map<String, dynamic>> groups,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _storageKey,
      jsonEncode(groups),
    );
  }
}