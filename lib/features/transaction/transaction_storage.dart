
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../budgets/budget_alert_service.dart';

class TransactionStorage {
  static const String _storageKey = 'expense_manager_transactions';

  static Future<List<Map<String, dynamic>>> getTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString(_storageKey);

    if (savedData == null) return [];

    final List<dynamic> decoded = jsonDecode(savedData) as List<dynamic>;

    return decoded.map((item) {
      return Map<String, dynamic>.from(item as Map);
    }).toList();
  }

  static Future<void> addTransaction(
    Map<String, dynamic> transaction,
  ) async {
    final transactions = await getTransactions();

    final newTransaction = <String, dynamic>{
      ...transaction,
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'date': (transaction['date'] ?? DateTime.now().toIso8601String())
          .toString(),
    };

    transactions.insert(0, newTransaction);

    await _saveTransactions(transactions);
    await _checkBudgetAlertsSafely(transactions);
  }

  // Check budget alerts without interrupting transaction operations.
  static Future<void> _checkBudgetAlertsSafely(
    List<Map<String, dynamic>> transactions,
  ) async {
    try {
      await BudgetAlertService.checkBudgets(transactions);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        print('Budget alert check failed: $error');
      }
      if (kDebugMode) {
        print(stackTrace);
      }
    }
  }

  // Update an existing transaction without changing its ID.
  static Future<bool> updateTransaction(
    Map<String, dynamic> updatedTransaction,
  ) async {
    final id = updatedTransaction['id']?.toString();

    if (id == null || id.isEmpty) return false;

    final transactions = await getTransactions();

    final index = transactions.indexWhere(
      (transaction) => transaction['id']?.toString() == id,
    );

    if (index == -1) return false;

    transactions[index] = {
      ...transactions[index],
      ...updatedTransaction,
      'id': id,
    };

    await _saveTransactions(transactions);
    await _checkBudgetAlertsSafely(transactions);

    return true;
  }

  // Delete a transaction using its unique ID.
  static Future<bool> deleteTransaction(String id) async {
    final transactions = await getTransactions();
    final originalLength = transactions.length;

    transactions.removeWhere(
      (transaction) => transaction['id']?.toString() == id,
    );

    if (transactions.length == originalLength) {
      return false;
    }

    await _saveTransactions(transactions);
    await _checkBudgetAlertsSafely(transactions);

    return true;
  }

  static Future<void> _saveTransactions(
    List<Map<String, dynamic>> transactions,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _storageKey,
      jsonEncode(transactions),
    );
  }

  static Future<void> clearTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
