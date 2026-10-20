import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class AddExpenseScreen extends StatefulWidget {
  final Map<String, dynamic>? existingTransaction;

  const AddExpenseScreen({super.key, this.existingTransaction});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String _type = 'Expense';
  String _category = 'Food';
  String _paymentMethod = 'Cash';
  DateTime _selectedDate = DateTime.now();

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

  bool get _isEditing => widget.existingTransaction != null;

  @override
  void initState() {
    super.initState();

    final transaction = widget.existingTransaction;

    if (transaction == null) return;

    _type = transaction['type'] == 'Income' ? 'Income' : 'Expense';

    final categories = _type == 'Expense'
        ? _expenseCategories
        : _incomeCategories;

    final savedCategory = transaction['category']?.toString() ?? '';

    _category = categories.contains(savedCategory)
        ? savedCategory
        : (_type == 'Expense' ? 'Food' : 'Salary');

    final savedAmount = transaction['amount'];

    _amountController.text = savedAmount is num ? savedAmount.toString() : '';

    _notesController.text = transaction['notes']?.toString() ?? '';

    final savedPaymentMethod =
        transaction['paymentMethod']?.toString() ?? 'Cash';

    _paymentMethod = _paymentMethods.contains(savedPaymentMethod)
        ? savedPaymentMethod
        : 'Cash';

    final savedDate = DateTime.tryParse(transaction['date']?.toString() ?? '');

    if (savedDate != null) {
      final today = DateTime.now();

      _selectedDate = savedDate.isAfter(today) ? today : savedDate;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final today = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year, today.month, today.day),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveTransaction() {
    if (!_formKey.currentState!.validate()) return;

    final existing = widget.existingTransaction;

    final transaction = <String, dynamic>{
      ...?existing,
      'title': _notesController.text.trim().isEmpty
          ? _category
          : _notesController.text.trim(),
      'category': _category,
      'date': _selectedDate.toIso8601String(),
      'amount': double.parse(_amountController.text.trim()),
      'type': _type,
      'paymentMethod': _paymentMethod,
      'notes': _notesController.text.trim(),
    };

    Navigator.pop(context, transaction);
  }

  @override
  Widget build(BuildContext context) {
    final categories = _type == 'Expense'
        ? _expenseCategories
        : _incomeCategories;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Transaction' : 'Add Transaction',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Transaction type
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceFor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderFor(context)),
                ),
                child: Row(
                  children: [_typeButton('Expense'), _typeButton('Income')],
                ),
              ),
              const SizedBox(height: 28),

              // Amount
              Text(
                'Amount (PKR)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryFor(context),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixText: 'PKR ',
                  filled: true,
                  fillColor: AppColors.surfaceFor(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.borderFor(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.borderFor(context)),
                  ),
                ),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');

                  if (amount == null || !amount.isFinite || amount <= 0) {
                    return 'Enter a valid amount greater than zero';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 22),

              // Category
              _fieldLabel('Category'),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: _decoration(),
                items: categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _category = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),

              // Date
              _fieldLabel('Date'),
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: _decoration(
                    suffixIcon: const Icon(Icons.calendar_month_outlined),
                  ),
                  child: Text(
                    '${_selectedDate.day.toString().padLeft(2, '0')}/'
                    '${_selectedDate.month.toString().padLeft(2, '0')}/'
                    '${_selectedDate.year}',
                    style: TextStyle(color: AppColors.textPrimaryFor(context)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Payment method
              _fieldLabel('Payment Method'),
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                isExpanded: true,
                decoration: _decoration(),
                items: _paymentMethods
                    .map(
                      (method) =>
                          DropdownMenuItem(value: method, child: Text(method)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _paymentMethod = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),

              // Notes
              _fieldLabel('Notes (Optional)'),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                maxLength: 200,
                decoration: _decoration(hintText: 'Add a short description...'),
              ),
              const SizedBox(height: 24),

              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _saveTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _isEditing ? 'Update Transaction' : 'Save Transaction',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeButton(String type) {
    final selected = _type == type;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _type = type;
            _category = type == 'Expense' ? 'Food' : 'Salary';
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            type,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondaryFor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryFor(context),
        ),
      ),
    );
  }

  InputDecoration _decoration({String? hintText, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hintText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surfaceFor(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.borderFor(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.borderFor(context)),
      ),
    );
  }
}
