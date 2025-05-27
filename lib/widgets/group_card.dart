import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/group_model.dart';
import '../models/expense_model.dart';
import '../models/user_model.dart';
import '../utils/formatters.dart';
import '../providers/group_provider.dart';
import '../widgets/dialogs/edit_group_dialog.dart';

class GroupCard extends StatefulWidget {
  final GroupModel group;
  final String currentUserId;

  const GroupCard({super.key, required this.group, required this.currentUserId});

  @override
  State<GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<GroupCard> {
  bool _hovering = false;
  bool _iconHovering = false; // Nueva variable de estado para el hover del icono
  late Future<Map<String, UserModel>> _participantsFuture;

  @override
  void initState() {
    super.initState();
    _participantsFuture = _fetchParticipants(widget.group.participantIds);
  }

  @override
  void didUpdateWidget(GroupCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.group.id != oldWidget.group.id || widget.group.participantIds.length != oldWidget.group.participantIds.length) {
      _participantsFuture = _fetchParticipants(widget.group.participantIds);
    }
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

  void _handleGroupUpdated() {
    if (mounted) {
      setState(() {
        _participantsFuture = _fetchParticipants(widget.group.participantIds);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.group.id.isEmpty) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<Map<String, UserModel>>(
      future: _participantsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(padding: EdgeInsets.all(24), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink(); 
        }
        
        final Map<String, UserModel> participants = snapshot.data!;
        final group = widget.group;
        final ExpenseModel? lastExpense = group.lastExpense != null 
            ? ExpenseModel.fromMap(group.lastExpense!, group.lastExpense!['id'] ?? '') 
            : null;

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
            ? const Color(0xFFE14B4B)
            : (currentUserGroupBalance > 0.01 ? const Color(0xFF1BC47D) : Colors.grey[700]);

        return MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
            decoration: BoxDecoration(
              color: _hovering ? const Color(0xFFF2F7FA) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _hovering ? const Color(0xFF179D8B) : const Color(0xFFE6E6E6), width: 1.5),
              boxShadow: _hovering
                  ? [BoxShadow(color: Colors.teal.withAlpha((0.10 * 255).round()), blurRadius: 16, offset: const Offset(0, 4))]
                  : [BoxShadow(color: Colors.black.withAlpha((0.03 * 255).round()), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.pushNamed(context, '/group/${group.id}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                  child: Stack(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.teal[100],
                            backgroundImage: (group.photoUrl != null && group.photoUrl!.isNotEmpty)
                                ? NetworkImage(group.photoUrl!)
                                : null,
                            child: (group.photoUrl == null || group.photoUrl!.isEmpty)
                                ? const Icon(Icons.group, size: 32, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  group.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'My balance: ${formatCurrency(currentUserGroupBalance, currencyForDisplay)}',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: balanceColor, fontSize: 16),
                                ),
                                if (lastExpense != null) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.receipt_long, size: 16, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        fit: FlexFit.loose,
                                        child: Text(
                                          'Last: "${lastExpense.description}" - ${formatCurrency(lastExpense.amount, lastExpense.currency)}',
                                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 15, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        formatDateShort(lastExpense.date),
                                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: TextButton(
                                    onPressed: () => Navigator.pushNamed(context, '/group/${group.id}'),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(50, 30),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      alignment: Alignment.centerRight,
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('View details', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w600)),
                                        SizedBox(width: 4),
                                        Icon(Icons.arrow_forward_ios, size: 14, color: Colors.teal),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (group.adminId == widget.currentUserId || group.roles.any((role) => role['uid'] == widget.currentUserId && role['role'] == 'admin'))
                      Positioned(
                        top: -8,
                        right: -8,
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            // splashColor: Colors.transparent, // Se mantiene para el botón
                            // hoverColor: Colors.transparent, // Se mantiene para el botón
                            // highlightColor: Colors.transparent, // Se mantiene para el botón
                            // Aplicar hoverColor a los items del PopupMenuButton
                            popupMenuTheme: PopupMenuThemeData(
                              color: Colors.white, // Color de fondo del menú
                              elevation: 8,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              textStyle: TextStyle(color: Colors.grey[800]), // Estilo de texto por defecto
                              // Definir aquí el hoverColor para los items
                              // Esto requiere una personalización más profunda o usar un paquete
                              // Por ahora, el hover por defecto de Material se aplicará si no se anula globalmente
                            ),
                          ),
                          child: PopupMenuButton<String>(
                            tooltip: 'Group actions',
                            // color: Colors.white, // Se define en popupMenuTheme
                            // elevation: 8, // Se define en popupMenuTheme
                            // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Se define en popupMenuTheme
                            offset: const Offset(0, 40),
                            icon: MouseRegion( // MouseRegion específico para el icono
                              onEnter: (_) => setState(() => _iconHovering = true),
                              onExit: (_) => setState(() => _iconHovering = false),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _iconHovering ? Colors.teal.withOpacity(0.1) : Colors.white.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: _iconHovering ? [] : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0,2)
                                    )
                                  ]
                                ),
                                child: Icon(
                                  Icons.more_vert,
                                  size: 22,
                                  color: _iconHovering ? Colors.teal : Colors.grey[800],
                                ),
                              ),
                            ),
                            onSelected: (value) async {
                              if (value == 'edit') {
                                showEditGroupDialog(
                                  context,
                                  group,
                                  participants.values.toList(),
                                  _handleGroupUpdated,
                                );
                              } else if (value == 'delete') {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete group'),
                                    content: const Text('Are you sure you want to delete this group? This action cannot be undone.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.delete_outline, color: Colors.white),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                        onPressed: () => Navigator.pop(context, true),
                                        label: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true && mounted) {
                                  try {
                                    await Provider.of<GroupProvider>(context, listen: false).deleteGroup(group.id, widget.currentUserId);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Group "${group.name}" deleted.'))
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error deleting group: $e'))
                                      );
                                    }
                                  }
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  leading: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
                                  title: const Text('Edit group'),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  // Aplicar hoverColor directamente si es posible, o usar MouseRegion
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  leading: const Icon(Icons.delete_outline, color: Color(0xFFE14B4B)),
                                  title: const Text('Delete group', style: TextStyle(color: Color(0xFFE14B4B))),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
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
