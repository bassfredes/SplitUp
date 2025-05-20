import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart'; // Asegúrate que esté si se usa directamente aquí, sino en los sub-widgets
import '../models/group_model.dart';
import '../models/user_model.dart';
import '../models/expense_model.dart';
import '../providers/group_provider.dart';
import '../providers/auth_provider.dart';
// import '../services/debt_calculator_service.dart'; // Movido a GroupBalancesCard
import '../services/export_service.dart';
import '../services/firestore_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:html' as html;
import '../config/constants.dart';
import '../widgets/breadcrumb.dart';
import '../widgets/header.dart';
import '../screens/add_expense_screen.dart';
// import '../utils/formatters.dart'; // Usado en sub-widgets
import 'package:firebase_analytics/firebase_analytics.dart';
import '../widgets/app_footer.dart';
import '../widgets/dialogs/invite_participant_dialog.dart';
// import '../widgets/dialogs/edit_group_dialog.dart'; // Movido a GroupInfoCard
import '../widgets/paginated_expense_list.dart';
import '../widgets/group_detail/group_info_card.dart'; // Nuevo widget
import '../widgets/group_detail/group_balances_card.dart'; // Nuevo widget
import 'dart:typed_data';

class GroupDetailScreen extends StatefulWidget {
  final GroupModel group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  Future<List<UserModel>>? _participantsFuture;
  bool _participantsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  void _loadParticipants() {
    setState(() {
      _participantsLoading = true; // Indicar carga al inicio
      _participantsFuture = _fetchParticipantsByIds(widget.group.participantIds).whenComplete(() {
        if (mounted) {
          setState(() {
            _participantsLoading = false;
          });
        }
      });
    });
  }

  Future<List<UserModel>> _fetchParticipantsByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    final firestoreService = FirestoreService();
    // El try-catch para el fallback ya está dentro de FirestoreService.fetchUsersByIds o debería estarlo.
    // Si no, considera mover el fallback allí para mantener este método más limpio.
    return await firestoreService.fetchUsersByIds(userIds);
  }

  Stream<List<ExpenseModel>> _getGroupExpenses(String groupId) {
    return FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  void _showExpenseDetail(BuildContext context, ExpenseModel expense, String groupName, Map<String, UserModel> usersById) async {
    if (!context.mounted) return;
    Navigator.pushNamed(
      context,
      '/group/${expense.groupId}/expense/${expense.id}',
      arguments: {
        'groupName': groupName,
        'participantsMap': usersById,
      },
    );
  }

  // _buildTotalsByCurrency ha sido movido a GroupBalancesCard

  Future<void> _importExpensesFromCsv(List<UserModel> users) async {
    final group = widget.group;
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (result != null) {
      Map<String, dynamic> importResult;
      ScaffoldMessengerState? scaffoldMessenger = mounted ? ScaffoldMessenger.of(context) : null;

      try {
        if (kIsWeb) {
          final bytes = result.files.single.bytes;
          if (bytes == null) throw Exception('Could not read the CSV file (web).');
          String content = utf8.decode(bytes);
          if (content.startsWith('\uFEFF')) content = content.substring(1); // Remover BOM
          importResult = await ExportService().importExpensesFromCsvContentWithValidation(content, users, group.id);
        } else if (result.files.single.path != null) {
          final file = File(result.files.single.path!);
          importResult = await ExportService().importExpensesFromCsvWithValidation(file, users, group.id);
        } else {
          throw Exception('Could not determine CSV file source.');
        }

        final List<ExpenseModel> importedExpenses = importResult['expenses'];
        final List<String> errors = importResult['errors'];

        if (!mounted) return;
        if (errors.isNotEmpty) {
          await showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Import Errors'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('The following errors occurred during import:'),
                      const SizedBox(height: 8),
                      ...errors.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(e, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      )),
                      const SizedBox(height: 16),
                      if (importedExpenses.isNotEmpty)
                        Text('However, ${importedExpenses.length} expenses were parsed successfully and can be imported.'),
                    ],
                  ),
                ),
              ),
              actions: [
                if (importedExpenses.isNotEmpty)
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      await _saveImportedExpenses(importedExpenses);
                    },
                    child: const Text('Import Valid Expenses'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        } else if (importedExpenses.isNotEmpty) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Confirm Import'),
              content: Text('Do you want to import ${importedExpenses.length} expenses into "${group.name}"?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Import'),
                ),
              ],
            ),
          );
          if (confirm == true) {
            await _saveImportedExpenses(importedExpenses);
          }
        } else {
          scaffoldMessenger?.showSnackBar(
            const SnackBar(content: Text('No valid expenses found in the CSV file to import.')),
          );
        }
      } catch (e) {
        scaffoldMessenger?.showSnackBar(
          SnackBar(content: Text('Error importing CSV: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _saveImportedExpenses(List<ExpenseModel> expenses) async {
    final group = widget.group;
    final batch = FirebaseFirestore.instance.batch();
    final expensesCollectionRef = FirebaseFirestore.instance.collection('groups').doc(group.id).collection('expenses');
    
    for (final expense in expenses) {
      final docRef = expensesCollectionRef.doc(); // Firestore generará un ID único
      // Asegurarse que el createdBy se establece si es necesario, o se maneja en el modelo/servicio
      batch.set(docRef, expense.copyWith(id: docRef.id, createdBy: Provider.of<AuthProvider>(context, listen: false).user?.id).toMap());
    }
    
    try {
      await batch.commit();
      await FirebaseAnalytics.instance.logEvent(
        name: 'import_expenses',
        parameters: {
          'group_id': group.id,
          'group_name': group.name,
          'count': expenses.length,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully imported ${expenses.length} expenses to "${group.name}".')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving imported expenses: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final ScrollController scrollController = ScrollController();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA), // Considerar mover a tema de la app
      floatingActionButton: _buildFloatingActionButtons(context, user),
      body: ScrollConfiguration(
        behavior: const ScrollBehavior(), // Para quitar el glow en web/desktop
        child: SingleChildScrollView(
          controller: scrollController,
          child: Column(
            children: [
              Header(
                currentRoute: '/group_detail', // Esto podría ser dinámico o gestionado por un router service
                onDashboard: () => Navigator.pushReplacementNamed(context, '/dashboard'),
                onGroups: () => Navigator.pushReplacementNamed(context, '/groups'),
                onAccount: () => Navigator.pushReplacementNamed(context, '/account'),
                onLogout: () async {
                  await authProvider.signOut();
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                },
                avatarUrl: user?.photoUrl,
                displayName: user?.name,
                email: user?.email,
              ),
              Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;
                    return Container(
                      width: isMobile ? double.infinity : MediaQuery.of(context).size.width * 0.95,
                      constraints: isMobile ? null : const BoxConstraints(maxWidth: 1280),
                      margin: EdgeInsets.symmetric(vertical: isMobile ? 8 : 20, horizontal: isMobile ? 10 : 0),
                      padding: EdgeInsets.all(isMobile ? 16 : 32), // Ajustado padding para móviles
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Breadcrumb(
                            items: [
                              BreadcrumbItem('Home', route: '/dashboard'),
                              BreadcrumbItem('Group: ${group.name}'),
                            ],
                            onTap: (i) {
                              if (i == 0) Navigator.pushReplacementNamed(context, '/dashboard');
                            },
                          ),
                          const SizedBox(height: 16),
                          GroupInfoCard(
                            group: group,
                            participantsFuture: _participantsFuture,
                            participantsLoading: _participantsLoading,
                            onEditGroupParticipantsLoaded: _loadParticipants, // Pasar el callback para recargar
                            onParticipantRemoved: _loadParticipants, // Recargar también al remover
                          ),
                          const SizedBox(height: 32),
                          FutureBuilder<List<UserModel>>(
                            future: _participantsFuture,
                            builder: (context, userSnapshot) {
                              if (userSnapshot.connectionState == ConnectionState.waiting || _participantsLoading) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (userSnapshot.hasError) {
                                return const Text('Error loading user data for expenses/balances.', style: TextStyle(color: Colors.red));
                              }
                              final users = userSnapshot.data ?? [];
                              final usersById = {for (var u in users) u.id: u};
                              final currentUserId = user?.id ?? '';

                              return StreamBuilder<List<ExpenseModel>>(
                                stream: _getGroupExpenses(group.id),
                                builder: (context, expenseSnapshot) {
                                  if (expenseSnapshot.connectionState == ConnectionState.waiting) {
                                    return const Center(child: CircularProgressIndicator());
                                  }
                                  final expenses = expenseSnapshot.data ?? [];
                                  
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Expenses:',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
                                      ),
                                      const SizedBox(height: 10),
                                      PaginatedExpenseList(
                                        expenses: expenses,
                                        usersById: usersById,
                                        currentUserId: currentUserId,
                                        groupName: widget.group.name,
                                        showExpenseDetail: _showExpenseDetail,
                                      ),
                                      const SizedBox(height: 32),
                                      GroupBalancesCard(
                                        group: group,
                                        expenses: expenses,
                                        usersById: usersById,
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 32),
                          _buildActionButtons(context, user),
                          if (user?.id == group.adminId)
                            Padding(
                              padding: const EdgeInsets.only(top: 24.0),
                              child: Center(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.delete_forever, color: Colors.white),
                                  label: const Text('Delete Group', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red[700],
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => _confirmDeleteGroup(context, group, authProvider),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const AppFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButtons(BuildContext context, UserModel? currentUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'add_expense_fab',
            backgroundColor: kPrimaryColor,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Add Expense'),
            onPressed: () async {
              final users = await _participantsFuture; // Re-evaluar si es necesario esperar aquí o pasar el future
              if (users == null || users.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Participants not loaded yet. Please wait.')),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddExpenseScreen(
                    groupId: widget.group.id,
                    participants: users,
                    currentUserId: currentUser!.id, // Asumir que currentUser no es null aquí
                    groupCurrency: widget.group.currency,
                    groupName: widget.group.name,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          FloatingActionButton.extended(
            heroTag: 'invite_participant_fab',
            onPressed: () async {
              final UserModel? invitedUser = await showInviteParticipantDialog(context);
              if (invitedUser != null) {
                if (!mounted) return;
                if (widget.group.participantIds.contains(invitedUser.id)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${invitedUser.name} is already a member of this group.')),
                  );
                  return;
                }
                setState(() => _participantsLoading = true);
                try {
                  final groupRef = FirebaseFirestore.instance.collection('groups').doc(widget.group.id);
                  final newRole = {'uid': invitedUser.id, 'role': 'member'}; // Considerar roles más granulares
                  await groupRef.update({
                    'participantIds': FieldValue.arrayUnion([invitedUser.id]),
                    'roles': FieldValue.arrayUnion([newRole])
                  });
                  await FirebaseAnalytics.instance.logEvent(
                    name: 'invite_participant',
                    parameters: {
                      'group_id': widget.group.id,
                      'group_name': widget.group.name,
                      'invited_user_id': invitedUser.id,
                    },
                  );
                  _loadParticipants(); // Recargar la lista de participantes
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${invitedUser.name} has been successfully added to the group.')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding participant: ${e.toString()}')),
                  );
                } finally {
                  if (mounted) {
                    setState(() => _participantsLoading = false);
                  }
                }
              }
            },
            label: const Text('Invite Member', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 22),
            backgroundColor: Colors.teal[50],
            foregroundColor: Colors.teal[800],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, UserModel? currentUser) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.download, size: 20),
          label: const Text('Export CSV'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey[700],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () async {
            final users = await _participantsFuture;
            if (users == null || users.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cannot export: Participant data not loaded.')),
              );
              return;
            }
            final expenses = await _getGroupExpenses(widget.group.id).first; // Obtener la lista actual de gastos
            final String fileName = "expenses_${widget.group.name.replaceAll(' ', '_')}.csv";
            final String csvDataString = ExportService().exportExpensesToCsv(expenses, users, widget.group.name);

            if (kIsWeb) {
              final blob = html.Blob([Uint8List.fromList(utf8.encode(csvDataString))], 'text/csv;charset=utf-8;');
              final url = html.Url.createObjectUrlFromBlob(blob);
              html.AnchorElement(href: url)
                ..setAttribute("download", fileName)
                ..click();
              html.Url.revokeObjectUrl(url);
            } else {
              try {
                final directory = await getApplicationDocumentsDirectory();
                final filePath = "${directory.path}/$fileName";
                final file = File(filePath);
                await file.writeAsString(csvDataString);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('CSV exported to: $filePath')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error exporting CSV: ${e.toString()}')),
                );
              }
            }
          },
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.upload_file, size: 20),
          label: const Text('Import CSV'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal[600],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () async {
            final users = await _participantsFuture;
            if (users == null || users.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cannot import: Participant data not loaded.')),
              );
              return;
            }
            await _importExpensesFromCsv(users);
          },
        ),
      ],
    );
  }

  Future<void> _confirmDeleteGroup(BuildContext context, GroupModel group, AuthProvider authProvider) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Delete Group'),
          content: Text('Are you sure you want to permanently delete the group "${group.name}"? This action cannot be undone, and all associated expenses and data will be lost.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete Permanently'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      if (!mounted) return;
      final String? currentUserId = authProvider.user?.id;
      if (currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: User not authenticated. Cannot delete group.')),
        );
        return;
      }
      try {
        await Provider.of<GroupProvider>(context, listen: false).deleteGroup(group.id, currentUserId);
        await FirebaseAnalytics.instance.logEvent(
          name: 'delete_group',
          parameters: {
            'group_id': group.id,
            'group_name': group.name,
            'user_id': currentUserId,
          },
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Group "${group.name}" has been deleted successfully.')),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/groups', (route) => false);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting group: ${e.toString()}')),
        );
      }
    }
  }
}
