import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense_model.dart';
import '../models/user_model.dart';
import '../widgets/breadcrumb.dart';
import '../widgets/header.dart';

class ExpenseDetailScreen extends StatefulWidget {
  final String groupId;
  final String expenseId;
  const ExpenseDetailScreen({super.key, required this.groupId, required this.expenseId});

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  ExpenseModel? expense;
  List<UserModel> participants = [];
  bool loading = true;
  String? error;
  String? groupName;

  @override
  void initState() {
    super.initState();
    _loadExpenseAndGroupName();
  }

  Future<void> _loadExpenseAndGroupName() async {
    try {
      final groupDoc = await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).get();
      groupName = groupDoc.exists ? groupDoc.data()!["name"] as String? : null;
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

  String _getUserName(String id) {
    final user = participants.firstWhere(
      (u) => u.id == id,
      orElse: () => UserModel(id: id, name: '', email: '', photoUrl: null),
    );
    return user.name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Header(
        currentRoute: '/expense_detail',
        onDashboard: () => Navigator.pushReplacementNamed(context, '/dashboard'),
        onGroups: () => Navigator.pushReplacementNamed(context, '/groups'),
        onAccount: () => Navigator.pushReplacementNamed(context, '/account'),
        onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
      ),
      body: Container(
        width: double.infinity,
        color: const Color(0xFFF6F8FA),
        child: Center(
          child: loading
              ? const CircularProgressIndicator()
              : error != null
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 18)),
                    )
                  : expense == null
                      ? const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('No se encontró el gasto.'),
                        )
                      : SingleChildScrollView(
                          child: Center(
                            child: Container(
                              width: MediaQuery.of(context).size.width * 0.95,
                              constraints: const BoxConstraints(maxWidth: 1200),
                              margin: const EdgeInsets.only(top: 20, bottom: 20),
                              padding: const EdgeInsets.all(40),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.07),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Breadcrumb(
                                    items: [
                                      BreadcrumbItem('Inicio', route: '/dashboard'),
                                      BreadcrumbItem(groupName != null ? 'Grupo: $groupName' : 'Grupo', route: '/group/${widget.groupId}'),
                                      BreadcrumbItem(expense != null ? expense!.description : 'Gasto'),
                                    ],
                                    onTap: (i) {
                                      if (i == 0) Navigator.pushReplacementNamed(context, '/dashboard');
                                      if (i == 1) Navigator.pushReplacementNamed(context, '/group/${widget.groupId}');
                                    },
                                  ),
                                  const SizedBox(height: 32),
                                  Text(
                                    expense!.description,
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      const Text('Monto: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                      Text('${expense!.amount.toStringAsFixed(2)} ${expense!.currency}'),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Text('Fecha: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                      Text('${expense!.date.toLocal()}'.split(' ')[0]),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Text('Categoría: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                      Text(expense!.category ?? '-'),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('Participantes:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ...expense!.participantIds.map((id) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: Text(_getUserName(id)),
                                      )),
                                  const SizedBox(height: 16),
                                  const Text('Pagadores:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ...expense!.payers.map((p) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: Text('${_getUserName(p['userId'])}: ${p['amount'].toStringAsFixed(2)} ${expense!.currency}'),
                                      )),
                                  const SizedBox(height: 16),
                                  if (expense!.attachments != null && expense!.attachments!.isNotEmpty)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Adjuntos:', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ...expense!.attachments!.map((a) => Text(a)),
                                        const SizedBox(height: 16),
                                      ],
                                    ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.edit),
                                        label: const Text('Editar'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () {
                                          Navigator.pushNamed(
                                            context,
                                            '/group/${widget.groupId}/expense/${widget.expenseId}/edit',
                                            arguments: {
                                              'expense': expense,
                                              'participants': participants,
                                              'groupId': widget.groupId,
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
        ),
      ),
    );
  }
}
