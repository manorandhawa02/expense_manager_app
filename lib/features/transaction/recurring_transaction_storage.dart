
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'transaction_storage.dart';

class RecurringTransactionStorage {
  static const String _storageKey =
      'expense_manager_recurring_transactions';

  static const int _maxOccurrencesPerRun = 1200;

  static Future<List<Map<String, dynamic>>>
      getRecurringTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString(_storageKey);

    if (savedData == null || savedData.isEmpty) return [];

    try {
      final decoded = jsonDecode(savedData);

      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    }
  }

  static Future<void> addRecurringTransaction(
    Map<String, dynamic> recurring,
  ) async {
    final rules = await getRecurringTransactions();
    final now = DateTime.now();

    final rule = <String, dynamic>{
      ...recurring,
      'id': now.microsecondsSinceEpoch.toString(),
      'enabled': recurring['enabled'] ?? true,
      'createdAt': now.toIso8601String(),
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

    final oldRule = rules[index];

    final scheduleChanged =
        _dateOnly(_parseDate(oldRule['startDate']) ?? DateTime(2000))
                .toIso8601String() !=
            (_parseDate(updated['startDate']) == null
                ? ''
                : _dateOnly(_parseDate(updated['startDate'])!)
                    .toIso8601String()) ||
        oldRule['frequency'] != updated['frequency'];

    rules[index] = {
      ...oldRule,
      ...updated,
      'id': id,
      // Reset progress if the schedule itself changes.
      if (scheduleChanged) 'lastProcessedDate': null,
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

  /// Creates due transactions when this method is called.
  ///
  /// A newly created rule starts processing from its start date,
  /// but never creates occurrences dated before today.
  /// Existing transaction markers prevent normal repeat processing.
  static Future<int> processDueTransactions() async {
    final rules = await getRecurringTransactions();
    final today = _dateOnly(DateTime.now());

    var createdCount = 0;
    var changed = false;

    // Read transactions once before processing the rules.
    final existingTransactions =
        await TransactionStorage.getTransactions();

    for (var i = 0; i < rules.length; i++) {
      final rule = rules[i];

      if (rule['enabled'] != true) continue;

      final start = _parseDate(rule['startDate']);
      if (start == null) continue;

      final startDate = _dateOnly(start);
      final end = _parseDate(rule['endDate']);
      final endDate = end == null ? null : _dateOnly(end);

      if (endDate != null && endDate.isBefore(startDate)) {
        rule['enabled'] = false;
        changed = true;
        rules[i] = rule;
        continue;
      }

      // If the rule has not yet started, do nothing.
      if (startDate.isAfter(today)) continue;

      var lastProcessed = _parseDate(rule['lastProcessedDate']);

      // Start from today for a new rule to avoid backfilling years
      // of historical transactions.
      DateTime due;

      if (lastProcessed == null) {
        due = _firstOccurrenceOnOrAfter(
          startDate,
          today,
          rule['frequency']?.toString() ?? 'Monthly',
        );
      } else {
        final lastDate = _dateOnly(lastProcessed);

        // Do not process the same or an earlier day again.
        if (!lastDate.isBefore(today)) continue;

        due = _nextOccurrence(
          startDate,
          lastDate,
          rule['frequency']?.toString() ?? 'Monthly',
        );
      }

      var iterations = 0;

      while (!due.isAfter(today) &&
          (endDate == null || !due.isAfter(endDate)) &&
          iterations < _maxOccurrencesPerRun) {
        final dueKey = due.toIso8601String();
        final ruleId = rule['id']?.toString();

        final alreadyCreated = existingTransactions.any((transaction) =>
            transaction['recurringRuleId']?.toString() == ruleId &&
            transaction['recurringDueDate']?.toString() == dueKey);

        if (!alreadyCreated) {
          final rawAmount = rule['amount'];
          final amount = rawAmount is num
              ? rawAmount.toDouble()
              : double.tryParse(rawAmount?.toString() ?? '') ?? 0.0;

          if (amount > 0 && amount.isFinite) {
            final transaction = <String, dynamic>{
              'title':
                  rule['title']?.toString() ?? 'Recurring transaction',
              'category': rule['category']?.toString() ?? 'Other',
              'date': dueKey,
              'amount': amount,
              'type': rule['type']?.toString() ?? 'Expense',
              'paymentMethod':
                  rule['paymentMethod']?.toString() ?? 'Cash',
              'notes': rule['notes']?.toString() ?? '',
              'recurringRuleId': ruleId,
              'recurringDueDate': dueKey,
            };

            await TransactionStorage.addTransaction(transaction);

            // Track newly created markers during this run too.
            existingTransactions.add(transaction);
            createdCount++;
          }
        }

        rule['lastProcessedDate'] = dueKey;
        changed = true;

        due = _nextOccurrence(
          startDate,
          due,
          rule['frequency']?.toString() ?? 'Monthly',
        );

        iterations++;
      }

      if (endDate != null && due.isAfter(endDate)) {
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

  static DateTime _firstOccurrenceOnOrAfter(
    DateTime start,
    DateTime target,
    String frequency,
  ) {
    final startDate = _dateOnly(start);
    final targetDate = _dateOnly(target);

    if (!startDate.isBefore(targetDate)) return startDate;

    var occurrence = startDate;
    var iterations = 0;

    while (occurrence.isBefore(targetDate) &&
        iterations < _maxOccurrencesPerRun) {
      occurrence = _nextOccurrence(startDate, occurrence, frequency);
      iterations++;
    }

    return occurrence;
  }

  /// Computes each occurrence from the original start date.
  /// This prevents Jan 31 -> Feb 28 -> Mar 28 date drift.
  static DateTime _nextOccurrence(
    DateTime originalStart,
    DateTime currentOccurrence,
    String frequency,
  ) {
    switch (frequency) {
      case 'Weekly':
        return currentOccurrence.add(const Duration(days: 7));

      case 'Yearly':
        return _dateInMonth(
          originalStart.year + _yearOffset(originalStart, currentOccurrence) + 1,
          originalStart.month,
          originalStart.day,
        );

      case 'Monthly':
      default:
        final monthDifference =
            (currentOccurrence.year - originalStart.year) * 12 +
            currentOccurrence.month -
            originalStart.month;

        return _dateInMonth(
          originalStart.year +
              (originalStart.month - 1 + monthDifference + 1) ~/ 12,
          (originalStart.month - 1 + monthDifference + 1) % 12 + 1,
          originalStart.day,
        );
    }
  }

  static int _yearOffset(DateTime start, DateTime current) {
    return current.year - start.year;
  }

  static DateTime _dateInMonth(int year, int month, int desiredDay) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(
      year,
      month,
      desiredDay > lastDay ? lastDay : desiredDay,
    );
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
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
