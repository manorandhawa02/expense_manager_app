
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class GroupSettlementStorage {
  static const String _storageKey = 'expense_manager_group_settlements';

  /// Returns all recorded settlements for a specific group.
  static Future<List<Map<String, dynamic>>> getSettlements(
    String groupId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString(_storageKey);

    if (savedData == null) return [];

    final List<dynamic> decoded = jsonDecode(savedData) as List<dynamic>;

    final settlements = decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    return settlements
        .where((item) => item['groupId']?.toString() == groupId)
        .toList();
  }

  /// Records a completed payment between two group members.
  static Future<void> addSettlement({
    required String groupId,
    required String paidBy,
    required String paidTo,
    required double amount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString(_storageKey);

    final List<Map<String, dynamic>> settlements;

    if (savedData == null) {
      settlements = [];
    } else {
      final List<dynamic> decoded = jsonDecode(savedData) as List<dynamic>;

      settlements = decoded
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    final settlement = <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'groupId': groupId,
      'paidBy': paidBy,
      'paidTo': paidTo,
      'amount': amount,
      'date': DateTime.now().toIso8601String(),
    };

    settlements.insert(0, settlement);

    await prefs.setString(
      _storageKey,
      jsonEncode(settlements),
    );
  }

  /// Deletes a recorded settlement by its ID.
  static Future<bool> deleteSettlement(String settlementId) async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString(_storageKey);

    if (savedData == null) return false;

    final List<dynamic> decoded = jsonDecode(savedData) as List<dynamic>;

    final settlements = decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    final originalLength = settlements.length;

    settlements.removeWhere(
      (item) => item['id']?.toString() == settlementId,
    );

    if (settlements.length == originalLength) return false;

    await prefs.setString(
      _storageKey,
      jsonEncode(settlements),
    );

    return true;
  }
}
