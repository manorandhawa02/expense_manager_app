
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'group_expense_storage.dart';
import 'group_balances_screen.dart';

class GroupDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> group;

  const GroupDetailsScreen({
    super.key,
    required this.group,
  });

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  List<Map<String, dynamic>> _expenses = [];
  bool _isLoading = true;

  List<String> get _members {
    final members = widget.group['members'] as List<dynamic>? ?? [];
    return members.map((member) => member.toString()).toList();
  }

  String get _groupId => widget.group['id'].toString();

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final expenses = await GroupExpenseStorage.getExpenses(_groupId);

    if (!mounted) return;

    setState(() {
      _expenses = expenses;
      _isLoading = false;
    });
  }

  Future<void> _openBalances() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupBalancesScreen(
          group: widget.group,
        ),
      ),
    );

    if (mounted) {
      await _loadExpenses();
    }
  }

  Future<void> _showAddExpenseDialog() async {
    if (_members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add group members first.'),
        ),
      );
      return;
    }

    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    String? paidBy;
    final sharedBy = <String>{..._members};

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Shared Expense'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Expense description',
                        hintText: 'e.g. Dinner, Groceries',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Total amount',
                        prefixText: 'Rs. ',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Paid by',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: paidBy,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        hintText: 'Select payer',
                      ),
                      items: _members.map((member) {
                        return DropdownMenuItem<String>(
                          value: member,
                          child: Text(member),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() => paidBy = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Split between',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    ..._members.map((member) {
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(member),
                        value: sharedBy.contains(member),
                        onChanged: (checked) {
                          setDialogState(() {
                            if (checked == true) {
                              sharedBy.add(member);
                            } else {
                              sharedBy.remove(member);
                            }
                          });
                        },
                      );
                    }),
                    const Text(
                      'The amount will initially be split equally '
                      'between the selected members.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final description =
                        descriptionController.text.trim();
                    final amount = double.tryParse(
                      amountController.text.trim(),
                    );

                    if (description.isEmpty ||
                        amount == null ||
                        !amount.isFinite ||
                        amount <= 0 ||
                        paidBy == null ||
                        sharedBy.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Enter valid details and select members.',
                          ),
                        ),
                      );
                      return;
                    }

                    await GroupExpenseStorage.addExpense(
                      groupId: _groupId,
                      description: description,
                      amount: amount,
                      paidBy: paidBy!,
                      sharedBy: sharedBy.toList(),
                    );

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, true);
                    }
                  },
                  child: const Text('Save Expense'),
                ),
              ],
            );
          },
        );
      },
    );

    descriptionController.dispose();
    amountController.dispose();

    if (result == true && mounted) {
      await _loadExpenses();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shared expense saved.')),
      );
    }
  }

  Future<void> _deleteExpense(
    Map<String, dynamic> expense,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text(
          'Delete "${expense['description']}" from this group?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await GroupExpenseStorage.deleteExpense(
      expense['id'].toString(),
    );

    if (!mounted) return;

    await _loadExpenses();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expense deleted.')),
    );
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final groupName = widget.group['name']?.toString() ?? 'Group';

    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      appBar: AppBar(
        title: Text(groupName),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadExpenses,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        groupName,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text('${_members.length} group members'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _members.map((member) {
                          return Chip(
                            avatar: const Icon(
                              Icons.person_outline,
                              size: 18,
                            ),
                            label: Text(member),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              // View Balances button
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openBalances,
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: const Text('View Balances & Settlements'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Text(
                'Shared Expense History',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_expenses.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long, size: 40),
                        SizedBox(height: 8),
                        Text('No shared expenses yet'),
                        SizedBox(height: 4),
                        Text('Add an expense to get started.'),
                      ],
                    ),
                  ),
                )
              else
                ..._expenses.map((expense) {
                  final amount =
                      (expense['amount'] as num?)?.toDouble() ?? 0;

                  final participants =
                      (expense['sharedBy'] as List<dynamic>? ?? [])
                          .map((member) => member.toString())
                          .toList();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.mint,
                        child: const Icon(Icons.receipt_long),
                      ),
                      title: Text(
                        expense['description']?.toString() ??
                            'Expense',
                      ),
                      subtitle: Text(
                        'Paid by ${expense['paidBy']}\n'
                        '${_formatDate(expense['date'])}\n'
                        'Split between: ${participants.join(', ')}',
                      ),
                      isThreeLine: true,
                      trailing: SizedBox(
                        width: 115,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Rs. ${amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 32,
                              child: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                iconSize: 22,
                                onSelected: (value) {
                                  if (value == 'delete') {
                                    _deleteExpense(expense);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Text('Delete expense'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
