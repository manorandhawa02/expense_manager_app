import 'package:flutter/material.dart';
import '../../app.dart';
import '../../core/theme/app_colors.dart';
import 'recurring_transaction_storage.dart';


class RecurringTransactionFormScreen extends StatefulWidget {
  final Map<String, dynamic>? existingRule;

  const RecurringTransactionFormScreen({super.key, this.existingRule});

  @override
  State<RecurringTransactionFormScreen> createState() =>
      _RecurringTransactionFormScreenState();
}

class _RecurringTransactionFormScreenState
    extends State<RecurringTransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String _type = 'Expense';
  String _category = 'Bills';
  String _paymentMethod = 'Cash';
  String _frequency = 'Monthly';

  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _enabled = true;
  bool _saving = false;

  final List<String> _expenseCategories = [
    'Food',
    'Transport',
    'Shopping',
    'Bills',
    'Health',
    'Education',
    'Entertainment',
    'Other',
  ];

  final List<String> _incomeCategories = [
    'Salary',
    'Freelance',
    'Business',
    'Investment',
    'Gift',
    'Other',
  ];

  final List<String> _paymentMethods = [
    'Cash',
    'Bank Transfer',
    'Debit Card',
    'Credit Card',
    'Mobile Wallet',
  ];

  bool get _isEditing => widget.existingRule != null;

  @override
  void initState() {
    super.initState();

    final rule = widget.existingRule;
    if (rule == null) return;

    _type = rule['type'] == 'Income' ? 'Income' : 'Expense';

    final categories = _type == 'Income'
        ? _incomeCategories
        : _expenseCategories;
    final savedCategory = rule['category']?.toString() ?? '';

    _category = categories.contains(savedCategory)
        ? savedCategory
        : (_type == 'Income' ? 'Salary' : 'Bills');

    _frequency = ['Weekly', 'Monthly', 'Yearly'].contains(rule['frequency'])
        ? rule['frequency'].toString()
        : 'Monthly';

    _paymentMethod = _paymentMethods.contains(rule['paymentMethod'])
        ? rule['paymentMethod'].toString()
        : 'Cash';

    _notesController.text = rule['notes']?.toString() ?? '';
    _enabled = rule['enabled'] != false;

    final start = DateTime.tryParse(rule['startDate']?.toString() ?? '');
    if (start != null) _startDate = start;

    final end = DateTime.tryParse(rule['endDate']?.toString() ?? '');
    if (end != null) _endDate = end;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final rule = widget.existingRule;
    if (rule == null || _amountController.text.isNotEmpty) return;

    final rawAmount = rule['amount'];
    if (rawAmount is num) {
      final converted = CurrencyProvider.of(context).convertFromPKR(rawAmount);

      if (converted != null) {
        _amountController.text = converted.toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime initial) async {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_endDate != null &&
        DateTime(_endDate!.year, _endDate!.month, _endDate!.day).isBefore(
          DateTime(_startDate.year, _startDate.month, _startDate.day),
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date must be on or after the start date.'),
        ),
      );
      return;
    }

    final enteredAmount = double.parse(_amountController.text.trim());
    final currency = CurrencyProvider.of(context);
    final pkrAmount = currency.convertToPKR(enteredAmount);

    if (pkrAmount == null || !pkrAmount.isFinite || pkrAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exchange rate unavailable. Please try again.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final existing = widget.existingRule;
    final notes = _notesController.text.trim();

    final rule = <String, dynamic>{
      ...?existing,
      'title': notes.isEmpty ? _category : notes,
      'category': _category,
      'amount': pkrAmount,
      'type': _type,
      'paymentMethod': _paymentMethod,
      'notes': notes,
      'frequency': _frequency,
      'startDate': DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
      ).toIso8601String(),
      'endDate': _endDate == null
          ? null
          : DateTime(
              _endDate!.year,
              _endDate!.month,
              _endDate!.day,
            ).toIso8601String(),
      'enabled': _enabled,
    };

    try {
      if (_isEditing) {
        final success =
            await RecurringTransactionStorage.updateRecurringTransaction(rule);

        if (!mounted) return;

        if (!success) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recurring rule not found.')),
          );
          return;
        }
      } else {
        await RecurringTransactionStorage.addRecurringTransaction(rule);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save recurring transaction.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _type == 'Expense'
        ? _expenseCategories
        : _incomeCategories;
    final currency = CurrencyProvider.of(context);
    final textColor = AppColors.textPrimaryFor(context);
    final primary = AppColors.primaryFor(context);
    final surface = AppColors.surfaceFor(context);
    final border = AppColors.borderFor(context);

    InputDecoration decoration(String label) => InputDecoration(
      labelText: label,
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Recurring Rule' : 'New Recurring Rule'),
        foregroundColor: primary,
        backgroundColor: AppColors.backgroundFor(context),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Expense', label: Text('Expense')),
                ButtonSegment(value: 'Income', label: Text('Income')),
              ],
              selected: {_type},
              onSelectionChanged: (value) {
                setState(() {
                  _type = value.first;
                  _category = _type == 'Expense' ? 'Bills' : 'Salary';
                });
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: decoration('Amount (${currency.currencyCode})')
                  .copyWith(prefixText: '${currency.currencySymbol} '),
              validator: (value) {
                final amount = double.tryParse(value?.trim() ?? '');
                if (amount == null || !amount.isFinite || amount <= 0) {
                  return 'Enter an amount greater than zero';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: decoration('Category'),
              items: categories
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: decoration('Repeat'),
              items: const ['Weekly', 'Monthly', 'Yearly']
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _frequency = value);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: decoration('Payment Method'),
              items: _paymentMethods
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _paymentMethod = value);
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start date'),
              subtitle: Text(_dateLabel(_startDate)),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: () async {
                final picked = await _pickDate(_startDate);
                if (picked != null) {
                  setState(() => _startDate = picked);
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('End date (optional)'),
              subtitle: Text(
                _endDate == null ? 'No end date' : _dateLabel(_endDate!),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_endDate != null)
                    IconButton(
                      tooltip: 'Clear end date',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _endDate = null),
                    ),
                  const Icon(Icons.event_outlined),
                ],
              ),
              onTap: () async {
                final picked = await _pickDate(_endDate ?? _startDate);
                if (picked != null) setState(() => _endDate = picked);
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLength: 200,
              maxLines: 2,
              decoration: decoration('Description (optional)'),
              style: TextStyle(color: textColor),
            ),
            if (_isEditing)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Recurring rule enabled'),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_isEditing ? 'Update Rule' : 'Save Rule'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
