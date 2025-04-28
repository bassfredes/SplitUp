import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense_model.dart';
import '../models/user_model.dart';
import '../models/group_model.dart';
import '../widgets/advanced_add_expense_screen.dart';
import '../widgets/header.dart';
import '../widgets/breadcrumb.dart';

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
          error = 'Grupo no encontrado';
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
          error = 'Gasto no encontrado';
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
        error = 'Error al cargar el gasto o grupo';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (error != null) {
      return Scaffold(body: Center(child: Text(error!, style: const TextStyle(color: Colors.red))));
    }
    final currentUserId = participants.isNotEmpty ? participants.first.id : '';
    return Scaffold(
      appBar: Header(
        currentRoute: '/expense_edit',
        onDashboard: () => Navigator.pushReplacementNamed(context, '/dashboard'),
        onGroups: () => Navigator.pushReplacementNamed(context, '/groups'),
        onAccount: () => Navigator.pushReplacementNamed(context, '/account'),
        onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
      ),
      backgroundColor: const Color(0xFFF6F8FA),
      body: SingleChildScrollView(
        child: Center(
          child: AdvancedAddExpenseScreen(
            groupId: widget.groupId,
            participants: participants,
            currentUserId: currentUserId,
            groupCurrency: expense?.currency ?? 'CLP',
            expenseToEdit: expense,
            groupName: group?.name,
          ),
        ),
      ),
    );
  }
}
