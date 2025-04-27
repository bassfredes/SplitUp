import '../models/expense_model.dart';
import '../models/group_model.dart';

class DebtCalculatorService {
  // Calcula el saldo de cada usuario en un grupo
  Map<String, double> calculateBalances(List<ExpenseModel> expenses, GroupModel group) {
    final Map<String, double> balances = { for (var id in group.participantIds) id: 0.0 };
    for (final expense in expenses) {
      // Suma lo que pagó cada usuario
      for (final payer in expense.payers) {
        final userId = payer['userId'] as String;
        final paid = (payer['amount'] as num).toDouble();
        balances[userId] = (balances[userId] ?? 0) + paid;
      }
      // Resta lo que debe pagar cada participante
      if (expense.customSplits != null) {
        for (final split in expense.customSplits!) {
          final userId = split['userId'] as String;
          final share = (split['amount'] as num).toDouble();
          balances[userId] = (balances[userId] ?? 0) - share;
        }
      } else {
        // División igualitaria
        final share = expense.amount / expense.participantIds.length;
        for (final userId in expense.participantIds) {
          balances[userId] = (balances[userId] ?? 0) - share;
        }
      }
    }
    return balances;
  }

  // Simplificación de deudas (algoritmo greedy)
  List<Map<String, dynamic>> simplifyDebts(Map<String, double> balances) {
    final List<MapEntry<String, double>> debtors = [];
    final List<MapEntry<String, double>> creditors = [];
    balances.forEach((userId, balance) {
      if (balance < -0.01) debtors.add(MapEntry(userId, -balance));
      if (balance > 0.01) creditors.add(MapEntry(userId, balance));
    });
    debtors.sort((a, b) => b.value.compareTo(a.value));
    creditors.sort((a, b) => b.value.compareTo(a.value));
    final List<Map<String, dynamic>> transactions = [];
    int i = 0, j = 0;
    while (i < debtors.length && j < creditors.length) {
      final amount = debtors[i].value < creditors[j].value ? debtors[i].value : creditors[j].value;
      transactions.add({
        'from': debtors[i].key,
        'to': creditors[j].key,
        'amount': amount,
      });
      debtors[i] = MapEntry(debtors[i].key, debtors[i].value - amount);
      creditors[j] = MapEntry(creditors[j].key, creditors[j].value - amount);
      if (debtors[i].value < 0.01) i++;
      if (creditors[j].value < 0.01) j++;
    }
    return transactions;
  }
}
