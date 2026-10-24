
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupService {
  static const String appId = 'expense_manager';
  static const int formatVersion = 1;

  // Export all app preferences, including transactions,
  // budgets, groups, profile, theme, and currency settings.
  static Future<Map<String, dynamic>> buildBackup() async {
    final prefs = await SharedPreferences.getInstance();

    final values = <String, dynamic>{};

    for (final key in prefs.getKeys()) {
      if (key.startsWith('expense_manager_')) {
        values[key] = prefs.get(key);
      }
    }

    return {
      'app': appId,
      'formatVersion': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': values,
    };
  }

  static String _timestamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');

    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  static Future<File> exportBackup() async {
    final directory = await getTemporaryDirectory();

    final file = File(
      '${directory.path}/expense_manager_backup_${_timestamp()}.json',
    );

    await file.writeAsString(
      jsonEncode(await buildBackup()),
    );

    return file;
  }

  static Future<File> exportTransactionsCsv() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('expense_manager_transactions');

    final List<dynamic> transactions =
        raw == null ? [] : jsonDecode(raw) as List<dynamic>;

    String csvCell(Object? value) {
      final text = value?.toString() ?? '';
      return '"${text.replaceAll('"', '""')}"';
    }

    final rows = <List<Object?>>[
      [
        'Date',
        'Type',
        'Title',
        'Amount',
        'Category',
        'Payment Method',
        'Note',
      ],
      for (final item in transactions)
        [
          item['date'],
          item['type'],
          item['title'],
          item['amount'],
          item['category'],
          item['paymentMethod'],
          item['note'],
        ],
    ];

    final csv = rows
        .map((row) => row.map(csvCell).join(','))
        .join('\r\n');

    final directory = await getTemporaryDirectory();

    final file = File(
      '${directory.path}/expense_manager_transactions_${_timestamp()}.csv',
    );

    // UTF-8 BOM improves compatibility with Excel.
    await file.writeAsBytes(
      [0xEF, 0xBB, 0xBF, ...utf8.encode(csv)],
    );

    return file;
  }

  // Restores only this app's prefixed keys.
  // The caller must confirm before invoking this method.
  static Future<void> restoreBackup(String content) async {
    final Map<String, dynamic> root;

    try {
      root = Map<String, dynamic>.from(
        jsonDecode(content) as Map,
      );
    } catch (_) {
      throw const FormatException('Invalid backup file.');
    }

    if (root['app'] != appId ||
        root['formatVersion'] != formatVersion ||
        root['data'] is! Map) {
      throw const FormatException(
        'Unsupported or invalid Expense Manager backup.',
      );
    }

    final data = Map<String, dynamic>.from(root['data'] as Map);

    // Validate the entire payload before changing any preferences.
    for (final entry in data.entries) {
      if (!entry.key.startsWith('expense_manager_')) {
        throw const FormatException(
          'Backup contains an unexpected setting.',
        );
      }

      final value = entry.value;

      if (value != null &&
          value is! String &&
          value is! bool &&
          value is! int &&
          value is! double &&
          value is! List<String>) {
        throw const FormatException(
          'Backup contains an unsupported value.',
        );
      }
    }

    final prefs = await SharedPreferences.getInstance();

    // Preserve a safety copy before restoring.
    final safetyFile = await exportBackup();
    debugPrint('Safety backup created: ${safetyFile.path}');

    final existingKeys = prefs.getKeys()
        .where((key) => key.startsWith('expense_manager_'))
        .toList();

    for (final key in existingKeys) {
      await prefs.remove(key);
    }

    for (final entry in data.entries) {
      final value = entry.value;

      if (value == null) {
        await prefs.remove(entry.key);
      } else if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is bool) {
        await prefs.setBool(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else if (value is double) {
        await prefs.setDouble(entry.key, value);
      } else if (value is List<String>) {
        await prefs.setStringList(entry.key, value);
      }
    }
  }
}
