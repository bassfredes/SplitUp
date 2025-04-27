import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/group_model.dart';
import '../models/user_model.dart';
import '../models/expense_model.dart';
import '../providers/group_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/advanced_add_expense_screen.dart';

class GroupDetailScreen extends StatelessWidget {
  final GroupModel group;
  const GroupDetailScreen({Key? key, required this.group}) : super(key: key);

  Future<List<UserModel>> _fetchParticipantsByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    final usersSnap = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: userIds)
        .get();
    // Ordenar los usuarios según el orden de userIds
    final users = usersSnap.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList();
    users.sort((a, b) => userIds.indexOf(a.id).compareTo(userIds.indexOf(b.id)));
    return users;
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

  void _showExpenseDetail(BuildContext context, ExpenseModel expense) async {
    // Obtener participantes del gasto
    final usersSnap = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: expense.participantIds)
        .get();
    final users = usersSnap.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Detalle del gasto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Descripción: ${expense.description}'),
            Text('Monto: ${expense.amount.toStringAsFixed(2)}'),
            Text('Fecha: ${expense.date.toLocal().toString().split(' ')[0]}'),
            const SizedBox(height: 8),
            const Text('Participantes:', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: users.map((u) => Chip(label: Text(u.name))).toList(),
            ),
            const SizedBox(height: 8),
            Text('Pagador: ${expense.payers.map((p) => p['userId']).join(', ')}'),
            if (expense.isLocked)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Gasto bloqueado', style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          if (!expense.isLocked)
            TextButton(
              onPressed: () async {
                // Eliminar gasto
                await FirebaseFirestore.instance
                    .collection('groups')
                    .doc(expense.groupId)
                    .collection('expenses')
                    .doc(expense.id)
                    .delete();
                Navigator.pop(context);
              },
              child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        backgroundColor: const Color(0xFF159d9e),
        leading: Navigator.canPop(context)
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Volver',
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/dashboard');
                },
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await Provider.of<AuthProvider>(context, listen: false).signOut();
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF6F8FA),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          padding: const EdgeInsets.all(32),
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
              Text(
                group.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (group.description != null && group.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(group.description!, style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: 24),
              const Text('Participantes:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              FutureBuilder<List<UserModel>>(
                future: _fetchParticipantsByIds(group.participantIds),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final users = snapshot.data ?? [];
                  if (users.isEmpty) {
                    return const Text('Sin participantes');
                  }
                  return Wrap(
                    spacing: 8,
                    children: users.map((user) => Chip(
                      avatar: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                          ? CircleAvatar(backgroundImage: NetworkImage(user.photoUrl!))
                          : CircleAvatar(child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?')),
                      label: Text(user.name),
                      onDeleted: () async {
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        final isAdmin = group.adminId == authProvider.user?.id;
                        if (isAdmin && user.id != group.adminId) {
                          // Eliminar participante del grupo y redistribuir gastos
                          await Provider.of<GroupProvider>(context, listen: false)
                              .removeParticipantAndRedistribute(group.id, user.id);
                          await FirebaseFirestore.instance.collection('groups').doc(group.id).update({
                            'participantIds': FieldValue.arrayRemove([user.id]),
                            'roles': group.roles.where((r) => r['uid'] != user.id).toList(),
                          });
                          // Refrescar pantalla
                          Navigator.of(context).pushReplacementNamed('/group_detail', arguments: group);
                        }
                      },
                    )).toList(),
                  );
                },
              ),
              const SizedBox(height: 32),
              const Text('Gastos del grupo:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              StreamBuilder<List<ExpenseModel>>(
                stream: _getGroupExpenses(group.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final expenses = snapshot.data ?? [];
                  if (expenses.isEmpty) {
                    return const Text('No hay gastos registrados.');
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      final e = expenses[index];
                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long, color: Color(0xFF159d9e)),
                          title: Text(e.description),
                          subtitle: Text('Monto: \$${e.amount.toStringAsFixed(2)} | Fecha: ${e.date.toLocal().toString().split(' ')[0]}'),
                          trailing: e.isLocked ? const Icon(Icons.lock, color: Colors.red) : null,
                          onTap: () => _showExpenseDetail(context, e),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('Invitar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF159d9e),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final result = await showDialog(
                        context: context,
                        builder: (context) => _InviteParticipantDialog(groupId: group.id),
                      );
                      if (result == true) {
                        final userId = Provider.of<AuthProvider>(context, listen: false).user?.id;
                        if (userId != null) {
                          await Provider.of<GroupProvider>(context, listen: false).loadUserGroups(userId);
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar gasto'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF159d9e),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final users = await _fetchParticipantsByIds(group.participantIds);
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdvancedAddExpenseScreen(
                            groupId: group.id,
                            participants: users,
                            currentUserId: Provider.of<AuthProvider>(context, listen: false).user!.id,
                            groupCurrency: group.currency,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Builder(
                builder: (context) {
                  final authProvider = Provider.of<AuthProvider>(context);
                  final user = authProvider.user;
                  final loading = authProvider.loading;
                  final isAdmin = user != null && group.adminId == user.id;
                  final isOnlyParticipant = user != null && group.participantIds.length == 1 && group.participantIds.first == user.id;
                  // Mostrar indicador de carga si el usuario aún no está disponible
                  if (loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  // Permitir eliminar grupo siempre si no hay historial o si el usuario es admin/único participante
                  if (isAdmin || isOnlyParticipant || !Navigator.canPop(context)) {
                    return ElevatedButton.icon(
                      icon: const Icon(Icons.delete),
                      label: const Text('Eliminar grupo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Eliminar grupo'),
                            content: const Text('¿Estás seguro de que deseas eliminar este grupo? Esta acción no se puede deshacer.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && user != null) {
                          await Provider.of<GroupProvider>(context, listen: false).deleteGroup(group.id, user.id);
                          Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
                        }
                      },
                    );
                  } else if (user != null && group.participantIds.contains(user.id)) {
                    return ElevatedButton.icon(
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Abandonar grupo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Abandonar grupo'),
                            content: const Text('¿Seguro que quieres abandonar este grupo?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Abandonar'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await FirebaseFirestore.instance.collection('groups').doc(group.id).update({
                            'participantIds': FieldValue.arrayRemove([user.id]),
                            'roles': group.roles.where((r) => r['uid'] != user.id).toList(),
                          });
                          Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
                        }
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteParticipantDialog extends StatefulWidget {
  final String groupId;
  const _InviteParticipantDialog({required this.groupId});

  @override
  State<_InviteParticipantDialog> createState() => _InviteParticipantDialogState();
}

class _InviteParticipantDialogState extends State<_InviteParticipantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Invitar participante'),
      content: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Correo del participante'),
                validator: (v) => v != null && v.contains('@') ? null : 'Correo inválido',
              ),
            ),
      actions: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF159d9e),
            foregroundColor: Colors.white,
          ),
          onPressed: _loading
              ? null
              : () async {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  setState(() { _loading = true; _error = null; });
                  final email = _emailController.text.trim();
                  final currentUid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
                  print('[INVITAR] UID autenticado: $currentUid');
                  print('[INVITAR] Email ingresado: ' + email);
                  try {
                    print('[INVITAR][DEBUG] Iniciando proceso de invitación...');
                    // Buscar usuario por email
                    final userSnap = await FirebaseFirestore.instance
                        .collection('users')
                        .where('email', isEqualTo: email)
                        .limit(1)
                        .get();
                    print('[INVITAR][DEBUG] Resultado búsqueda usuario: ${userSnap.docs.length} encontrados');
                    if (userSnap.docs.isEmpty) {
                      if (!mounted) return;
                      setState(() {
                        _loading = false;
                        _error = 'Usuario no encontrado';
                      });
                      print('[INVITAR][DEBUG] Usuario no encontrado');
                      return;
                    }
                    final userId = userSnap.docs.first.id;
                    print('[INVITAR][DEBUG] userId encontrado: $userId');
                    // Obtener documento actual del grupo
                    final groupRef = FirebaseFirestore.instance.collection('groups').doc(widget.groupId);
                    final groupDoc = await groupRef.get();
                    if (!groupDoc.exists) {
                      print('[INVITAR][DEBUG][ERROR] El grupo no existe');
                      setState(() {
                        _loading = false;
                        _error = 'El grupo no existe';
                      });
                      return;
                    }
                    final data = groupDoc.data();
                    print('[INVITAR][DEBUG] Datos del grupo: $data');
                    final List participantIds = List.from(data?['participantIds'] ?? []);
                    print('[INVITAR][DEBUG] participantIds actuales: $participantIds');
                    final currentUid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
                    print('[INVITAR][DEBUG] currentUid: $currentUid');
                    // Validar permisos antes del update
                    if (currentUid == null) {
                      print('[INVITAR][DEBUG][ERROR] currentUid es null');
                      setState(() {
                        _loading = false;
                        _error = 'No autenticado';
                      });
                      return;
                    }
                    if (!participantIds.contains(currentUid)) {
                      print('[INVITAR][DEBUG][ERROR] currentUid no es participante del grupo');
                      setState(() {
                        _loading = false;
                        _error = 'No tienes permisos para invitar en este grupo';
                      });
                      return;
                    }
                    // Agregar el nuevo usuario si no está
                    if (!participantIds.contains(userId)) {
                      participantIds.add(userId);
                    }
                    print('[INVITAR][DEBUG] participantIds para update: $participantIds');
                    print('[INVITAR][DEBUG] Intentando update en Firestore...');
                    await groupRef.update({
                      'participantIds': participantIds,
                      'roles': FieldValue.arrayUnion([{ 'uid': userId, 'role': 'miembro' }]),
                    });
                    final groupDocAfter = await groupRef.get();
                    print('[INVITAR][DEBUG] participantIds después del update: ${groupDocAfter.data()?['participantIds']}');
                    print('[INVITAR][DEBUG] roles después del update: ${groupDocAfter.data()?['roles']}');
                    print('[INVITAR][DEBUG] Usuario agregado correctamente');
                    if (!mounted) return;
                    setState(() => _loading = false);
                    if (!mounted) return;
                    Navigator.pop(context, true);
                  } catch (e, stack) {
                    print('[INVITAR][ERROR] $e');
                    print('[INVITAR][STACKTRACE] $stack');
                    setState(() {
                      _loading = false;
                      _error = 'Error: ${e.toString()}';
                    });
                  }
                },
          child: const Text('Invitar'),
        ),
      ],
    );
  }
}
