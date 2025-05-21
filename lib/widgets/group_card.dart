import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/group_model.dart';
import '../models/expense_model.dart';
import '../models/user_model.dart';
import '../utils/formatters.dart';
// import '../providers/auth_provider.dart'; // Unused import, ensure it's actually unused or restore if needed for delete logic
import '../providers/group_provider.dart';
import '../widgets/edit_group_dialog.dart'; // Necesario para showEditGroupDialog

class GroupCard extends StatefulWidget {
  final GroupModel group;
  final String currentUserId;

  const GroupCard({super.key, required this.group, required this.currentUserId});

  @override
  State<GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<GroupCard> {
  bool _hovering = false;
  late Future<Map<String, dynamic>> _futureData;

  @override
  void initState() {
    super.initState();
    _futureData = _fetchGroupDetails();
  }

  @override
  void didUpdateWidget(GroupCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.group.id != oldWidget.group.id) {
      _futureData = _fetchGroupDetails();
    }
  }

  Future<Map<String, dynamic>> _fetchGroupDetails() async {
    final participantsMap = await _fetchParticipants(widget.group.participantIds);
    ExpenseModel? lastExpense;
    if (widget.group.id.isNotEmpty) {
      try {
        final expenseSnap = await FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.group.id)
            .collection('expenses')
            .orderBy('date', descending: true)
            .limit(1)
            .get();
        if (expenseSnap.docs.isNotEmpty) {
          lastExpense = ExpenseModel.fromMap(expenseSnap.docs.first.data(), expenseSnap.docs.first.id);
        }
      } catch (e) {
        print('Error fetching last expense for group ${widget.group.id}: $e');
      }
    }
    return {'participants': participantsMap, 'lastExpense': lastExpense};
  }

  Future<Map<String, UserModel>> _fetchParticipants(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    Map<String, UserModel> participants = {};
    try {
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: userIds.isNotEmpty ? userIds : null)
          .get();
      for (var doc in usersSnap.docs) {
        participants[doc.id] = UserModel.fromMap(doc.data(), doc.id);
      }
    } catch (e) {
      print('Error fetching participants for group ${widget.group.id}: $e');
    }
    return participants;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.group.id.isEmpty) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: _futureData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 0), // Adjusted
            elevation: 2, // Adjusted
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(padding: EdgeInsets.all(24), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
          );
        }
        // Adjusted error/no data handling
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink(); 
        }
        
        final Map<String, UserModel> participants = snapshot.data!['participants'] as Map<String, UserModel>;
        final ExpenseModel? lastExpense = snapshot.data!['lastExpense'] as ExpenseModel?;
        final group = widget.group;

        // Calculate current user's balance (current logic maintained, styling from old code)
        double currentUserGroupBalance = 0;
        String currencyForDisplay = group.currency;
        final userBalanceData = group.participantBalances.firstWhere(
          (b) => b['userId'] == widget.currentUserId,
          orElse: () => <String, dynamic>{},
        );

        if (userBalanceData.isNotEmpty && userBalanceData['balances'] is Map) {
          final balancesMap = userBalanceData['balances'] as Map<String, dynamic>;
          if (balancesMap.containsKey(group.currency)) {
            currentUserGroupBalance = (balancesMap[group.currency] as num?)?.toDouble() ?? 0.0;
          } else if (balancesMap.isNotEmpty) {
            currencyForDisplay = balancesMap.keys.first;
            currentUserGroupBalance = (balancesMap[currencyForDisplay] as num?)?.toDouble() ?? 0.0;
          }
        }
        
        final balanceColor = currentUserGroupBalance < -0.01
            ? const Color(0xFFE14B4B) // Red from old code
            : (currentUserGroupBalance > 0.01 ? const Color(0xFF1BC47D) : Colors.grey[700]); // Green from old code

        return MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 0), // Adjusted
            decoration: BoxDecoration(
              color: _hovering ? const Color(0xFFF2F7FA) : Colors.white, // Adjusted
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _hovering ? const Color(0xFF179D8B) : const Color(0xFFE6E6E6), width: 1.5), // Adjusted
              boxShadow: _hovering // Adjusted
                  ? [BoxShadow(color: Colors.teal.withAlpha((0.10 * 255).round()), blurRadius: 16, offset: const Offset(0, 4))]
                  : [BoxShadow(color: Colors.black.withAlpha((0.03 * 255).round()), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.pushNamed(context, '/group/${group.id}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18), // Adjusted
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.teal[100], // Adjusted
                        backgroundImage: (group.photoUrl != null && group.photoUrl!.isNotEmpty)
                            ? NetworkImage(group.photoUrl!)
                            : null,
                        child: (group.photoUrl == null || group.photoUrl!.isEmpty)
                            ? const Icon(Icons.group, size: 32, color: Colors.white) // Adjusted
                            : null,
                      ),
                      const SizedBox(width: 18), // Adjusted
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    group.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (group.adminId == widget.currentUserId || group.roles.any((role) => role['uid'] == widget.currentUserId && role['role'] == 'admin'))
                                PopupMenuButton<String>(
                                  tooltip: 'Acciones de grupo', // Adjusted
                                  color: Colors.white, // Adjusted
                                  elevation: 8, // Adjusted
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Adjusted
                                  offset: const Offset(0, 36), // Adjusted
                                  icon: Container( // Adjusted icon
                                    padding: const EdgeInsets.all(4), // Added padding for better touch area and visual
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF179D8B).withAlpha(((_hovering ? 0.18 : 0.12) * 255).round()),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.more_vert,
                                      size: 24,
                                      color: _hovering ? const Color(0xFF179D8B) : Colors.grey[700],
                                    ),
                                  ),
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      // final participants = (snapshot.data!['participants'] as Map<String, UserModel>).values.toList(); // Already available
                                      await showEditGroupDialog(context, group, participants.values.toList());
                                    } else if (value == 'delete') {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Eliminar grupo'), // Adjusted
                                          content: const Text('¿Estás seguro de que deseas eliminar este grupo? Esta acción no se puede deshacer.'), // Adjusted
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text('Cancelar'),
                                            ),
                                            ElevatedButton.icon( // Adjusted
                                              icon: const Icon(Icons.delete_outline, color: Colors.white),
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                              onPressed: () => Navigator.pop(context, true),
                                              label: const Text('Eliminar'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true && mounted) { // mounted check added
                                        // final authProvider = Provider.of<AuthProvider>(context, listen: false); // Potentially needed if userId is not passed
                                        // final user = authProvider.user;
                                        // if (user != null) { // currentUserId is already available via widget.currentUserId
                                          try {
                                            await Provider.of<GroupProvider>(context, listen: false).deleteGroup(group.id, widget.currentUserId);
                                            if (mounted) { // Check mounted again before UI operations
                                               ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Grupo "${group.name}" eliminado.'))
                                              );
                                              // Consider if navigation is still desired or handled by provider/listener
                                              // Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                               ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Error al eliminar grupo: $e'))
                                              );
                                            }
                                          }
                                        // }
                                      }
                                    }
                                  },
                                  itemBuilder: (context) => [ // Adjusted
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: ListTile(
                                        leading: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
                                        title: const Text('Editar grupo'),
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: ListTile(
                                        leading: const Icon(Icons.delete_outline, color: Color(0xFFE14B4B)),
                                        title: const Text('Eliminar grupo', style: TextStyle(color: Color(0xFFE14B4B))),
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 2), // Adjusted
                             Text( // Balance display
                              'My balance: ${formatCurrency(currentUserGroupBalance, currencyForDisplay)}', // currencyForDisplay used
                              style: TextStyle(fontWeight: FontWeight.w600, color: balanceColor, fontSize: 16), // Adjusted
                            ),
                            if (lastExpense != null) ...[
                              const SizedBox(height: 4), // Adjusted
                              Row( // Restructured last expense
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Icon(Icons.receipt_long, size: 16, color: Colors.grey), // Adjusted
                                  const SizedBox(width: 4),
                                  Flexible(
                                    fit: FlexFit.loose,
                                    child: Text(
                                      'Last expense: "${lastExpense.description}"', // Adjusted
                                      style: const TextStyle(fontSize: 14, color: Colors.grey), // Adjusted
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('|', style: TextStyle(fontSize: 15, color: Colors.grey)),
                                      const SizedBox(width: 8),
                                      Text(
                                        formatCurrency(lastExpense.amount, lastExpense.currency),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF179D8B)), // Adjusted
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 15, color: Colors.grey), // Adjusted
                                  const SizedBox(width: 4),
                                  Text(
                                    formatDateShort(lastExpense.date),
                                    style: const TextStyle(fontSize: 13, color: Colors.grey), // Adjusted
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
