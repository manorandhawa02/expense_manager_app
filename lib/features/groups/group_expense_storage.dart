import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class GroupExpenseStorage {
  static const String _storageKey = 'expense_manager_group_expenses';

  static Future<List<Map<String, dynamic>>> getExpenses(
    String groupId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString(_storageKey);

    if (savedData == null) return [];

    final List<dynamic> decoded = jsonDecode(savedData) as List<dynamic>;

    final expenses = decoded.map((item) {
      return Map<String, dynamic>.from(item as Map);
    }).toList();

    return expenses
        .where((expense) => expense['groupId']?.toString() == groupId)
        .toList();
  }

  static Future<void> addExpense({
    required String groupId,
    required String description,
    required double amount,
    required String paidBy,
    required List<String> sharedBy,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString(_storageKey);

    final List<Map<String, dynamic>> expenses;

    if (savedData == null) {
      expenses = [];
    } else {
      final List<dynamic> decoded = jsonDecode(savedData) as List<dynamic>;

      expenses = decoded.map((item) {
        return Map<String, dynamic>.from(item as Map);
      }).toList();
    }

    final expense = <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'groupId': groupId,
      'description': description.trim(),
      'amount': amount,
      'paidBy': paidBy,
      'sharedBy': sharedBy,
      'date': DateTime.now().toIso8601String(),
    };

    expenses.insert(0, expense);

    await prefs.setString(_storageKey, jsonEncode(expenses));
  }

  static Future<bool> deleteExpense(String expenseId) async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString(_storageKey);

    if (savedData == null) return false;

    final List<dynamic> decoded = jsonDecode(savedData) as List<dynamic>;

    final expenses = decoded.map((item) {
      return Map<String, dynamic>.from(item as Map);
    }).toList();

    final originalLength = expenses.length;

    expenses.removeWhere(
      (expense) => expense['id']?.toString() == expenseId,
    );

    if (expenses.length == originalLength) return false;

    await prefs.setString(_storageKey, jsonEncode(expenses));
    return true;
  }
}