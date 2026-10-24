import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/theme/app_colors.dart';
import '../transaction/transaction_storage.dart';
import 'budget_storage.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  List<Map<String, dynamic>> _budgets = [];
  List<Map<String, dynamic>> _transactions = [];
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loading = true;

  static const List<String> _categories = [
    'All',
    'Food',
    'Transport',
    'Shopping',
    'Bills',
    'Health',
    'Education',
    'Entertainment',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        BudgetStorage.getBudgets(),
        TransactionStorage.getTransactions(),
      ]);

      if (!mounted) return;

      setState(() {
        _budgets = results[0] as List<Map<String, dynamic>>;
        _transactions = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('Budget loading failed: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not load budgets.')));
    }
  }

  double _spent(String category) {
    return _transactions.fold<double>(0, (total, t) {
      if (t['type'] != 'Expense') return total;

      final date = DateTime.tryParse(t['date']?.toString() ?? '');
      if (date == null ||
          date.year != _month.year ||
          date.month != _month.month) {
        return total;
      }

      if (category != 'All' && t['category'] != category) {
        return total;
      }

      final amount = t['amount'];
      return total + (amount is num ? amount.toDouble() : 0);
    });
  }

  String _money(double pkr) => CurrencyProvider.of(context).formatAmount(pkr);

  Future<void> _changeMonth(int offset) async {
    setState(() {
      _month = DateTime(_month.year, _month.month + offset);
    });
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BudgetForm(existing: existing, categories: _categories),
    );

    if (saved == true && mounted) await _load();
  }

  Future<void> _delete(String category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete budget?'),
        content: Text(
          'Remove the ${category == 'All' ? 'overall' : category} budget?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await BudgetStorage.deleteBudget(category);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppColors.textPrimaryFor(context);
    final secondary = AppColors.textSecondaryFor(context);
    final surface = AppColors.surfaceFor(context);
    final border = AppColors.borderFor(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      appBar: AppBar(
        title: const Text('Budgets'),
        backgroundColor: AppColors.backgroundFor(context),
        foregroundColor: text,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primaryFor(context),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Set budget'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: surface,
                      border: Border.all(color: border),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => _changeMonth(-1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            '${_monthName(_month.month)} ${_month.year}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: text,
                              fontSize: 17,
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
                  ),
                  const SizedBox(height: 18),
                  if (_budgets.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.flag_outlined, size: 44, color: secondary),
                          const SizedBox(height: 12),
                          Text(
                            'No budgets yet',
                            style: TextStyle(
                              color: text,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Set an overall monthly limit or a limit for a specific category.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: secondary),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => _openForm(),
                            child: const Text('Create your first budget'),
                          ),
                        ],
                      ),
                    ),
                  for (final b in _budgets) ...[
                    _buildBudgetCard(b, text, secondary, surface, border),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Budgets repeat every month. Changing a budget updates its limit for all months.',
                    style: TextStyle(color: secondary, fontSize: 12),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBudgetCard(
    Map<String, dynamic> b,
    Color text,
    Color secondary,
    Color surface,
    Color border,
  ) {
    final category = b['category']?.toString() ?? 'All';
    final limit = (b['limitPkr'] as num?)?.toDouble() ?? 0;
    final spent = _spent(category);
    final ratio = limit > 0 ? spent / limit : 0.0;
    final threshold = (b['alertThresholdPct'] as num?)?.toInt() ?? 80;
    final over = spent > limit;
    final warning = !over && ratio >= threshold / 100;
    final color = over
        ? AppColors.expense
        : warning
        ? const Color(0xFFD9A62E)
        : AppColors.income;
    final progress = ratio.clamp(0.0, 1.0).toDouble();

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _openForm(existing: b),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(
                      category == 'All'
                          ? Icons.flag_outlined
                          : Icons.category_outlined,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      category == 'All' ? 'Overall monthly budget' : category,
                      style: TextStyle(
                        color: text,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    '${(ratio * 100).round()}%',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') _openForm(existing: b);
                      if (value == 'delete') _delete(category);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 9,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_money(spent)} spent',
                      style: TextStyle(color: secondary, fontSize: 12),
                    ),
                  ),
                  Text(
                    _money(limit),
                    style: TextStyle(color: text, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                over
                    ? '${_money(spent - limit)} over budget'
                    : '${_money(limit - spent)} remaining',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if (warning || over) ...[
                const SizedBox(height: 8),
                Text(
                  over
                      ? 'You have exceeded this budget.'
                      : 'You have reached the alert level ($threshold%).',
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[month - 1];
  }
}

class _BudgetForm extends StatefulWidget {
  const _BudgetForm({required this.categories, this.existing});

  final List<String> categories;
  final Map<String, dynamic>? existing;

  @override
  State<_BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<_BudgetForm> {
  final _controller = TextEditingController();
  String _category = 'All';
  double _threshold = 80;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    if (b != null) {
      _category = b['category']?.toString() ?? 'All';
      _threshold = ((b['alertThresholdPct'] as num?) ?? 80).toDouble();
      final pkr = (b['limitPkr'] as num?)?.toDouble() ?? 0;
      final converted = CurrencyProvider.of(context).convertFromPKR(pkr);
      _controller.text = converted?.toStringAsFixed(2) ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final entered = double.tryParse(_controller.text.trim());
    if (entered == null || !entered.isFinite || entered <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }

    final currency = CurrencyProvider.of(context);
    final pkr = currency.convertToPKR(entered);
    if (pkr == null || !pkr.isFinite || pkr <= 0) {
      setState(() => _error = 'Currency conversion is unavailable.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await BudgetStorage.saveBudget(
        category: _category,
        limitPkr: pkr,
        alertThresholdPct: _threshold.round(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e, st) {
      debugPrint('Budget save failed: $e');
      debugPrintStack(stackTrace: st);
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the budget. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = CurrencyProvider.of(context);
    final text = AppColors.textPrimaryFor(context);
    final secondary = AppColors.textSecondaryFor(context);
    final surface = AppColors.surfaceFor(context);
    final border = AppColors.borderFor(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _editing ? 'Edit budget' : 'Set monthly budget',
              style: TextStyle(
                color: text,
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This limit repeats every month.',
              style: TextStyle(color: secondary),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              dropdownColor: surface,
              decoration: InputDecoration(
                labelText: 'Budget applies to',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              items: widget.categories.map((c) {
                return DropdownMenuItem(
                  value: c,
                  child: Text(c == 'All' ? 'Overall spending' : c),
                );
              }).toList(),
              onChanged: _editing || _saving
                  ? null
                  : (v) {
                      if (v != null) setState(() => _category = v);
                    },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: 'Monthly limit',
                prefixText: '${currency.currencyCode}  ',
                errorText: _error,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Alert at ${_threshold.round()}%',
              style: TextStyle(color: text, fontWeight: FontWeight.w600),
            ),
            Slider(
              value: _threshold,
              min: 50,
              max: 100,
              divisions: 10,
              label: '${_threshold.round()}%',
              onChanged: _saving ? null : (v) => setState(() => _threshold = v),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save budget'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
