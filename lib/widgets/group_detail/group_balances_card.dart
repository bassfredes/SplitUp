import 'package:flutter/material.dart';
import '../../models/group_model.dart';
import '../../models/expense_model.dart';
import '../../models/user_model.dart';
import '../../services/debt_calculator_service.dart';
import '../../utils/formatters.dart';

class GroupBalancesCard extends StatelessWidget {
  final GroupModel group;
  final List<ExpenseModel> expenses;
  final Map<String, UserModel> usersById;

  const GroupBalancesCard({
    super.key,
    required this.group,
    required this.expenses,
    required this.usersById,
  });

  Widget _buildTotalsByCurrency(Map<String, double> totalsByCurrency, BuildContext context) {
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
    if (expenses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(child: Text('No expenses to calculate balances from.')),
      );
    }

    final calculator = DebtCalculatorService();
    final balances = calculator.calculateBalances(expenses, group);
    
    final Map<String, double> totalsByCurrency = {};
    for (var expense in expenses) {
      totalsByCurrency.update(
        expense.currency,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    final balanceEntries = balances.entries.where((e) => e.value.abs() > 0.01).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTotalsByCurrency(totalsByCurrency, context),
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
            physics: const NeverScrollableScrollPhysics(), // Para usar dentro de SingleChildScrollView
            itemCount: balanceEntries.length,
            itemBuilder: (context, index) {
              final entry = balanceEntries[index];
              final userId = entry.key;
              final amount = entry.value;
              final userName = usersById[userId]?.name ?? 'Unknown User';
              final bool owesMoney = amount > 0;

              return Card(
                elevation: 1,
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: owesMoney ? Colors.red[100] : Colors.green[100],
                    child: Icon(
                      owesMoney ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      color: owesMoney ? Colors.red[700] : Colors.green[700],
                      size: 20,
                    ),
                  ),
                  title: Text(userName, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    '${owesMoney ? "Owes" : "Is owed"}: ${formatCurrency(amount.abs(), group.currency)} ${group.currency}',
                    style: TextStyle(color: owesMoney ? Colors.red[700] : Colors.green[700], fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  // Se podrían añadir más detalles o acciones aquí si fuera necesario
                ),
              );
            },
          ),
      ],
    );
  }
}
