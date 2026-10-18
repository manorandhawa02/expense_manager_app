
import 'group_expense_storage.dart';
import 'group_settlement_storage.dart';

class GroupBalanceService {
  /// Calculates each member's paid amount, expense share,
  /// settlements, and remaining net balance.
  ///
  /// Positive balance = member should receive money.
  /// Negative balance = member owes money.
  static Future<List<Map<String, dynamic>>> calculateBalances({
    required String groupId,
    required List<String> members,
  }) async {
    final expenses = await GroupExpenseStorage.getExpenses(groupId);
    final settlements =
        await GroupSettlementStorage.getSettlements(groupId);

    final balances = <String, Map<String, dynamic>>{};

    for (final member in members) {
      balances[member] = {
        'member': member,
        'totalPaid': 0.0,
        'totalShare': 0.0,
        'settlementsPaid': 0.0,
        'settlementsReceived': 0.0,
        'netBalance': 0.0,
      };
    }

    // Process group expenses.
    for (final expense in expenses) {
      final amount = (expense['amount'] as num?)?.toDouble() ?? 0.0;
      final paidBy = expense['paidBy']?.toString();

      final sharedBy =
          (expense['sharedBy'] as List<dynamic>? ?? [])
              .map((member) => member.toString())
              .where((member) => balances.containsKey(member))
              .toSet()
              .toList();

      if (!amount.isFinite || amount <= 0) continue;

      if (paidBy != null && balances.containsKey(paidBy)) {
        balances[paidBy]!['totalPaid'] =
            (balances[paidBy]!['totalPaid'] as double) + amount;
      }

      if (sharedBy.isNotEmpty) {
        final share = amount / sharedBy.length;

        for (final member in sharedBy) {
          balances[member]!['totalShare'] =
              (balances[member]!['totalShare'] as double) + share;
        }
      }
    }

    // Process completed settlements.
    for (final settlement in settlements) {
      final amount =
          (settlement['amount'] as num?)?.toDouble() ?? 0.0;
      final paidBy = settlement['paidBy']?.toString();
      final paidTo = settlement['paidTo']?.toString();

      if (!amount.isFinite || amount <= 0) continue;
      if (paidBy == paidTo) continue;

      if (paidBy != null && balances.containsKey(paidBy)) {
        balances[paidBy]!['settlementsPaid'] =
            (balances[paidBy]!['settlementsPaid'] as double) + amount;
      }

      if (paidTo != null && balances.containsKey(paidTo)) {
        balances[paidTo]!['settlementsReceived'] =
            (balances[paidTo]!['settlementsReceived'] as double) +
                amount;
      }
    }

    // Calculate remaining balances after completed settlements.
    for (final balance in balances.values) {
      final totalPaid = balance['totalPaid'] as double;
      final totalShare = balance['totalShare'] as double;
      final settlementsPaid = balance['settlementsPaid'] as double;
      final settlementsReceived =
          balance['settlementsReceived'] as double;

      balance['netBalance'] = totalPaid -
          totalShare +
          settlementsPaid -
          settlementsReceived;
    }

    return balances.values.toList();
  }

  /// Suggests payments that can settle the remaining balances.
  /// These suggestions do not record actual payments.
  static List<Map<String, dynamic>> suggestSettlements(
    List<Map<String, dynamic>> balances,
  ) {
    final creditors = <Map<String, dynamic>>[];
    final debtors = <Map<String, dynamic>>[];

    for (final balance in balances) {
      final net =
          (balance['netBalance'] as num?)?.toDouble() ?? 0.0;

      if (net > 0.005) {
        creditors.add({
          'member': balance['member'],
          'amount': net,
        });
      } else if (net < -0.005) {
        debtors.add({
          'member': balance['member'],
          'amount': -net,
        });
      }
    }

    final suggestions = <Map<String, dynamic>>[];
    var debtorIndex = 0;
    var creditorIndex = 0;

    while (debtorIndex < debtors.length &&
        creditorIndex < creditors.length) {
      final debtor = debtors[debtorIndex];
      final creditor = creditors[creditorIndex];

      final debt = debtor['amount'] as double;
      final credit = creditor['amount'] as double;
      final payment = debt < credit ? debt : credit;

      if (payment > 0.005) {
        suggestions.add({
          'from': debtor['member'],
          'to': creditor['member'],
          'amount': double.parse(payment.toStringAsFixed(2)),
        });
      }

      debtor['amount'] = debt - payment;
      creditor['amount'] = credit - payment;

      if ((debtor['amount'] as double) < 0.005) {
        debtorIndex++;
      }

      if ((creditor['amount'] as double) < 0.005) {
        creditorIndex++;
      }
    }

    return suggestions;
  }
}
