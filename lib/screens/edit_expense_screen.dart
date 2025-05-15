import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense_model.dart';
import '../models/user_model.dart';
import '../models/group_model.dart';
import '../widgets/advanced_add_expense_screen.dart';
import '../widgets/header.dart';
import '../widgets/app_footer.dart';

class EditExpenseScreen extends StatefulWidget {
  final String groupId;
  final String expenseId;
  const EditExpenseScreen({super.key, required this.groupId, required this.expenseId});

  @override
  State<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  ExpenseModel? expense;
  List<UserModel> participants = [];
  bool loading = true;
  String? error;
  GroupModel? group;

  @override
  void initState() {
    super.initState();
    _loadExpenseAndGroup();
  }

  Future<void> _loadExpenseAndGroup() async {
    try {
      final groupDoc = await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).get();
      if (!groupDoc.exists) {
        setState(() {
          error = 'Group not found';
          loading = false;
        });
        return;
      }
      group = GroupModel.fromMap(groupDoc.data()!, groupDoc.id);
      final doc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('expenses')
          .doc(widget.expenseId)
          .get();
      if (!doc.exists) {
        setState(() {
          error = 'Expense not found';
          loading = false;
        });
        return;
      }
      final exp = ExpenseModel.fromMap(doc.data()!, doc.id);
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: exp.participantIds)
          .get();
      setState(() {
        expense = exp;
        participants = usersSnap.docs.map((d) => UserModel.fromMap(d.data(), d.id)).toList();
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Error loading expense or group';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F8FA),
        body: SingleChildScrollView(
          child: Center(
            child: Column(
              children: [
                Header(
                  currentRoute: '/expense_edit',
                  onDashboard: () => Navigator.pushReplacementNamed(context, '/dashboard'),
                  onGroups: () => Navigator.pushReplacementNamed(context, '/groups'),
                  onAccount: () => Navigator.pushReplacementNamed(context, '/account'),
                  onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
                ),
                const SizedBox(height: 40),
                const CircularProgressIndicator(),
                const AppFooter(),
              ],
            ),
          ),
        ),
      );
    }
    if (error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F8FA),
        body: SingleChildScrollView(
          child: Center(
            child: Column(
              children: [
                Header(
                  currentRoute: '/expense_edit',
                  onDashboard: () => Navigator.pushReplacementNamed(context, '/dashboard'),
                  onGroups: () => Navigator.pushReplacementNamed(context, '/groups'),
                  onAccount: () => Navigator.pushReplacementNamed(context, '/account'),
                  onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
                ),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                const AppFooter(),
              ],
            ),
          ),
        ),
      );
    }
    final currentUserId = participants.isNotEmpty ? participants.first.id : '';
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              Header(
                currentRoute: '/expense_edit',
                onDashboard: () => Navigator.pushReplacementNamed(context, '/dashboard'),
                onGroups: () => Navigator.pushReplacementNamed(context, '/groups'),
                onAccount: () => Navigator.pushReplacementNamed(context, '/account'),
                onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
              ),
              Container(
                width: MediaQuery.of(context).size.width < 600 ? double.infinity : MediaQuery.of(context).size.width * 0.95,
                constraints: MediaQuery.of(context).size.width < 600 ? null : const BoxConstraints(maxWidth: 1280),
                margin: EdgeInsets.only(
                  top: MediaQuery.of(context).size.width < 600 ? 8 : 20,
                  bottom: MediaQuery.of(context).size.width < 600 ? 8 : 20,
                  left: MediaQuery.of(context).size.width < 600 ? 10 : 0,
                  right: MediaQuery.of(context).size.width < 600 ? 10 : 0,
                ),
                padding: EdgeInsets.all(MediaQuery.of(context).size.width < 600 ? 0 : 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width < 600 ? 12 : 24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: MediaQuery.of(context).size.width < 600 ? 8 : 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: AdvancedAddExpenseScreen(
                  groupId: widget.groupId,
                  participants: participants,
                  currentUserId: currentUserId,
                  groupCurrency: expense?.currency ?? 'CLP',
                  expenseToEdit: expense,
                  groupName: group?.name,
                ),
              ),
              const AppFooter(),
            ],
          ),
        ),
      ),
    );
  }
}
