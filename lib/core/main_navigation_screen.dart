import 'package:flutter/material.dart';
import '../features/groups/group_screen.dart';
import '../features/home/home_screen.dart';
import '../features/transaction/add_expense_screen.dart';
import '../features/transaction/transactions_screen.dart';
import '../features/transaction/transaction_storage.dart';
import '../widgets/bottom_navigation.dart';
import 'theme/app_colors.dart';
import '../features/reports/reports_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final GlobalKey<GroupsScreenState> _groupsKey =
    GlobalKey<GroupsScreenState>();
  final GlobalKey<HomeScreenState> _homeKey =
      GlobalKey<HomeScreenState>();

  final GlobalKey<TransactionsScreenState> _transactionsKey =
      GlobalKey<TransactionsScreenState>();

  List<Widget> get _screens => [
  HomeScreen(
  key: _homeKey,
  onNavigate: _onNavigationTap,
  onAddTransaction: _openAddTransaction,
),
  TransactionsScreen(
    key: _transactionsKey,
    onEdit: _editTransaction,
    onDelete: _deleteTransaction,
  ),
  GroupsScreen(key: _groupsKey),
  ReportsScreen(
  onTransactionsChanged: _refreshScreens,
),
];

  Future<void> _refreshScreens() async {
    await Future.wait([
      _homeKey.currentState?.loadTransactions() ??
          Future<void>.value(),
      _transactionsKey.currentState?.loadTransactions() ??
          Future<void>.value(),
    ]);
  }

  Future<void> _openAddTransaction() async {
    final transaction = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddExpenseScreen(),
      ),
    );

    if (transaction == null || !mounted) return;

    await TransactionStorage.addTransaction(transaction);
    await _refreshScreens();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transaction saved on this device.'),
      ),
    );
  }

  Future<void> _editTransaction(
    Map<String, dynamic> transaction,
  ) async {
    final updatedTransaction =
        await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(
          existingTransaction: transaction,
        ),
      ),
    );

    if (updatedTransaction == null || !mounted) return;

    final success = await TransactionStorage.updateTransaction(
      updatedTransaction,
    );

    if (!mounted) return;

    if (success) {
      await _refreshScreens();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction updated successfully.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update this transaction.'),
        ),
      );
    }
  }

  Future<void> _deleteTransaction(
    Map<String, dynamic> transaction,
  ) async {
    final id = transaction['id']?.toString();

    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to identify this transaction.'),
        ),
      );
      return;
    }

    final success = await TransactionStorage.deleteTransaction(id);

    if (!mounted) return;

    if (success) {
      await _refreshScreens();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction deleted successfully.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction could not be found.'),
        ),
      );
    }
  }

  void _onNavigationTap(int index) {
  setState(() {
    _currentIndex = index;
  });

  if (index == 0) {
    _homeKey.currentState?.loadTransactions();
  } else if (index == 1) {
    _transactionsKey.currentState?.loadTransactions();
  } else if (index == 2) {
    _groupsKey.currentState?.loadGroups();
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigation(
        currentIndex: _currentIndex,
        onTap: _onNavigationTap,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTransaction,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,
    );
  }
}

// ignore: unused_element
class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          '$title screen will be implemented next.',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}