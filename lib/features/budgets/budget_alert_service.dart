
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/notifications/notification_service.dart';
import 'budget_storage.dart';

class BudgetAlertService {
  BudgetAlertService._();

  static Future<void> checkBudgets(
    List<Map<String, dynamic>> transactions,
  ) async {
    final now = DateTime.now();

    final budgets = await BudgetStorage.getBudgets();
    final prefs = await SharedPreferences.getInstance();

    for (final budget in budgets) {
      final category = budget['category']?.toString() ?? 'All';
      final limit = (budget['limitPkr'] as num?)?.toDouble() ?? 0;
      final threshold =
          (budget['alertThresholdPct'] as num?)?.toInt() ?? 80;

      if (limit <= 0 || threshold <= 0) continue;

      final spent = transactions.fold<double>(0, (total, transaction) {
        if (transaction['type'] != 'Expense') return total;

        final date = DateTime.tryParse(
          transaction['date']?.toString() ?? '',
        );

        if (date == null ||
            date.year != now.year ||
            date.month != now.month) {
          return total;
        }

        if (category != 'All' &&
            transaction['category']?.toString() != category) {
          return total;
        }

        final amount = transaction['amount'];
        return total + (amount is num ? amount.toDouble() : 0);
      });

      final percentage = spent / limit * 100;
      final monthKey =
          '${now.year}_${now.month.toString().padLeft(2, '0')}';
      final categoryKey = Uri.encodeComponent(category);

      // Alert at the budget's configured threshold.
      if (percentage >= threshold) {
        final thresholdKey =
            'budget_alert_${monthKey}_${categoryKey}_$threshold';

        if (!prefs.getBool(thresholdKey).orFalse) {
          await NotificationService.instance.showBudgetAlert(
            id: _notificationId(category, 0),
            title: 'Budget alert: $category',
            body: '$category spending has reached '
                '${percentage.toStringAsFixed(0)}% of its monthly budget '
                '(Rs ${spent.toStringAsFixed(0)} of '
                'Rs ${limit.toStringAsFixed(0)}).',
          );

          await prefs.setBool(thresholdKey, true);
        }
      }

      // Send a separate alert at 100%, unless the configured
      // threshold is already 100%.
      if (percentage >= 100 && threshold < 100) {
        final exceededKey = 'budget_exceeded_${monthKey}_$categoryKey';

        if (!prefs.getBool(exceededKey).orFalse) {
          await NotificationService.instance.showBudgetAlert(
            id: _notificationId(category, 1),
            title: 'Budget limit reached: $category',
            body: '$category spending has reached or exceeded '
                'your monthly limit of Rs ${limit.toStringAsFixed(0)}.',
          );

          await prefs.setBool(exceededKey, true);
        }
      }
    }
  }

  static int _notificationId(String category, int level) {
    var hash = 0;
    for (final code in category.codeUnits) {
      hash = (hash * 31 + code) & 0x3FFFFFFF;
    }
    return 300 + (hash % 100000) * 2 + level;
  }
}

extension on bool? {
  bool get orFalse => this ?? false;
}

