import 'package:flutter/material.dart';
import '../../app.dart';
import '../../core/theme/app_colors.dart';
import 'add_expense_screen.dart';
import 'transaction_storage.dart';
import 'recurring_transactions_screen.dart';
class TransactionsScreen extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic> transaction)? onEdit;
  final Future<void> Function(Map<String, dynamic> transaction)? onDelete;

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
String _searchQuery = '';
String _sortBy = 'Newest first';

final TextEditingController _searchController =
    TextEditingController();

List<Map<String, dynamic>> _transactions = [];
bool _isLoading = true;


@override
void dispose() {
  _searchController.dispose();
  super.dispose();
}

  
List<Map<String, dynamic>> get _filteredTransactions {
  final query = _searchQuery.trim().toLowerCase();

  final results = _transactions.where((transaction) {
    final matchesType = _selectedFilter == 'All' ||
        transaction['type'] == _selectedFilter;

    final title = transaction['title']?.toString() ?? '';
    final category = transaction['category']?.toString() ?? '';
    final notes = transaction['notes']?.toString() ?? '';

    final matchesSearch = query.isEmpty ||
        title.toLowerCase().contains(query) ||
        category.toLowerCase().contains(query) ||
        notes.toLowerCase().contains(query);

    return matchesType && matchesSearch;
  }).toList();

  int compareDates(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final dateA = DateTime.tryParse(a['date']?.toString() ?? '') ??
        DateTime(2000);
    final dateB = DateTime.tryParse(b['date']?.toString() ?? '') ??
        DateTime(2000);

    return dateA.compareTo(dateB);
  }

  double amountOf(Map<String, dynamic> transaction) {
    final amount = transaction['amount'];
    return amount is num ? amount.toDouble() : 0;
  }

  switch (_sortBy) {
    case 'Oldest first':
      results.sort(compareDates);
      break;
    case 'Highest amount':
      results.sort(
        (a, b) => amountOf(b).compareTo(amountOf(a)),
      );
      break;
    case 'Lowest amount':
      results.sort(
        (a, b) => amountOf(a).compareTo(amountOf(b)),
      );
      break;
    case 'Newest first':
    default:
      results.sort(
        (a, b) => compareDates(b, a),
      );
  }

  return results;
}


 Future<void> _openRecurringTransactions() async {
  await Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => const RecurringTransactionsScreen(),
    ),
  );

  if (!mounted) return;

  await loadTransactions();
}

  @override
  void initState() {
    super.initState();
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    try {
      final savedTransactions = await TransactionStorage.getTransactions();

      if (!mounted) return;

      setState(() {
        _transactions = savedTransactions;
        _isLoading = false;
      });
    } catch (_) {
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
        .fold<double>(0, (total, transaction) {
      final amount = transaction['amount'];
      return total + (amount is num ? amount.toDouble() : 0);
    });
  }

  String _formatAmount(num amount) {
    return CurrencyProvider.of(context).formatAmount(amount);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (type == 'Income') {
      return isDark
          ? const Color(0xFF214B3B)
          : const Color(0xFFDDF5E8);
    }

    return isDark
        ? const Color(0xFF4A3826)
        : const Color(0xFFFFE6C7);
  }

  Future<void> _editTransaction(
    Map<String, dynamic> transaction,
  ) async {
    try {
      if (widget.onEdit != null) {
        await widget.onEdit!(transaction);

        if (mounted) {
          await loadTransactions();
        }
        return;
      }

      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => AddExpenseScreen(
            existingTransaction: transaction,
          ),
        ),
      );

      if (result == null || !mounted) return;

      final updated = await TransactionStorage.updateTransaction(result);

      if (!mounted) return;

      if (!updated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction could not be found.'),
          ),
        );
        return;
      }

      await loadTransactions();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction updated successfully.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update transaction.'),
        ),
      );
    }
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
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      if (widget.onDelete != null) {
        await widget.onDelete!(transaction);

        if (mounted) {
          await loadTransactions();
        }
        return;
      }

      final id = transaction['id']?.toString();

      if (id == null || id.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This transaction has no valid ID.'),
          ),
        );
        return;
      }

      final deleted = await TransactionStorage.deleteTransaction(id);

      if (!mounted) return;

      if (!deleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction could not be found.'),
          ),
        );
        return;
      }

      await loadTransactions();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction deleted successfully.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to delete transaction.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.textPrimaryFor(context);
    final secondaryColor = AppColors.textSecondaryFor(context);
    final surfaceColor = AppColors.surfaceFor(context);
    final borderColor = AppColors.borderFor(context);
    final primaryColor = AppColors.primaryFor(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadTransactions,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transactions',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Track your income and expenses',
            style: TextStyle(
              fontSize: 14,
              color: secondaryColor,
            ),
          ),
        ],
      ),
    ),
    IconButton(
      tooltip: 'Recurring transactions',
      onPressed: _openRecurringTransactions,
      icon: const Icon(Icons.event_repeat_outlined),
      color: primaryColor,
    ),
  ],
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
                      const Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Colors.white70,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Total Transactions',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isLoading ? '...' : '${_filteredTransactions.length}',
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

                Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 14),

                
TextField(
  controller: _searchController,
  onChanged: (value) {
    setState(() {
      _searchQuery = value;
    });
  },
  style: TextStyle(color: textColor),
  decoration: InputDecoration(
    hintText: 'Search title, category, or notes...',
    hintStyle: TextStyle(color: secondaryColor),
    prefixIcon: Icon(Icons.search, color: secondaryColor),
    suffixIcon: _searchQuery.isNotEmpty
        ? IconButton(
            tooltip: 'Clear search',
            icon: const Icon(Icons.close),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
            },
          )
        : null,
    filled: true,
    fillColor: surfaceColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: primaryColor, width: 1.5),
    ),
  ),
),
const SizedBox(height: 14),


Row(
  children: [
    Icon(
      Icons.sort,
      color: secondaryColor,
      size: 20,
    ),
    const SizedBox(width: 8),
    Text(
      'Sort by',
      style: TextStyle(color: secondaryColor),
    ),
    const Spacer(),
    DropdownButton<String>(
      value: _sortBy,
      dropdownColor: surfaceColor,
      underline: const SizedBox.shrink(),
      style: TextStyle(
        color: textColor,
        fontSize: 13,
      ),
      items: const [
        DropdownMenuItem(
          value: 'Newest first',
          child: Text('Newest first'),
        ),
        DropdownMenuItem(
          value: 'Oldest first',
          child: Text('Oldest first'),
        ),
        DropdownMenuItem(
          value: 'Highest amount',
          child: Text('Highest amount'),
        ),
        DropdownMenuItem(
          value: 'Lowest amount',
          child: Text('Lowest amount'),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          _sortBy = value;
        });
      },
    ),
  ],
),
const SizedBox(height: 14),



                // Filters
                Row(
                  children: ['All', 'Expense', 'Income'].map((filter) {
                    final selected = _selectedFilter == filter;

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            filter == 'Expense' ? 'Expenses' : filter,
                          ),
                          selected: selected,
                          showCheckmark: false,
                          selectedColor: primaryColor,
                          backgroundColor: surfaceColor,
                          side: BorderSide(
                            color: selected
                                ? (primaryColor)
                                : borderColor,
                          ),
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : textColor,
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

                // Transaction list
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
                            color: secondaryColor,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
    ? 'No matching transactions'
    : 'No transactions yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _searchQuery.isNotEmpty
    ? 'Try another title, category, or keyword.'
    : 'Tap + to add your first transaction.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: secondaryColor),
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
            _formatAmount(amount),
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
    final category = transaction['category']?.toString() ?? 'Other';
    final title = transaction['title']?.toString() ?? category;
    final date = transaction['date']?.toString() ?? '';
    final rawAmount = transaction['amount'];
    final amount = rawAmount is num ? rawAmount.toDouble() : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.borderFor(context),
        ),
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
              color: AppColors.primaryFor(context),
              size: 23,
            ),
          ),
          const SizedBox(width: 12),

          // Transaction details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimaryFor(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$category • ${_formatDate(date)}',
                  style: TextStyle(
                    color: AppColors.textSecondaryFor(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Converted amount
          Flexible(
            child: Text(
              '${isIncome ? '+' : '-'}${_formatAmount(amount)}',
              textAlign: TextAlign.end,
              maxLines: 2,
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

          // Edit and delete options
          PopupMenuButton<String>(
            tooltip: 'Transaction options',
            icon: Icon(
              Icons.more_vert,
              color: AppColors.textSecondaryFor(context),
            ),
            onSelected: (value) {
              if (value == 'edit') {
                _editTransaction(transaction);
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
