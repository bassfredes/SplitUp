import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/advanced_add_expense_screen.dart';
import '../widgets/header.dart';

class AddExpenseScreen extends StatefulWidget {
  final String groupId;
  final List<UserModel> participants;
  final String currentUserId;
  final String groupCurrency;
  final String? groupName;

  // Corregido: Usar super parámetros
  const AddExpenseScreen({
    super.key,
    required this.groupId,
    required this.participants,
    required this.currentUserId,
    this.groupCurrency = 'CLP',
    this.groupName,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Header(
        currentRoute: '/add_expense',
        onDashboard: () => Navigator.pushReplacementNamed(context, '/dashboard'),
        onGroups: () => Navigator.pushReplacementNamed(context, '/groups'),
        onAccount: () => Navigator.pushReplacementNamed(context, '/account'),
        onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
      ),
      body: AdvancedAddExpenseScreen(
        groupId: widget.groupId,
        participants: widget.participants,
        currentUserId: widget.currentUserId,
        groupCurrency: widget.groupCurrency,
        groupName: widget.groupName,
      ),
    );
  }
}
