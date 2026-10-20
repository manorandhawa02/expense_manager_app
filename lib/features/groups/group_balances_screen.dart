
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'group_balance_service.dart';
import 'group_settlement_storage.dart';

class GroupBalancesScreen extends StatefulWidget {
  final Map<String, dynamic> group;

  const GroupBalancesScreen({
    super.key,
    required this.group,
  });

  @override
  State<GroupBalancesScreen> createState() =>
      _GroupBalancesScreenState();
}

class _GroupBalancesScreenState extends State<GroupBalancesScreen> {
  List<Map<String, dynamic>> _balances = [];
  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> _settlements = [];

  bool _isLoading = true;
  bool _isRecording = false;

  List<String> get _members =>
      (widget.group['members'] as List<dynamic>? ?? [])
          .map((member) => member.toString())
          .toList();

  String get _groupId => widget.group['id'].toString();

  @override
  void initState() {
    super.initState();
    _loadBalances();
  }

  Future<void> _loadBalances() async {
    try {
      final balances = await GroupBalanceService.calculateBalances(
        groupId: _groupId,
        members: _members,
      );

      final suggestions =
          GroupBalanceService.suggestSettlements(balances);

      final settlements =
          await GroupSettlementStorage.getSettlements(_groupId);

      if (!mounted) return;

      setState(() {
        _balances = balances;
        _suggestions = suggestions;
        _settlements = settlements;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load balances. Please try again.'),
        ),
      );
    }
  }

  Future<void> _recordSettlement(
    Map<String, dynamic> suggestion,
  ) async {
    if (_isRecording) return;

    final from = suggestion['from'].toString();
    final to = suggestion['to'].toString();
    final amount = (suggestion['amount'] as num).toDouble();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Record Settlement'),
        content: Text(
          'Confirm that $from has paid $to '
          'Rs. ${amount.toStringAsFixed(2)}?\n\n'
          'Only record this after the payment has actually been made.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Confirm Payment'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isRecording = true;
    });

    try {
      await GroupSettlementStorage.addSettlement(
        groupId: _groupId,
        paidBy: from,
        paidTo: to,
        amount: amount,
      );

      await _loadBalances();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settlement recorded successfully.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not record settlement. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }
    }
  }

  Future<void> _deleteSettlement(
    Map<String, dynamic> settlement,
  ) async {
    final paidBy = settlement['paidBy']?.toString() ?? 'Member';
    final paidTo = settlement['paidTo']?.toString() ?? 'Member';
    final amount =
        (settlement['amount'] as num?)?.toDouble() ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Settlement?'),
        content: Text(
          'Remove the recorded payment of '
          'Rs. ${amount.toStringAsFixed(2)} from $paidBy to $paidTo?\n\n'
          'The group balances will be recalculated.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await GroupSettlementStorage.deleteSettlement(
        settlement['id'].toString(),
      );

      await _loadBalances();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settlement deleted and balances updated.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete settlement. Please try again.'),
        ),
      );
    }
  }

  String _formatAmount(double amount) =>
      'Rs. ${amount.abs().toStringAsFixed(2)}';

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');

    if (date == null) return 'Date unavailable';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final groupName =
        widget.group['name']?.toString() ?? 'Group Balances';

    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      appBar: AppBar(
        title: Text('$groupName Balances'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadBalances,
          child: _isLoading
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 250),
                    Center(child: CircularProgressIndicator()),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    // MEMBER BALANCES
                    Text(
                      'Member Balances',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),

                    ..._balances.map((balance) {
                      final name = balance['member'].toString();
                      final net =
                          (balance['netBalance'] as num).toDouble();

                      final status = net > 0.005
                          ? 'Should receive'
                          : net < -0.005
                              ? 'Owes'
                              : 'Settled';

                      final color = net.abs() < 0.005
                          ? AppColors.textSecondaryFor(context)
                          : net > 0
                              ? AppColors.primaryFor(context)
                              : Colors.red;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.mint,
                            child: Text(
                              name.isNotEmpty
                                  ? name[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          title: Text(name),
                          subtitle: Text(status),
                          trailing: Text(
                            '${net < -0.005 ? '-' : net > 0.005 ? '+' : ''}'
                            '${_formatAmount(net)}',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 20),

                    // SUGGESTED SETTLEMENTS
                    Text(
                      'Suggested Settlements',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),

                    if (_suggestions.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'Everyone is settled up!',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ..._suggestions.map((suggestion) {
                        final from = suggestion['from'].toString();
                        final to = suggestion['to'].toString();
                        final amount =
                            (suggestion['amount'] as num).toDouble();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$from pays $to',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(_formatAmount(amount)),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton(
                                    onPressed: _isRecording
                                        ? null
                                        : () => _recordSettlement(
                                              suggestion,
                                            ),
                                    child: Text(
                                      _isRecording
                                          ? 'Recording...'
                                          : 'Record Payment',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 20),

                    // SETTLEMENT HISTORY
                    Text(
                      'Settlement History',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),

                    if (_settlements.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.history,
                                size: 40,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'No settlements recorded yet',
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Confirmed payments will appear here.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._settlements.map((settlement) {
                        final paidBy =
                            settlement['paidBy']?.toString() ?? 'Member';
                        final paidTo =
                            settlement['paidTo']?.toString() ?? 'Member';
                        final amount =
                            (settlement['amount'] as num?)?.toDouble() ?? 0;
                        final date = _formatDate(settlement['date']);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.mint,
                              child: const Icon(
                                Icons.check_circle_outline,
                              ),
                            ),
                            title: Text('$paidBy paid $paidTo'),
                            subtitle: Text(date),
                            trailing: SizedBox(
                              width: 115,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        _formatAmount(amount),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    onSelected: (value) {
                                      if (value == 'delete') {
                                        _deleteSettlement(settlement);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Text('Delete settlement'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 24),
                  ],
                ),
        ),
      ),
    );
  }
}
