import 'package:flutter/material.dart';
import '../models/expense_model.dart';
import '../models/user_model.dart';
import '../config/constants.dart';

class ExpenseTile extends StatelessWidget {
  final ExpenseModel expense;
  final Map<String, UserModel> usersById;
  final String currentUserId;
  final void Function()? onTap;

  const ExpenseTile({
    super.key,
    required this.expense,
    required this.usersById,
    required this.currentUserId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Main payer (the first in the payers list)
    final payerId = expense.payers.isNotEmpty ? expense.payers.first['userId'] as String : expense.createdBy;
    final payer = usersById[payerId];
    // Avatar
    final avatar = (payer != null && payer.photoUrl != null && payer.photoUrl!.isNotEmpty)
        ? CircleAvatar(backgroundImage: NetworkImage(payer.photoUrl!), radius: 22)
        : CircleAvatar(
            radius: 22,
            backgroundColor: Colors.teal[100],
            child: Text(
              payer != null && payer.name.isNotEmpty ? payer.name[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 22, color: Colors.white),
            ),
          );
    // Category icon
    final categoryIcon = _getCategoryIcon(expense.category);
    final textColor = DefaultTextStyle.of(context).style.color;
    // Amount corresponding to the current user
    double userShare = 0.0;
    if (expense.customSplits != null) {
      final split = expense.customSplits!.firstWhere(
        (s) => s['userId'] == currentUserId,
        orElse: () => <String, dynamic>{},
      );
      if (split['amount'] != null) {
        userShare = (split['amount'] as num).toDouble();
      }
    } else if (expense.participantIds.contains(currentUserId)) {
      userShare = expense.amount / expense.participantIds.length;
    }
    // Did the user pay?
    double paidByUser = 0.0;
    for (final p in expense.payers) {
      if (p['userId'] == currentUserId) {
        paidByUser += (p['amount'] as num).toDouble();
      }
    }
    final net = paidByUser - userShare;
    final netColor = net < 0 ? Colors.red : (net > 0 ? Colors.green : Colors.grey[700]);
    final netLabel = net < 0 ? 'You owe' : (net > 0 ? 'You are owed' : 'Settled');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: ListTile(
        onTap: onTap,
        leading: avatar,
        title: Row(
          children: [
            if (categoryIcon != null) ...[
              Icon(categoryIcon, color: textColor, size: 20),
              const SizedBox(width: 6),
            ],
            Expanded(child: Text(expense.description, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paid by: ${payer?.name ?? payerId}'),
            Text(expense.date.toLocal().toString().split(' ')[0]),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatAmountWithCurrency(expense.amount, expense.currency),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            if (net != 0)
              Text(
                '$netLabel: ${_formatAmountWithCurrency(net.abs(), expense.currency)}',
                style: TextStyle(color: netColor, fontWeight: FontWeight.w600, fontSize: 13),
              )
            else
              const Text('Settled: \$ 0', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  String _formatAmountWithCurrency(double amount, String currency) {
    switch (currency) {
      case 'CLP':
        return '\$${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} CLP';
      case 'USD':
        return '\$${amount.toStringAsFixed(2)} USD';
      case 'EUR':
        return '€${amount.toStringAsFixed(2)} EUR';
      default:
        return '\$${amount.toStringAsFixed(2)}';
    }
  }

  IconData? _getCategoryIcon(String? category) {
    final cat = kExpenseCategories.firstWhere(
      (c) => c['key'] == category?.toLowerCase(),
      orElse: () => <String, dynamic>{},
    );
    if (cat.isEmpty) return null;
    switch (cat['icon']) {
      case 'fastfood':
        return Icons.fastfood;
      case 'restaurant':
        return Icons.restaurant;
      case 'directions_car':
        return Icons.directions_car;
      case 'directions_transit':
        return Icons.directions_transit;
      case 'directions_bus':
        return Icons.directions_bus;
      case 'home':
        return Icons.home;
      case 'local_play':
        return Icons.local_play;
      case 'celebration':
        return Icons.celebration;
      case 'flight':
        return Icons.flight;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'category':
        return Icons.category;
      default:
        return null;
    }
  }
}
