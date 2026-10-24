
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'recurring_transaction_form_screen.dart';
import 'recurring_transaction_storage.dart';

class RecurringTransactionsScreen extends StatefulWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  State<RecurringTransactionsScreen> createState() =>
      _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState
    extends State<RecurringTransactionsScreen> {
  List<Map<String, dynamic>> _rules = [];
  bool _loading = true;
  int _createdCount = 0;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    try {
      // Process scheduled transactions before displaying the rules.
      final created =
          await RecurringTransactionStorage.processDueTransactions();
      final rules =
          await RecurringTransactionStorage.getRecurringTransactions();

      if (!mounted) return;

      setState(() {
        _createdCount += created;
        _rules = rules;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load recurring transactions.'),
        ),
      );
    }
  }

  Future<void> _addRule() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const RecurringTransactionFormScreen(),
      ),
    );

    if (saved == true && mounted) {
      await _loadRules();
    }
  }

  Future<void> _editRule(Map<String, dynamic> rule) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RecurringTransactionFormScreen(
          existingRule: rule,
        ),
      ),
    );

    if (saved == true && mounted) {
      await _loadRules();
    }
  }

  Future<void> _toggleRule(
    Map<String, dynamic> rule,
    bool enabled,
  ) async {
    final id = rule['id']?.toString();
    if (id == null) return;

    await RecurringTransactionStorage.setEnabled(id, enabled);
    await _loadRules();
  }

  Future<void> _deleteRule(Map<String, dynamic> rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete recurring rule?'),
        content: const Text(
          'This removes the schedule. Transactions already created '
          'will remain in your transaction history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final id = rule['id']?.toString();
    if (id == null) return;

    final deleted =
        await RecurringTransactionStorage.deleteRecurringTransaction(id);

    if (!mounted) return;

    if (deleted) {
      await _loadRules();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recurring rule deleted.')),
      );
    }
  }

  String _formatAmount(dynamic value) {
    if (value is num) return value.toStringAsFixed(2);
    return '0.00';
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Not set';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  
DateTime? _parseDate(dynamic value) {
  return DateTime.tryParse(value?.toString() ?? '');
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

DateTime _addMonthFromAnchor(DateTime anchor, int monthOffset) {
  final monthIndex = anchor.year * 12 + anchor.month - 1 + monthOffset;
  final year = monthIndex ~/ 12;
  final month = monthIndex % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;

  return DateTime(
    year,
    month,
    anchor.day > lastDay ? lastDay : anchor.day,
  );
}

DateTime _nextOccurrence(Map<String, dynamic> rule) {
  final start = _parseDate(rule['startDate']) ?? DateTime.now();
  final anchor = DateTime(start.year, start.month, start.day);
  final lastProcessed = _parseDate(rule['lastProcessedDate']);
  final today = _dateOnly(DateTime.now());
  final frequency = rule['frequency']?.toString() ?? 'Monthly';

  DateTime next;

  if (lastProcessed != null) {
    final last = _dateOnly(lastProcessed);

    if (frequency == 'Weekly') {
      next = last.add(const Duration(days: 7));
    } else if (frequency == 'Yearly') {
      next = DateTime(
        last.year + 1,
        anchor.month,
        anchor.day,
      );
    } else {
      final monthOffset =
          (last.year - anchor.year) * 12 +
          last.month -
          anchor.month +
          1;
      next = _addMonthFromAnchor(anchor, monthOffset);
    }
  } else {
    next = anchor;
  }

  // Display the next upcoming date, without changing stored data.
  for (var i = 0; i < 1200 && next.isBefore(today); i++) {
    if (frequency == 'Weekly') {
      next = next.add(const Duration(days: 7));
    } else if (frequency == 'Yearly') {
      next = DateTime(
        next.year + 1,
        anchor.month,
        anchor.day,
      );
    } else {
      final monthOffset =
          (next.year - anchor.year) * 12 +
          next.month -
          anchor.month +
          1;
      next = _addMonthFromAnchor(anchor, monthOffset);
    }
  }

  return next;
}

String _status(Map<String, dynamic> rule) {
  if (rule['enabled'] != true) return 'Paused';

  final end = _parseDate(rule['endDate']);
  final next = _nextOccurrence(rule);

  if (end != null && _dateOnly(next).isAfter(_dateOnly(end))) {
    return 'Completed';
  }

  return 'Active';
}


  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primaryFor(context);
    final text = AppColors.textPrimaryFor(context);
    final secondary = AppColors.textSecondaryFor(context);
    final surface = AppColors.surfaceFor(context);
    final border = AppColors.borderFor(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      appBar: AppBar(
        title: const Text('Recurring Transactions'),
        foregroundColor: primary,
        backgroundColor: AppColors.backgroundFor(context),
        actions: [
          IconButton(
            tooltip: 'Process due transactions',
            onPressed: () async {
              setState(() => _loading = true);
              await _loadRules();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRule,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Schedule'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRules,
              child: _rules.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 100),
                        Icon(
                          Icons.event_repeat_outlined,
                          size: 64,
                          color: secondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No recurring schedules yet',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: text,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add a schedule for rent, bills, salary, '
                          'or another regular transaction.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: secondary),
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      children: [
                        if (_createdCount > 0)
                          Card(
                            color: surface,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Text(
                                'Created $_createdCount due '
                                '${_createdCount == 1 ? 'transaction' : 'transactions'}. '
                                'Refresh to check again.',
                                style: TextStyle(color: text),
                              ),
                            ),
                          ),
                        for (final rule in _rules)
                          Card(
                            color: surface,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(color: border),
                            ),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: rule['type'] == 'Income'
                                            ? const Color(0xFFDDF5E8)
                                            : const Color(0xFFFFE6C7),
                                        child: Icon(
                                          rule['type'] == 'Income'
                                              ? Icons.south_west
                                              : Icons.north_east,
                                          color: primary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              rule['title']?.toString() ??
                                                  rule['category']?.toString() ??
                                                  'Recurring transaction',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: text,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${rule['category'] ?? 'Other'} • '
                                              '${rule['frequency'] ?? 'Monthly'}',
                                              style: TextStyle(
                                                color: secondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _editRule(rule);
                                          } else if (value == 'delete') {
                                            _deleteRule(rule);
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Edit'),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '${rule['type'] == 'Income' ? '+' : '-'}'
                                    'PKR ${_formatAmount(rule['amount'])}',
                                    style: TextStyle(
                                      color: rule['type'] == 'Income'
                                          ? const Color(0xFF23865A)
                                          : const Color(0xFFD9534F),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  
Text(
  'Starts: ${_formatDate(rule['startDate'])}',
  style: TextStyle(color: secondary),
),
const SizedBox(height: 4),
Text(
  'Next occurrence: ${_formatDate(_nextOccurrence(rule))}',
  style: TextStyle(color: secondary),
),
const SizedBox(height: 4),
Text(
  'Last processed: ${rule['lastProcessedDate'] == null ? 'Never' : _formatDate(rule['lastProcessedDate'])}',
  style: TextStyle(color: secondary),
),
const SizedBox(height: 4),
Text(
  'Ends: ${rule['endDate'] == null ? 'Never' : _formatDate(rule['endDate'])}',
  style: TextStyle(color: secondary),
),
const SizedBox(height: 8),
Row(
  children: [
    const Text(
      'Status: ',
      style: TextStyle(fontWeight: FontWeight.w500),
    ),
    Text(
      _status(rule),
      style: TextStyle(
        color: _status(rule) == 'Active'
            ? const Color(0xFF23865A)
            : _status(rule) == 'Paused'
                ? Colors.orange
                : secondary,
        fontWeight: FontWeight.bold,
      ),
    ),
  ],
),

                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      rule['enabled'] == true
                                          ? 'Schedule active'
                                          : 'Schedule paused',
                                      style: TextStyle(color: text),
                                    ),
                                    value: rule['enabled'] == true,
                                    onChanged: (value) =>
                                        _toggleRule(rule, value),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
    );
  }
}
