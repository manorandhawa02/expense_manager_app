import 'package:flutter/material.dart';
import '../groups/group_storage.dart';
import '../groups/group_balances_screen.dart';
import '../../app.dart';
import '../../core/theme/app_colors.dart';
import '../transaction/transaction_storage.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;
  final VoidCallback? onAddTransaction;

  const HomeScreen({super.key, this.onNavigate, this.onAddTransaction});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    loadTransactions();
  }
  Future<void> _openSettleUp() async {
  try {
    final groups = await GroupStorage.getGroups();

    if (!mounted) return;

    if (groups.isEmpty) {
      _showFeatureMessage('Create a group first to use Settle Up');
      return;
    }

    if (groups.length == 1) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupBalancesScreen(group: groups.first),
        ),
      );
      return;
    }

    final selectedGroup = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Select a group'),
        children: groups.map((group) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, group),
            child: Text(group['name']?.toString() ?? 'Unnamed Group'),
          );
        }).toList(),
      ),
    );

    if (selectedGroup == null || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupBalancesScreen(group: selectedGroup),
      ),
    );
  } catch (_) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open Settle Up.')),
    );
  }
}

  Future<void> loadTransactions() async {
    try {
      final savedTransactions = await TransactionStorage.getTransactions();

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
        const SnackBar(content: Text('Unable to load dashboard transactions.')),
      );
    }
  }

  double _totalFor(String type, {bool thisMonth = false}) {
    final now = DateTime.now();

    return _transactions
        .where((transaction) {
          if (transaction['type'] != type) return false;
          if (!thisMonth) return true;

          final date = DateTime.tryParse(transaction['date']?.toString() ?? '');

          return date != null &&
              date.year == now.year &&
              date.month == now.month;
        })
        .fold<double>(0, (total, transaction) {
          final amount = transaction['amount'];
          if (amount is! num) return total;
          return total + amount.toDouble();
        });
  }


 String _displayAmount(double amount) {
  if (_isLoading) return '...';

  return CurrencyProvider.of(context).formatAmount(amount);
}

  List<Map<String, dynamic>> get _recentTransactions {
    final sorted = List<Map<String, dynamic>>.from(_transactions);

    sorted.sort((a, b) {
      final dateA = DateTime.tryParse(a['date']?.toString() ?? '');
      final dateB = DateTime.tryParse(b['date']?.toString() ?? '');

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;

      return dateB.compareTo(dateA);
    });

    return sorted.take(5).toList();
  }

  Map<String, double> get _categoryTotals {
    final totals = <String, double>{};

    for (final transaction in _transactions) {
      if (transaction['type'] != 'Expense') continue;

      final category = transaction['category']?.toString().trim();

      final amount = transaction['amount'];

      if (category == null || category.isEmpty || amount is! num) {
        continue;
      }

      totals[category] = (totals[category] ?? 0) + amount.toDouble();
    }

    return Map.fromEntries(
      totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Date unavailable';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant_outlined;
      case 'transport':
        return Icons.directions_bus_outlined;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'bills':
        return Icons.receipt_long_outlined;
      case 'health':
        return Icons.health_and_safety_outlined;
      case 'education':
        return Icons.school_outlined;
      case 'entertainment':
        return Icons.movie_outlined;
      case 'salary':
        return Icons.work_outline;
      case 'freelance':
        return Icons.laptop_outlined;
      case 'business':
        return Icons.store_outlined;
      case 'investment':
        return Icons.trending_up;
      case 'gift':
        return Icons.card_giftcard_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  void _showFeatureMessage(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature will be implemented next.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalIncome = _totalFor('Income');
    final totalExpenses = _totalFor('Expense');
    final balance = totalIncome - totalExpenses;

    final monthlyIncome = _totalFor('Income', thisMonth: true);
    final monthlyExpenses = _totalFor('Expense', thisMonth: true);
    final monthlySavings = monthlyIncome - monthlyExpenses;

    final categories = _categoryTotals;
    final totalCategorizedExpenses = categories.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );

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
                // HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryFor(context),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'My Expenses',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.mint,
                      child: Icon(
                        Icons.person_outline,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // BALANCE CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(24),
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
                            'Total Balance',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _displayAmount(balance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Income',
                              amount: _displayAmount(totalIncome),
                              icon: Icons.arrow_downward,
                              iconColor: AppColors.mint,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Expenses',
                              amount: _displayAmount(totalExpenses),
                              icon: Icons.arrow_upward,
                              iconColor: const Color(0xFFFFA69A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // QUICK ACTIONS
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryFor(context),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildQuickAction(
                        icon: Icons.add,
                        label: 'Add Expense',
                        onTap: () => widget.onAddTransaction?.call(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildQuickAction(
                        icon: Icons.group_outlined,
                        label: 'Groups',
                        onTap: () => widget.onNavigate?.call(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickAction(
                        icon: Icons.swap_horiz,
                        label: 'Settle Up',
                        onTap: _openSettleUp,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildQuickAction(
                        icon: Icons.pie_chart_outline,
                        label: 'Reports',
                        onTap: () => widget.onNavigate?.call(3),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // MONTHLY SUMMARY
                Text(
                  'This Month',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryFor(context),
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: _buildMonthlyCard(
                        title: 'Income',
                        amount: _displayAmount(monthlyIncome),
                        icon: Icons.arrow_downward,
                        color: AppColors.mint,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMonthlyCard(
                        title: 'Expenses',
                        amount: _displayAmount(monthlyExpenses),
                        icon: Icons.arrow_upward,
                        color: const Color(0xFFFFA69A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildMonthlyCard(
                  title: 'Savings',
                  amount: _displayAmount(monthlySavings),
                  icon: Icons.account_balance_wallet_outlined,
                  color: const Color(0xFFF4D58D),
                ),

                const SizedBox(height: 28),

                // RECENT TRANSACTIONS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Transactions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryFor(context),
                      ),
                    ),
                    TextButton(
                      onPressed: () => widget.onNavigate?.call(1),
                      child: const Text('See all'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_recentTransactions.isEmpty)
                  _buildEmptyCard(
                    icon: Icons.receipt_long_outlined,
                    message: 'No transactions yet.',
                    detail: 'Add your first transaction to get started.',
                  )
                else
                  ..._recentTransactions.map((transaction) {
                    final type = transaction['type']?.toString() ?? 'Expense';
                    final amount =
                        (transaction['amount'] as num?)?.toDouble() ?? 0;
                    final category =
                        transaction['category']?.toString() ?? 'Other';
                    final title =
                        transaction['title']?.toString().trim().isNotEmpty ==
                            true
                        ? transaction['title'].toString()
                        : category;
                    final isIncome = type == 'Income';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: AppColors.surfaceFor(context),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.mint,
                          child: Icon(
                            _categoryIcon(category),
                            color: AppColors.primary,
                          ),
                        ),
                        title: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '$category • ${_formatDate(transaction['date'])}',
                        ),
                        trailing: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${isIncome ? '+' : '-'}${CurrencyProvider.of(context).formatAmount(amount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isIncome ? AppColors.primary : Colors.red,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 28),

                // CATEGORY-WISE SPENDING
                Text(
                  'Spending by Category',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryFor(context),
                  ),
                ),
                const SizedBox(height: 12),

                if (_isLoading)
                  const LinearProgressIndicator()
                else if (categories.isEmpty)
                  _buildEmptyCard(
                    icon: Icons.pie_chart_outline,
                    message: 'No expense categories yet.',
                    detail: 'Your expense breakdown will appear here.',
                  )
                else
                  Card(
                    color: AppColors.surfaceFor(context),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: categories.entries.map((entry) {
                          final fraction = totalCategorizedExpenses > 0
                              ? entry.value / totalCategorizedExpenses
                              : 0.0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _categoryIcon(entry.key),
                                      size: 20,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        entry.key,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      CurrencyProvider.of(context).formatAmount(entry.value),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: fraction,
                                    minHeight: 8,
                                    backgroundColor: AppColors.borderFor(
                                      context,
                                    ),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '${(fraction * 100).toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondaryFor(
                                        context,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) return 'GOOD MORNING 👋';
    if (hour < 17) return 'GOOD AFTERNOON 👋';
    return 'GOOD EVENING 👋';
  }

  Widget _buildEmptyCard({
    required IconData icon,
    required String message,
    required String detail,
  }) {
    return Card(
      color: AppColors.surfaceFor(context),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 36, color: AppColors.textSecondaryFor(context)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondaryFor(context),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surfaceFor(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderFor(context)),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 26),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimaryFor(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
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
          CircleAvatar(
            radius: 18,
            backgroundColor: color,
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textSecondaryFor(context),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: TextStyle(
                color: AppColors.textPrimaryFor(context),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
