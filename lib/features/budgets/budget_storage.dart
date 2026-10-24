import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class BudgetStorage {
  static const String _key = 'expense_manager_budgets_v1';

  static Future<List<Map<String, dynamic>>> getBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);

    if (raw == null) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveBudget({
    required String category,
    required double limitPkr,
    required int alertThresholdPct,
  }) async {
    final budgets = await getBudgets();

    final existingIndex = budgets.indexWhere(
      (b) => (b['category']?.toString() ?? '') == category,
    );

    final budget = <String, dynamic>{
      'category': category,
      'limitPkr': limitPkr,
      'alertThresholdPct': alertThresholdPct,
    };

    if (existingIndex >= 0) {
      budgets[existingIndex] = budget;
    } else {
      budgets.add(budget);
    }

    await _save(budgets);
  }

  static Future<void> deleteBudget(String category) async {
    final budgets = await getBudgets();
    budgets.removeWhere((b) => (b['category']?.toString() ?? '') == category);
    await _save(budgets);
  }

  static Future<void> _save(List<Map<String, dynamic>> budgets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(budgets));
  }
}
