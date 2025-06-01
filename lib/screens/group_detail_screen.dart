import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/group_model.dart';
import '../models/user_model.dart';
import '../models/expense_model.dart';
import '../providers/group_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/expense_provider.dart'; // Import ExpenseProvider
import '../services/export_service.dart';
import '../services/firestore_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:html' as html;
import '../config/constants.dart';
import '../widgets/breadcrumb.dart';
import '../widgets/header.dart';
import '../screens/add_expense_screen.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../widgets/app_footer.dart';
import '../widgets/dialogs/invite_participant_dialog.dart';
import '../widgets/paginated_expense_list.dart';
import '../widgets/group_detail/group_info_card.dart';
import '../widgets/group_detail/group_balances_card.dart';
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
  // ScrollController para el SingleChildScrollView principal
  final ScrollController _mainScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadParticipants();
    // Cargar la primera página de gastos para este grupo
    // Usar addPostFrameCallback para asegurar que el context esté disponible para Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<ExpenseProvider>(context, listen: false).loadExpenses(widget.group.id, forceRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _mainScrollController.dispose(); // Dispose del ScrollController principal
    super.dispose();
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

  // _getGroupExpenses ya no es necesario y se elimina completamente.

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
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false); // Obtener ExpenseProvider
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      // Usar el método addExpense del provider para cada gasto importado
      // Esto asegura que la lógica de refresco de la lista (forceRefresh: true) se ejecute.
      // Considerar un método batchAddExpenses en el provider si el rendimiento es un problema.
      for (final expense in expenses) {
        // Asegurarse que el createdBy se establece si es necesario
        // El ID será generado por Firestore dentro de addExpense si no se provee en el modelo.
        await expenseProvider.addExpense(expense.copyWith(
          createdBy: authProvider.user?.id,
          // Si ExpenseModel.id es nullable y se genera en FirestoreService.addExpense,
          // no es necesario pasarlo aquí. Si es requerido, asegurarse que se genere antes.
        ));
      }

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
        SnackBar(content: Text('Error saving imported expenses: ${e.toString()}')),);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    // El ScrollController para PaginatedExpenseList se maneja internamente en ese widget.
    // Este _mainScrollController es para el SingleChildScrollView de toda la pantalla.

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      floatingActionButton: _buildFloatingActionButtons(context, user),
      body: ScrollConfiguration(
        behavior: const ScrollBehavior(),
        child: SingleChildScrollView(
          controller: _mainScrollController, // Usar el ScrollController principal aquí
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
                            color: Colors.black.withAlpha((0.07 * 255).round()),
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
                              
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Expenses:',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
                                  ),
                                  const SizedBox(height: 10),
                                  // Ya no se usa StreamBuilder aquí para los gastos.
                                  // PaginatedExpenseList consumirá del ExpenseProvider.
                                  PaginatedExpenseList(
                                    groupId: group.id, // Pasar el groupId
                                    usersById: usersById,
                                    currentUserId: currentUserId,
                                    groupName: widget.group.name,
                                    showExpenseDetail: _showExpenseDetail,
                                  ),
                                  const SizedBox(height: 32),
                                  GroupBalancesCard(
                                    group: group,
                                    usersById: usersById,
                                  ),
                                ],
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

                setState(() => _participantsLoading = true);
                try {
                  final groupProvider = Provider.of<GroupProvider>(context, listen: false);
                  final updatedGroup = await groupProvider.addParticipantToGroup(widget.group.id, invitedUser);

                  // La lógica para manejar participantes duplicados ahora reside en la capa de servicio/proveedor.
                  // El servicio previene la adición de duplicados y devuelve el grupo sin cambios
                  // si el participante ya es miembro. La UI simplemente refleja el estado del grupo devuelto.
                  // Si se requiere un mensaje específico para "ya es miembro", el servicio debería proporcionarlo.

                  await FirebaseAnalytics.instance.logEvent(
                    name: 'invite_participant',
                    parameters: {
                      'group_id': widget.group.id,
                      'group_name': widget.group.name, // Considerar usar updatedGroup.name si puede cambiar
                      'invited_user_id': invitedUser.id,
                    },
                  );
                  
                  // Actualizar el estado local con el grupo modificado y recargar participantes
                  // Esto es crucial si `widget.group` no se actualiza automáticamente.
                  // Sin embargo, `_loadParticipants` usa `widget.group.participantIds`.
                  // Si `addParticipantToGroup` en el provider actualiza su lista interna `_groups`
                  // y `GroupDetailScreen` escucha esos cambios (o el `widget.group` se actualiza
                  // a través de un stream superior), entonces `_loadParticipants()` podría ser suficiente
                  // si se llama DESPUÉS de que `widget.group` se haya actualizado.

                  // Opción 1: Confiar en que el GroupProvider y el stream actualicen widget.group
                  // y luego _loadParticipants use los IDs actualizados.
                  // _loadParticipants(); // Ya está aquí.

                  // Opción 2: Forzar la actualización de la UI de participantes usando el `updatedGroup` directamente.
                  // Esto es más directo si `widget.group` no se actualiza inmediatamente.
                  // Primero, actualiza el `_participantsFuture` con los nuevos IDs del `updatedGroup`.
                  setState(() {
                    // Actualiza el widget.group localmente si es necesario y si este GroupDetailScreen
                    // no se reconstruye automáticamente cuando el GroupProvider notifica cambios.
                    // Si GroupDetailScreen SÍ se reconstruye, esta línea podría ser redundante o causar doble estado.
                    // widget.group = updatedGroup; // Esto no es posible porque widget.group es final.

                    // En lugar de modificar widget.group, actualizamos el _participantsFuture
                    // basándonos en los participantIds del updatedGroup.
                    _participantsFuture = _fetchParticipantsByIds(updatedGroup.participantIds).whenComplete(() {
                      if (mounted) {
                        setState(() {
                          _participantsLoading = false;
                        });
                      }
                    });
                  });
                  // Luego, si _loadParticipants() hace más que solo setear _participantsFuture (ej. cambiar _participantsLoading),
                  // podría ser necesario llamarlo o replicar su lógica relevante aquí.
                  // Por ahora, la actualización directa de _participantsFuture y _participantsLoading debería ser suficiente.


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
            // Obtener gastos del ExpenseProvider en lugar de _getGroupExpenses
            final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
            // Asegurarse que los gastos son para el grupo actual
            // Si el groupId del provider no coincide, podría ser un estado intermedio.
            // Idealmente, loadExpenses ya se llamó y los gastos están disponibles.
            if (expenseProvider.currentGroupId != widget.group.id) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Expense data is not ready for this group yet. Please wait a moment and try again.')),
                );
                return;
            }
            final expenses = expenseProvider.expenses; 
            final String fileName = "expenses_${widget.group.name.replaceAll(' ', '_')}.csv";
            // ... rest of the export logic ...
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
