import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/advanced_add_expense_screen.dart';
import '../widgets/header.dart';
import '../widgets/app_footer.dart';

class AddExpenseScreen extends StatefulWidget {
  final String groupId;
  final List<UserModel> participants;
  final String currentUserId;
  final String groupCurrency;
  final String? groupName;

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
      backgroundColor: const Color(0xFFF6F8FA),
      body: SingleChildScrollView(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              return Column(
                children: [
                  Header(
                    currentRoute: '/add_expense',
                    onDashboard: () => Navigator.pushReplacementNamed(context, '/dashboard'),
                    onGroups: () => Navigator.pushReplacementNamed(context, '/groups'),
                    onAccount: () => Navigator.pushReplacementNamed(context, '/account'),
                    onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
                  ),
                  Container(
                    width: isMobile ? double.infinity : MediaQuery.of(context).size.width * 0.95,
                    constraints: isMobile ? null : const BoxConstraints(maxWidth: 1280),
                    margin: EdgeInsets.only(top: isMobile ? 8 : 20, bottom: isMobile ? 8 : 20, left: isMobile ? 10 : 0, right: isMobile ? 10 : 0),
                    padding: EdgeInsets.all(isMobile ? 0 : 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(isMobile ? 12 : 24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.07),
                          blurRadius: isMobile ? 8 : 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: AdvancedAddExpenseScreen(
                        groupId: widget.groupId,
                        participants: widget.participants,
                        currentUserId: widget.currentUserId,
                        groupCurrency: widget.groupCurrency,
                        groupName: widget.groupName,
                      ),
                    ),
                  ),
                  const AppFooter(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
