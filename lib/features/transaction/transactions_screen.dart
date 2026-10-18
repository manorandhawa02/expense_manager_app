
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'transaction_storage.dart';

class TransactionsScreen extends StatefulWidget {
  final Future<void> Function(
    Map<String, dynamic> transaction,
  )? onEdit;

  final Future<void> Function(
    Map<String, dynamic> transaction,
  )? onDelete;

  const TransactionsScreen({
    super.key,
    this.onEdit,
    this.onDelete,
  });

  @override
  TransactionsScreenState createState() => TransactionsScreenState();
}

class TransactionsScreenState extends State<TransactionsScreen> {
  String _selectedFilter = 'All';

  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  List<Map<String, dynamic>> get _filteredTransactions {
    if (_selectedFilter == 'All') {
      return _transactions;
    }

    return _transactions.where((transaction) {
      return transaction['type'] == _selectedFilter;
    }).toList();
  }


  
  @override
  void initState() {
    super.initState();
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    try {
      final savedTransactions =
          await TransactionStorage.getTransactions();

      if (!mounted) return;

      setState(() {
        _transactions = savedTransactions;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load saved transactions.'),
        ),
      );
    }
  }

  double _totalFor(String type) {
    return _filteredTransactions
        .where((transaction) => transaction['type'] == type)
        .fold<double>(
          0,
          (total, transaction) =>
              total + (transaction['amount'] as num).toDouble(),
        );
  }

  String _formatAmount(num amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);

    if (date == null) return value;

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant_outlined;
      case 'transport':
      case 'travel':
        return Icons.directions_car_outlined;
      case 'shopping':
      case 'personal':
        return Icons.shopping_bag_outlined;
      case 'bills':
        return Icons.receipt_long_outlined;
      case 'health':
        return Icons.medical_services_outlined;
      case 'education':
        return Icons.school_outlined;
      case 'salary':
      case 'freelance':
      case 'business':
      case 'income':
        return Icons.account_balance_wallet_outlined;
      case 'entertainment':
        return Icons.movie_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  Color _categoryColor(String type) {
    return type == 'Income'
        ? const Color(0xFFDDF5E8)
        : const Color(0xFFFFE6C7);
  }


Future<void> _confirmDelete(
  Map<String, dynamic> transaction,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text(
          'Are you sure you want to delete this transaction? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !mounted) return;

  final deleteCallback = widget.onDelete;

  if (deleteCallback == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Delete functionality is not connected yet.'),
      ),
    );
    return;
  }

  await deleteCallback(transaction);
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadTransactions,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Transactions',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Track your income and expenses',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Summary card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Transactions',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isLoading
                            ? '...'
                            : '${_filteredTransactions.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummary(
                              'Income',
                              _totalFor('Income'),
                              AppColors.mint,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummary(
                              'Expenses',
                              _totalFor('Expense'),
                              const Color(0xFFFFA69A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 26),

                const Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),

                // Transaction filters
                Row(
                  children: ['All', 'Expense', 'Income'].map((filter) {
                    final selected = _selectedFilter == filter;

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            filter == 'Expense'
                                ? 'Expenses'
                                : filter,
                          ),
                          selected: selected,
                          showCheckmark: false,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.surface,
                          side: BorderSide(
                            color: selected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                          labelStyle: TextStyle(
                            color: selected
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) {
                            setState(() {
                              _selectedFilter = filter;
                            });
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Saved transaction list
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_filteredTransactions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 48,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No transactions yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Tap + to add your first transaction.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._filteredTransactions.map(_buildTransactionTile),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(
    String title,
    double amount,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 9, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'PKR ${_formatAmount(amount)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionTile(
    Map<String, dynamic> transaction,
  ) {
    final isIncome = transaction['type'] == 'Income';
    final category = transaction['category'] as String? ?? 'Other';
    final title = transaction['title'] as String? ?? category;
    final date = transaction['date']?.toString() ?? '';
    final amount = (transaction['amount'] as num).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: _categoryColor(
              transaction['type']?.toString() ?? 'Expense',
            ),
            child: Icon(
              _categoryIcon(category),
              color: AppColors.primary,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$category • ${_formatDate(date)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${isIncome ? '+' : '-'} PKR ${_formatAmount(amount)}',
              textAlign: TextAlign.end,
              style: TextStyle(
                color: isIncome
                    ? const Color(0xFF23865A)
                    : const Color(0xFFD9534F),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 4),

PopupMenuButton<String>(
  tooltip: 'Transaction options',
  icon: const Icon(
    Icons.more_vert,
    color: AppColors.textSecondary,
  ),
  onSelected: (value) {
    if (value == 'edit') {
      final editCallback = widget.onEdit;

      if (editCallback != null) {
        editCallback(transaction);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Edit functionality is not connected yet.'),
          ),
        );
      }
    } else if (value == 'delete') {
      _confirmDelete(transaction);
    }
  },
  itemBuilder: (context) => const [
    PopupMenuItem<String>(
      value: 'edit',
      child: Row(
        children: [
          Icon(Icons.edit_outlined, size: 20),
          SizedBox(width: 10),
          Text('Edit'),
        ],
      ),
    ),
    PopupMenuItem<String>(
      value: 'delete',
      child: Row(
        children: [
          Icon(
            Icons.delete_outline,
            color: Colors.red,
            size: 20,
          ),
          SizedBox(width: 10),
          Text('Delete'),
        ],
      ),
    ),
  ],
),
        ],
      ),
    );
  }
}
