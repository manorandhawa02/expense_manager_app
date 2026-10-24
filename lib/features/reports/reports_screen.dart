import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/app_colors.dart';
import '../settings/settings_screen.dart';
import '../transaction/transaction_storage.dart';

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

  late DateTime _startDate;
  late DateTime _endDate;

  String _selectedPreset = 'This Month';

  @override
  void initState() {
    super.initState();

    final today = _dateOnly(DateTime.now());

    _startDate = DateTime(today.year, today.month, 1);
    _endDate = today;

    _loadTransactions();
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _loadTransactions() async {
    try {
      final transactions = await TransactionStorage.getTransactions();

      if (!mounted) return;

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load reports. Please try again.'),
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    return _transactions.where((transaction) {
      final date = DateTime.tryParse(
        transaction['date']?.toString() ?? '',
      );

      if (date == null) return false;

      final transactionDate = _dateOnly(date);

      return !transactionDate.isBefore(_startDate) &&
          !transactionDate.isAfter(_endDate);
    }).toList();
  }

  double _totalFor(String type) {
    return _filteredTransactions.fold<double>(0, (total, transaction) {
      if (transaction['type']?.toString().toLowerCase() != type) {
        return total;
      }

      final rawAmount = transaction['amount'];
      final amount = rawAmount is num
          ? rawAmount.toDouble()
          : double.tryParse(rawAmount?.toString() ?? '') ?? 0;

      return total + amount;
    });
  }

  Map<String, double> get _categoryExpenses {
    final result = <String, double>{};

    for (final transaction in _filteredTransactions) {
      if (transaction['type']?.toString().toLowerCase() != 'expense') {
        continue;
      }

      final category =
          transaction['category']?.toString() ?? 'Other';

      final rawAmount = transaction['amount'];
      final amount = rawAmount is num
          ? rawAmount.toDouble()
          : double.tryParse(rawAmount?.toString() ?? '') ?? 0;

      result[category] = (result[category] ?? 0) + amount;
    }

    return result;
  }

  String _formatAmount(double amount) {
    return CurrencyProvider.of(context).formatAmount(amount);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String get _dateRangeLabel {
    return '${_formatDate(_startDate)} - ${_formatDate(_endDate)}';
  }

  void _selectPreset(String preset) {
    final today = _dateOnly(DateTime.now());

    setState(() {
      _selectedPreset = preset;

      switch (preset) {
        case 'This Month':
          _startDate = DateTime(today.year, today.month, 1);
          _endDate = today;
          break;

        case 'Last Month':
          _startDate = DateTime(today.year, today.month - 1, 1);
          _endDate = DateTime(today.year, today.month, 1)
              .subtract(const Duration(days: 1));
          break;

        case 'This Year':
          _startDate = DateTime(today.year, 1, 1);
          _endDate = today;
          break;
      }
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: _endDate,
      helpText: 'Select start date',
    );

    if (picked == null || !mounted) return;

    setState(() {
      _startDate = _dateOnly(picked);
      _selectedPreset = 'Custom';
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Select end date',
    );

    if (picked == null || !mounted) return;

    setState(() {
      _endDate = _dateOnly(picked);
      _selectedPreset = 'Custom';
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
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  _buildDateRangeSection(),
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

  Widget _buildDateRangeSection() {
    final primary = AppColors.primaryFor(context);
    final text = AppColors.textPrimaryFor(context);
    final secondary = AppColors.textSecondaryFor(context);
    final surface = AppColors.surfaceFor(context);
    final border = AppColors.borderFor(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Report Period',
            style: TextStyle(
              color: text,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // All three preset buttons remain in one row.
          Row(
            children: [
              Expanded(
                child: _buildPresetButton('This Month'),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildPresetButton('Last Month'),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildPresetButton('This Year'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            'Custom date range',
            style: TextStyle(
              color: secondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _buildDateButton(
                  label: 'Start date',
                  date: _startDate,
                  onPressed: _pickStartDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDateButton(
                  label: 'End date',
                  date: _endDate,
                  onPressed: _pickEndDate,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Icon(
                Icons.date_range_outlined,
                size: 18,
                color: primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _dateRangeLabel,
                  style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _selectPreset('This Month'),
                child: const Text('Reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton(String preset) {
    final primary = AppColors.primaryFor(context);
    final text = AppColors.textPrimaryFor(context);
    final border = AppColors.borderFor(context);
    final surface = AppColors.surfaceFor(context);

    final isSelected = _selectedPreset == preset;

    return ChoiceChip(
      label: SizedBox(
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            preset,
            maxLines: 1,
            style: TextStyle(
              color: isSelected ? Colors.white : text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: primary,
      backgroundColor: surface,
      side: BorderSide(
        color: isSelected ? primary : border,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 2,
        vertical: 8,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onSelected: (_) => _selectPreset(preset),
    );
  }

  Widget _buildDateButton({
    required String label,
    required DateTime date,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide(
          color: AppColors.borderFor(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondaryFor(context),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 16,
                color: AppColors.primaryFor(context),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _formatDate(date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimaryFor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
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
                  'Balance for Selected Period',
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
        const SizedBox(height: 6),
        Text(
          'For $_dateRangeLabel',
          style: TextStyle(
            color: AppColors.textSecondaryFor(context),
            fontSize: 12,
          ),
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
        const SizedBox(height: 6),
        Text(
          'For $_dateRangeLabel',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondaryFor(context),
          ),
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
              'No expenses recorded for this period.',
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
                      color: AppColors.textSecondaryFor(context),
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
