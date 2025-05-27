import 'package:flutter/material.dart';
import '../../models/group_model.dart';
import '../../models/user_model.dart';
import '../../utils/formatters.dart';

class GroupBalancesCard extends StatelessWidget {
  final GroupModel group;
  final Map<String, UserModel> usersById;

  const GroupBalancesCard({
    super.key,
    required this.group,
    required this.usersById,
  });

  Widget _buildTotalsByCurrency(BuildContext context) {
    final Map<String, double> totalsByCurrency = {};
    if (group.participantBalances.isNotEmpty) {
      for (final balance in group.participantBalances) {
        final balances = balance['balances'] as Map<String, dynamic>?;
        if (balances != null) {
          balances.forEach((currency, value) {
            totalsByCurrency[currency] = (totalsByCurrency[currency] ?? 0) + (value as num).abs();
          });
        }
      }
    }
    if (totalsByCurrency.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Total Spent by Currency:', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...totalsByCurrency.entries.map((entry) => Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(
            '${formatCurrency(entry.value, entry.key)} ${entry.key}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        )),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final balances = group.participantBalances;
    final balanceEntries = balances.where((b) {
      final userBalances = b['balances'] as Map<String, dynamic>?;
      if (userBalances == null) return false;
      return userBalances.values.any((v) => (v as num).abs() > 0.01);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTotalsByCurrency(context),
        Text('Group Balances:', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (balanceEntries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('All balances are settled or negligible.', style: TextStyle(fontSize: 15, fontStyle: FontStyle.italic)),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: balanceEntries.length,
            itemBuilder: (context, index) {
              final entry = balanceEntries[index];
              final userId = entry['userId'] as String?;
              final userBalances = entry['balances'] as Map<String, dynamic>?;
              if (userId == null || userBalances == null) return const SizedBox.shrink();
              final userName = usersById[userId]?.name ?? 'Unknown user';
              return Card(
                elevation: 1,
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  leading: const Icon(Icons.account_balance_wallet_rounded),
                  title: Text(userName, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: userBalances.entries
                        .where((e) => (e.value as num).abs() > 0.01)
                        .map((e) {
                      final amount = (e.value as num).toDouble();
                      final currency = e.key;
                      final owesMoney = amount > 0.01;
                      return Text(
                        '${owesMoney ? "Owes" : "Is Owed"}: ${formatCurrency(amount.abs(), currency)} $currency',
                        style: TextStyle(
                          color: owesMoney ? Colors.red[700] : Colors.green[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
