import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense_model.dart';
import '../models/user_model.dart';
import '../widgets/breadcrumb.dart';
import '../widgets/header.dart';
import '../utils/formatters.dart';

class ExpenseDetailScreen extends StatefulWidget {
  final String groupId;
  final String expenseId;
  const ExpenseDetailScreen({super.key, required this.groupId, required this.expenseId});

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  ExpenseModel? expense;
  // Optimization: Receive map of participants instead of list
  Map<String, UserModel> participantsMap = {};
  bool loading = true;
  String? error;
  // Optimization: Receive group name
  String? groupName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read arguments here because they depend on the context
    final arguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (arguments != null) {
      groupName = arguments['groupName'] as String?;
      participantsMap = arguments['participantsMap'] as Map<String, UserModel>? ?? {};
    }
    // Load only the expense if it hasn't been done already
    if (loading && expense == null) {
       _loadExpense();
    }
  }

  // Optimization: Rename and simplify the function
  Future<void> _loadExpense() async {
    // Ensure not to reload if already loading or loaded
    if (!loading && expense != null) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      // No need to fetch the group anymore
      // final groupDoc = await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).get();
      // groupName = groupDoc.exists ? groupDoc.data()!["name"] as String? : null;

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

      // No need to fetch participants, use the passed map
      // final usersSnap = await FirebaseFirestore.instance
      //     .collection('users')
      //     .where(FieldPath.documentId, whereIn: exp.participantIds)
      //     .get();
      // participants = usersSnap.docs.map((d) => UserModel.fromMap(d.data(), d.id)).toList();

      // Validate that the expense participants are in the passed map (they should be)
      final missingParticipants = exp.participantIds.where((id) => !participantsMap.containsKey(id)).toList();
      if (missingParticipants.isNotEmpty) {
        debugPrint("[WARN] ExpenseDetailScreen: Missing participants in the passed map: $missingParticipants");
        // Optional: You could try to load them here as a fallback, but ideally this shouldn't happen.
      }

      setState(() {
        expense = exp;
        loading = false;
      });
    } catch (e, stacktrace) {
      debugPrint("Error loading expense: $e\n$stacktrace");
      setState(() {
        error = 'Error loading expense';
        loading = false;
      });
    }
  }

  // Optimization: Use the participants map
  String _getUserName(String id) {
    return participantsMap[id]?.name ?? 'Unknown user';
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
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 18)),
                  )
                : expense == null
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Expense not found.'),
                      )
                    : Center(
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
                                color: const Color.fromRGBO(0, 0, 0, 0.07),
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
                                  BreadcrumbItem('Home', route: '/dashboard'),
                                  // Use the received groupName
                                  BreadcrumbItem(groupName != null ? 'Group: $groupName' : 'Group', route: '/group/${widget.groupId}'),
                                  BreadcrumbItem(expense != null ? expense!.description : 'Expense'),
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
                                  const Text('Amount: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  // Use the formatCurrency function
                                  Text(formatCurrency(expense!.amount, expense!.currency)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text('Date: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text('${expense!.date.toLocal()}'.split(' ')[0]),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text('Category: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text(expense!.category ?? '-'),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Text('Participants:', style: TextStyle(fontWeight: FontWeight.bold)),
                              // Use _getUserName which now uses the map
                              ...expense!.participantIds.map((id) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Text(_getUserName(id)),
                                  )),
                              const SizedBox(height: 16),
                              const Text('Payers:', style: TextStyle(fontWeight: FontWeight.bold)),
                              // Use _getUserName which now uses the map
                              ...expense!.payers.map((p) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Text('${_getUserName(p['userId'])}: ${formatCurrency((p['amount'] as num).toDouble(), expense!.currency)}'),
                                  )),
                              const SizedBox(height: 16),
                              if (expense!.attachments != null && expense!.attachments!.isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Attachments:', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ...expense!.attachments!.map((a) => Text(a)),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Edit'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      // Ensure to pass the participants map to the edit screen
                                      Navigator.pushNamed(
                                        context,
                                        '/group/${widget.groupId}/expense/${widget.expenseId}/edit',
                                        arguments: {
                                          'expense': expense,
                                          'participantsMap': participantsMap, // Pass the map
                                          'groupId': widget.groupId,
                                          'groupName': groupName, // Also pass the group name
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
    );
  }
}
