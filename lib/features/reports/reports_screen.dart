import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../transaction/transaction_storage.dart';
import '../settings/settings_screen.dart';
import '../../app.dart';
class ReportsScreen extends StatefulWidget {
  final Future<void> Function()? onTransactionsChanged;

  const ReportsScreen({
    super.key,
    this.onTransactionsChanged,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final transactions = await TransactionStorage.getTransactions();

    if (!mounted) return;

    setState(() {
      _transactions = transactions;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _monthlyTransactions {
    return _transactions.where((transaction) {
      final date = DateTime.tryParse(
        transaction['date']?.toString() ?? '',
      );

      return date != null &&
          date.year == _selectedMonth.year &&
          date.month == _selectedMonth.month;
    }).toList();
  }

  double _totalFor(String type) {
    return _monthlyTransactions.fold<double>(0, (total, transaction) {
      if (transaction['type']?.toString().toLowerCase() != type) {
        return total;
      }

      return total +
          (double.tryParse(transaction['amount'].toString()) ?? 0);
    });
  }

  Map<String, double> get _categoryExpenses {
    final result = <String, double>{};

    for (final transaction in _monthlyTransactions) {
      if (transaction['type']?.toString().toLowerCase() != 'expense') {
        continue;
      }

      final category =
          transaction['category']?.toString() ?? 'Other';
      final amount =
          double.tryParse(transaction['amount'].toString()) ?? 0;

      result[category] = (result[category] ?? 0) + amount;
    }

    return result;
  }

  String _formatAmount(double amount) {
  return CurrencyProvider.of(context).formatAmount(amount);
}

  String get _monthLabel {
    const months = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December',
    ];

    return '${months[_selectedMonth.month - 1]} ${_selectedMonth.year}';
  }

  void _changeMonth(int difference) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + difference,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final income = _totalFor('income');
    final expenses = _totalFor('expense');
    final savings = income - expenses;

    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      appBar: AppBar(
  title: const Text('Reports'),
  backgroundColor: AppColors.backgroundFor(context),
  elevation: 0,
  actions: [
    IconButton(
      tooltip: 'Settings',
      icon: const Icon(Icons.settings_outlined),
     onPressed: () async {
  await Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => SettingsScreen(
        onTransactionsCleared: () async {
          await _loadTransactions();
          await widget.onTransactionsChanged?.call();
        },
      ),
    ),
  );
},
    ),
  ],
),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTransactions,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildMonthSelector(),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Income',
                          income,
                          Icons.arrow_downward_rounded,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'Expenses',
                          expenses,
                          Icons.arrow_upward_rounded,
                          Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSavingsCard(savings),
                  const SizedBox(height: 28),
                  _buildComparisonSection(income, expenses),
                  const SizedBox(height: 28),
                  _buildCategorySection(),
                ],
              ),
            ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _changeMonth(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              _monthLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _changeMonth(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textSecondaryFor(context),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatAmount(amount),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsCard(double savings) {
    final isPositive = savings >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.account_balance_wallet_rounded,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Monthly Balance',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatAmount(savings),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isPositive
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            color: Colors.white,
            size: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonSection(double income, double expenses) {
    final largest = income > expenses ? income : expenses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Income vs Expenses',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildComparisonBar('Income', income, Colors.green, largest),
        const SizedBox(height: 16),
        _buildComparisonBar(
          'Expenses',
          expenses,
          Colors.redAccent,
          largest,
        ),
      ],
    );
  }

  Widget _buildComparisonBar(
    String label,
    double amount,
    Color color,
    double maximum,
  ) {
    final fraction = maximum > 0 ? amount / maximum : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              _formatAmount(amount),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 10,
            backgroundColor: AppColors.borderFor(context),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    final categories = _categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalExpenses = _totalFor('expense');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Spending by Category',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (categories.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceFor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderFor(context)),
            ),
            child: const Text(
              'No expenses recorded for this month.',
              textAlign: TextAlign.center,
            ),
          )
        else
          ...categories.map((entry) {
            final fraction = totalExpenses > 0
                ? entry.value / totalExpenses
                : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(_formatAmount(entry.value)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 8,
                      backgroundColor: AppColors.borderFor(context),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(fraction * 100).toStringAsFixed(1)}% of expenses',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
