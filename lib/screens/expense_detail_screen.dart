import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense_model.dart';
import '../models/user_model.dart';
import '../widgets/breadcrumb.dart';
import '../widgets/header.dart';
import '../utils/formatters.dart';
import '../widgets/app_footer.dart';

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

  // Helper widget to build detail rows consistently
  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    String? value,
    Widget? child,
    required bool isMobile,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: isMobile ? 20 : 24, color: Colors.black54),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: isMobile ? 15 : 17, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                if (value != null)
                  Text(value, style: TextStyle(fontSize: isMobile ? 14 : 16, color: Colors.black54))
                else if (child != null)
                  child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteExpense() async {
    if (expense == null) return;

    // Show a loading indicator while deleting
    // You might want to add a more sophisticated loading state management
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deleting expense...')),
    );

    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('expenses')
          .doc(widget.expenseId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted successfully'), backgroundColor: Colors.green),
        );
        // Navigate back to the group screen or dashboard
        // Consider if there's a more specific place to go, e.g., previous screen if it makes sense
        Navigator.pushReplacementNamed(context, '/group/${widget.groupId}');
      }
    } catch (e) {
      debugPrint("Error deleting expense: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting expense: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _confirmDeleteExpense(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this expense? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(ctx).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(ctx).pop(); // Close the dialog
                _deleteExpense(); // Proceed with deletion
              },
            ),
          ],
        );
      },
    );
  }

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
                    currentRoute: '/expense_detail',
                    onDashboard: () => Navigator.pushReplacementNamed(context, '/dashboard'),
                    onGroups: () => Navigator.pushReplacementNamed(context, '/groups'),
                    onAccount: () => Navigator.pushReplacementNamed(context, '/account'),
                    onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
                  ),
                  Container(
                    width: isMobile ? double.infinity : MediaQuery.of(context).size.width * 0.95,
                    constraints: isMobile ? null : const BoxConstraints(maxWidth: 1280),
                    margin: EdgeInsets.only(top: isMobile ? 8 : 20, bottom: isMobile ? 8 : 20, left: isMobile ? 10 : 0, right: isMobile ? 10 : 0),
                    padding: EdgeInsets.all(isMobile ? 16 : 32), // Adjusted padding for mobile
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(isMobile ? 12 : 24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((0.07 * 255).round()),
                          blurRadius: isMobile ? 8 : 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 0 : 18), // No extra padding for mobile here, handled by container
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : error != null
                              ? Padding(
                                  padding: EdgeInsets.all(isMobile ? 8 : 18),
                                  child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 18)),
                                )
                              : expense == null
                                  ? Padding(
                                      padding: EdgeInsets.all(isMobile ? 8 : 18),
                                      child: const Text('Expense not found.', style: TextStyle(fontSize: 18)), // Added style
                                    )
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Breadcrumb(
                                          items: [
                                            BreadcrumbItem('Home', route: '/dashboard'),
                                            BreadcrumbItem(groupName != null ? 'Group: $groupName' : 'Group', route: '/group/${widget.groupId}'),
                                            BreadcrumbItem(expense!.description.isNotEmpty ? expense!.description : 'Expense'), // Handle empty description
                                          ],
                                          onTap: (i) {
                                            if (i == 0) Navigator.pushReplacementNamed(context, '/dashboard');
                                            if (i == 1) Navigator.pushReplacementNamed(context, '/group/${widget.groupId}');
                                          },
                                        ),
                                        const SizedBox(height: 24),
                                        Text(
                                          expense!.description.isNotEmpty ? expense!.description : 'Expense Details', // Handle empty description
                                          style: TextStyle(fontSize: isMobile ? 22 : 28, fontWeight: FontWeight.bold, color: Colors.black87),
                                        ),
                                        const SizedBox(height: 24),

                                        _buildDetailRow(
                                          icon: Icons.euro_symbol, // Or other currency icon based on expense!.currency
                                          label: 'Amount',
                                          value: formatCurrency(expense!.amount, expense!.currency),
                                          isMobile: isMobile,
                                        ),
                                        _buildDetailRow(
                                          icon: Icons.calendar_today_outlined,
                                          label: 'Date',
                                          value: '${expense!.date.toLocal()}'.split(' ')[0],
                                          isMobile: isMobile,
                                        ),
                                        _buildDetailRow(
                                          icon: Icons.category_outlined,
                                          label: 'Category',
                                          value: expense!.category ?? '-',
                                          isMobile: isMobile,
                                        ),
                                        _buildDetailRow(
                                          icon: Icons.people_outline,
                                          label: 'Participants',
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: expense!.participantIds.map((id) => Padding(
                                              padding: const EdgeInsets.only(top: 4.0),
                                              child: Text(_getUserName(id), style: TextStyle(fontSize: isMobile ? 14 : 16, color: Colors.black54)),
                                            )).toList(),
                                          ),
                                          isMobile: isMobile,
                                        ),
                                        _buildDetailRow(
                                          icon: Icons.account_balance_wallet_outlined,
                                          label: 'Payer',
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: expense!.payers.map((p) => Padding(
                                              padding: const EdgeInsets.only(top: 4.0),
                                              child: Text('${_getUserName(p['userId'])}: ${formatCurrency((p['amount'] as num).toDouble(), expense!.currency)}', style: TextStyle(fontSize: isMobile ? 14 : 16, color: Colors.black54)),
                                            )).toList(),
                                          ),
                                          isMobile: isMobile,
                                        ),
                                        // The OCR image shows "Notes". The closest field in ExpenseModel is description.
                                        // If description is meant to be the main title, and there should be a separate notes field,
                                        // then the ExpenseModel needs to be updated.
                                        // For now, we are not displaying a separate "Notes" field as it doesn't exist in the model.
                                        // The main description is already shown above.

                                        if (expense!.attachments != null && expense!.attachments!.isNotEmpty)
                                          _buildDetailRow(
                                            icon: Icons.attachment_outlined,
                                            label: 'Attachments',
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: expense!.attachments!.map((a) => Padding(
                                                padding: const EdgeInsets.only(top: 4.0),
                                                child: Text(a, style: TextStyle(fontSize: isMobile ? 14 : 16, color: Colors.blueAccent, decoration: TextDecoration.underline)), // Style as link
                                              )).toList(),
                                            ),
                                            isMobile: isMobile,
                                          ),
                                        
                                        const SizedBox(height: 32),

                                        Row(
                                          mainAxisAlignment: isMobile ? MainAxisAlignment.spaceEvenly : MainAxisAlignment.end,
                                          children: [
                                            ElevatedButton.icon(
                                              icon: const Icon(Icons.edit_outlined),
                                              label: const Text('Edit'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.teal,
                                                foregroundColor: Colors.white,
                                                padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 24, vertical: isMobile ? 14 : 16), // Increased padding
                                                textStyle: TextStyle(fontSize: isMobile ? 15 : 16, fontWeight: FontWeight.bold), // Bold text
                                              ),
                                              onPressed: () {
                                                Navigator.pushNamed(
                                                  context,
                                                  '/group/${widget.groupId}/expense/${widget.expenseId}/edit',
                                                  arguments: {
                                                    'expense': expense,
                                                    'participantsMap': participantsMap,
                                                    'groupName': groupName,
                                                  },
                                                );
                                              },
                                            ),
                                            if (!isMobile) const SizedBox(width: 16),
                                            ElevatedButton.icon(
                                              icon: const Icon(Icons.delete_outline),
                                              label: const Text('Delete'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.redAccent,
                                                foregroundColor: Colors.white,
                                                padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 24, vertical: isMobile ? 14 : 16), // Increased padding
                                                textStyle: TextStyle(fontSize: isMobile ? 15 : 16, fontWeight: FontWeight.bold), // Bold text
                                              ),
                                              onPressed: () => _confirmDeleteExpense(context),
                                            ),
                                          ],
                                        ),
                                      ],
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
