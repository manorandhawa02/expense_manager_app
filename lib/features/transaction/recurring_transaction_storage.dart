
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'transaction_storage.dart';

class RecurringTransactionStorage {
  static const String _storageKey =
      'expense_manager_recurring_transactions';

  static Future<List<Map<String, dynamic>>> getRecurringTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString(_storageKey);

    if (savedData == null) return [];

    final decoded = jsonDecode(savedData);

    if (decoded is! List) return [];

    return decoded.map((item) {
      return Map<String, dynamic>.from(item as Map);
    }).toList();
  }

  static Future<void> addRecurringTransaction(
    Map<String, dynamic> recurring,
  ) async {
    final rules = await getRecurringTransactions();

    final rule = <String, dynamic>{
      ...recurring,
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'enabled': recurring['enabled'] ?? true,
      'createdAt': DateTime.now().toIso8601String(),
      'lastProcessedDate': null,
    };

    rules.insert(0, rule);
    await _save(rules);
  }

  static Future<bool> updateRecurringTransaction(
    Map<String, dynamic> updated,
  ) async {
    final id = updated['id']?.toString();

    if (id == null || id.isEmpty) return false;

    final rules = await getRecurringTransactions();
    final index = rules.indexWhere(
      (rule) => rule['id']?.toString() == id,
    );

    if (index == -1) return false;

    rules[index] = {
      ...rules[index],
      ...updated,
      'id': id,
    };

    await _save(rules);
    return true;
  }

  static Future<bool> deleteRecurringTransaction(String id) async {
    final rules = await getRecurringTransactions();
    final previousLength = rules.length;

    rules.removeWhere((rule) => rule['id']?.toString() == id);

    if (rules.length == previousLength) return false;

    await _save(rules);
    return true;
  }

  static Future<void> setEnabled(String id, bool enabled) async {
    final rules = await getRecurringTransactions();
    final index = rules.indexWhere(
      (rule) => rule['id']?.toString() == id,
    );

    if (index == -1) return;

    rules[index]['enabled'] = enabled;
    await _save(rules);
  }

  /// Creates due transactions and records the processed date.
  ///
  /// Reprocessing the same scheduled date will not create a duplicate.
  static Future<int> processDueTransactions() async {
    final rules = await getRecurringTransactions();
    final today = _dateOnly(DateTime.now());
    var createdCount = 0;
    var changed = false;

    for (var i = 0; i < rules.length; i++) {
      final rule = rules[i];

      if (rule['enabled'] != true) continue;

      final start = DateTime.tryParse(
        rule['startDate']?.toString() ?? '',
      );
      if (start == null) continue;

      final endValue = rule['endDate']?.toString();
      final end = endValue == null || endValue.isEmpty
          ? null
          : DateTime.tryParse(endValue);

      var due = _dateOnly(start);
      final lastProcessedValue =
          rule['lastProcessedDate']?.toString();

      if (lastProcessedValue != null &&
          lastProcessedValue.isNotEmpty) {
        final lastProcessed = DateTime.tryParse(lastProcessedValue);

        if (lastProcessed != null) {
          final lastDate = _dateOnly(lastProcessed);
          if (!lastDate.isBefore(today)) continue;

          due = _nextDate(
            lastDate,
            rule['frequency']?.toString() ?? 'Monthly',
          );
        }
      }

      var iterations = 0;

      while (!due.isAfter(today) &&
          (end == null || !due.isAfter(_dateOnly(end))) &&
          iterations < 1200) {
        final dueKey = due.toIso8601String();

        // A unique marker on each rule prevents duplicate creation
        // when this same scheduled date is processed again.
        final transaction = <String, dynamic>{
          'title': rule['title']?.toString() ?? 'Recurring transaction',
          'category': rule['category']?.toString() ?? 'Other',
          'date': dueKey,
          'amount': rule['amount'] is num
              ? (rule['amount'] as num).toDouble()
              : double.tryParse(rule['amount']?.toString() ?? '') ?? 0.0,
          'type': rule['type']?.toString() ?? 'Expense',
          'paymentMethod': rule['paymentMethod']?.toString() ?? 'Cash',
          'notes': rule['notes']?.toString() ?? '',
          'recurringRuleId': rule['id']?.toString(),
          'recurringDueDate': dueKey,
        };

        final existing = await TransactionStorage.getTransactions();

        final alreadyCreated = existing.any((item) =>
            item['recurringRuleId']?.toString() ==
                rule['id']?.toString() &&
            item['recurringDueDate']?.toString() == dueKey);

        if (!alreadyCreated) {
          await TransactionStorage.addTransaction(transaction);
          createdCount++;
        }

        rule['lastProcessedDate'] = dueKey;
        changed = true;
        due = _nextDate(
          due,
          rule['frequency']?.toString() ?? 'Monthly',
        );
        iterations++;
      }

      if (end != null && due.isAfter(_dateOnly(end))) {
        rule['enabled'] = false;
        changed = true;
      }

      rules[i] = rule;
    }

    if (changed) {
      await _save(rules);
    }

    return createdCount;
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime _nextDate(DateTime date, String frequency) {
    switch (frequency) {
      case 'Weekly':
        return date.add(const Duration(days: 7));
      case 'Yearly':
        return _addMonths(date, 12);
      case 'Monthly':
      default:
        return _addMonths(date, 1);
    }
  }

  static DateTime _addMonths(DateTime date, int months) {
    final totalMonths = date.year * 12 + date.month - 1 + months;
    final year = totalMonths ~/ 12;
    final month = totalMonths % 12 + 1;

    final lastDay = DateTime(year, month + 1, 0).day;
    final day = date.day > lastDay ? lastDay : date.day;

    return DateTime(year, month, day);
  }

  static Future<void> _save(
    List<Map<String, dynamic>> rules,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(rules));
  }

  static Future<void> clearRecurringTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
