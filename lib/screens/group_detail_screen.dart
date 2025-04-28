import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/group_model.dart';
import '../models/user_model.dart';
import '../models/expense_model.dart';
import '../providers/group_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/advanced_add_expense_screen.dart';
import '../services/debt_calculator_service.dart';
import '../services/export_service.dart';
import '../widgets/expense_tile.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:csv/csv.dart';
import 'dart:html' as html;
import 'dart:typed_data';
import '../config/constants.dart';
import '../widgets/breadcrumb.dart';
import '../widgets/header.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class GroupDetailScreen extends StatefulWidget {
  final GroupModel group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  int _participantsReload = 0;
  bool _participantsLoading = false;

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

  String _formatCurrency(double amount, String currency) {
    switch (currency) {
      case 'CLP':
        return '\$${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
      case 'USD':
        return '\$${amount.toStringAsFixed(2)}';
      case 'EUR':
        return '€${amount.toStringAsFixed(2)}';
      default:
        return '\$${amount.toStringAsFixed(2)}';
    }
  }

  void _showExpenseDetail(BuildContext context, ExpenseModel expense) async {
    await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: expense.participantIds)
        .get();
    if (!context.mounted) return;
    Navigator.pushNamed(
      context,
      '/group/${expense.groupId}/expense/${expense.id}',
    );
  }

  Widget _buildTotalsByCurrency(Map<String, double> totalsByCurrency) {
    if (totalsByCurrency.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Totales por moneda:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...totalsByCurrency.entries.map((entry) => Text(
          '${_formatCurrency(entry.value, entry.key)} ${entry.key}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        )),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _importExpensesFromCsv() async {
    final group = widget.group;
    final users = await _fetchParticipantsByIds(group.participantIds);
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (result != null) {
      Map<String, dynamic> importResult;
      if (kIsWeb) {
        // Web: leer desde bytes
        final bytes = result.files.single.bytes;
        if (bytes == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo leer el archivo CSV.')),
          );
          return;
        }
        // Decodificar a String (UTF-8)
        String content = utf8.decode(bytes);
        // Quitar BOM si existe
        if (content.startsWith('\uFEFF')) content = content.substring(1);
        importResult = await ExportService().importExpensesFromCsvContentWithValidation(content, users, group.id);
      } else if (result.files.single.path != null) {
        final file = File(result.files.single.path!);
        importResult = await ExportService().importExpensesFromCsvWithValidation(file, users, group.id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo leer el archivo CSV.')),
        );
        return;
      }
      final List<ExpenseModel> expenses = importResult['expenses'];
      final List<String> errors = importResult['errors'];
      if (errors.isNotEmpty) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Errores en la importación'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Se encontraron los siguientes errores:'),
                    const SizedBox(height: 8),
                    ...errors.map((e) => Text(e, style: const TextStyle(color: Colors.red, fontSize: 13))),
                    const SizedBox(height: 16),
                    if (expenses.isNotEmpty)
                      Text('Aún así, se pueden importar ${expenses.length} gastos válidos.'),
                  ],
                ),
              ),
            ),
            actions: [
              if (expenses.isNotEmpty)
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _saveImportedExpenses(expenses);
                  },
                  child: const Text('Importar válidos'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        );
      } else if (expenses.isNotEmpty) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar importación'),
            content: Text('¿Deseas importar ${expenses.length} gastos?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Importar'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await _saveImportedExpenses(expenses);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se importó ningún gasto válido.')),
        );
      }
    }
  }

  Future<void> _saveImportedExpenses(List<ExpenseModel> expenses) async {
    final group = widget.group;
    final batch = FirebaseFirestore.instance.batch();
    final expensesRef = FirebaseFirestore.instance.collection('groups').doc(group.id).collection('expenses');
    for (final e in expenses) {
      final docRef = expensesRef.doc();
      batch.set(docRef, e.toMap());
    }
    await batch.commit();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Importación completada: ${expenses.length} gastos importados.')),
    );
  }

  void _showEditGroupDialog(GroupModel group) async {
    final nameController = TextEditingController(text: group.name);
    final descController = TextEditingController(text: group.description ?? '');
    String? _imagePath;
    String? _photoUrl = group.photoUrl;
    bool _uploading = false;
    String? _uploadError;
    List<String> participants = List<String>.from(group.participantIds);
    final ImagePicker _picker = ImagePicker();
    final groupRef = FirebaseFirestore.instance.collection('groups').doc(group.id);
    await showDialog(
      context: context,
      barrierDismissible: false, // No se puede cerrar haciendo click fuera
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Editar grupo'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                            if (image != null) {
                              final allowedExtensions = ['jpg', 'jpeg', 'png'];
                              final ext = image.name.split('.').last.toLowerCase();
                              final bytes = await image.length();
                              if (!allowedExtensions.contains(ext)) {
                                setState(() => _uploadError = 'Solo se permiten imágenes JPG o PNG');
                                return;
                              }
                              if (bytes > 2 * 1024 * 1024) {
                                setState(() => _uploadError = 'La imagen no debe superar los 2MB');
                                return;
                              }
                              setState(() {
                                _imagePath = image.path;
                                _uploadError = null;
                              });
                            }
                          },
                          child: FutureBuilder<DecorationImage?>(
                            future: () async {
                              if (_imagePath != null) {
                                if (kIsWeb) {
                                  final bytes = await XFile(_imagePath!).readAsBytes();
                                  return DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover);
                                } else {
                                  return DecorationImage(image: FileImage(File(_imagePath!)), fit: BoxFit.cover);
                                }
                              } else if (_photoUrl?.isNotEmpty == true) {
                                return DecorationImage(image: NetworkImage(_photoUrl!), fit: BoxFit.cover);
                              }
                              return null;
                            }(),
                            builder: (context, snapshot) {
                              return Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  shape: BoxShape.circle,
                                  image: snapshot.data,
                                ),
                                child: (_imagePath == null && (_photoUrl?.isEmpty != false))
                                    ? const Icon(Icons.group, color: Colors.white, size: 36)
                                    : null,
                              );
                            },
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nombre del grupo'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
                    ),
                    const SizedBox(height: 16),
                    const Text('Participantes', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    FutureBuilder<List<UserModel>>(
                      future: _fetchParticipantsByIds(participants),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const CircularProgressIndicator();
                        final users = snapshot.data!;
                        return Column(
                          children: users.map((user) => ListTile(
                            leading: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                                ? CircleAvatar(backgroundImage: NetworkImage(user.photoUrl!))
                                : CircleAvatar(child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?')),
                            title: Text(user.name),
                            subtitle: Text(user.email),
                            trailing: (user.id != group.adminId && participants.length > 1)
                                ? IconButton(
                                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                                    onPressed: () {
                                      setState(() => participants.remove(user.id));
                                    },
                                  )
                                : null,
                          )).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.person_add),
                      label: const Text('Añadir participante'),
                      onPressed: () async {
                        final emailController = TextEditingController();
                        String? error;
                        await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Invitar participante'),
                            content: TextField(
                              controller: emailController,
                              decoration: const InputDecoration(labelText: 'Correo del participante'),
                            ),
                            actions: [
                              if ((error ?? '').isNotEmpty)
                                Text(error ?? '', style: const TextStyle(color: Colors.red)),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  final email = emailController.text.trim();
                                  final userSnap = await FirebaseFirestore.instance
                                      .collection('users')
                                      .where('email', isEqualTo: email)
                                      .limit(1)
                                      .get();
                                  if (userSnap.docs.isEmpty) {
                                    error = 'Usuario no encontrado';
                                    setState(() {});
                                    return;
                                  }
                                  final userId = userSnap.docs.first.id;
                                  if (!participants.contains(userId)) {
                                    setState(() => participants.add(userId));
                                  }
                                  Navigator.pop(context);
                                },
                                child: const Text('Invitar'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    if (_uploading) ...[
                      const SizedBox(height: 12),
                      const CircularProgressIndicator(),
                    ],
                    if (_uploadError != null) ...[
                      const SizedBox(height: 12),
                      Text(_uploadError!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, foregroundColor: Colors.white),
                onPressed: _uploading
                    ? null
                    : () async {
                        String? newPhotoUrl = _photoUrl;
                        if (_imagePath != null) {
                          setState(() { _uploading = true; _uploadError = null; });
                          try {
                            print('[DEBUG] Subiendo imagen: $_imagePath');
                            final ref = FirebaseStorage.instance.ref().child('group_photos/${DateTime.now().millisecondsSinceEpoch}.jpg');
                            if (kIsWeb) {
                              final bytes = await XFile(_imagePath!).readAsBytes();
                              await ref.putData(bytes);
                            } else {
                              await ref.putFile(File(_imagePath!));
                            }
                            final url = await ref.getDownloadURL();
                            print('[DEBUG] Imagen subida correctamente. URL: $url');
                            newPhotoUrl = url;
                          } catch (e, st) {
                            print('[ERROR] Error al subir imagen: $e');
                            print(st);
                            setState(() { _uploading = false; _uploadError = 'Error al subir la imagen'; });
                            return;
                          }
                          setState(() { _uploading = false; });
                        }
                        await groupRef.update({
                          'name': nameController.text.trim(),
                          'description': descController.text.trim(),
                          'photoUrl': newPhotoUrl,
                          'participantIds': participants,
                        });
                        if (!mounted) return;
                        Navigator.pop(context);
                        setState(() {});
                      },
                child: const Text('Guardar'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return Scaffold(
      appBar: Header(
        currentRoute: '/group_detail',
        onDashboard: () => Navigator.pushReplacementNamed(context, '/dashboard'),
        onGroups: () => Navigator.pushReplacementNamed(context, '/groups'),
        onAccount: () => Navigator.pushReplacementNamed(context, '/account'),
        onLogout: () async {
          await authProvider.signOut();
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        },
      ),
      body: Container(
        width: double.infinity,
        color: const Color(0xFFF6F8FA),
        child: SingleChildScrollView(
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
                      BreadcrumbItem('Grupo: ${group.name}'),
                    ],
                    onTap: (i) {
                      if (i == 0) Navigator.pushReplacementNamed(context, '/dashboard');
                    },
                  ),
                  // --- FOTO DEL GRUPO Y BOTÓN EDITAR ---
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: (group.photoUrl?.isNotEmpty == true)
                            ? NetworkImage(group.photoUrl!)
                            : null,
                        child: (group.photoUrl?.isEmpty != false)
                            ? const Icon(Icons.group, color: Colors.white, size: 36)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          group.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.teal),
                        tooltip: 'Editar grupo',
                        onPressed: () => _showEditGroupDialog(group),
                      ),
                    ],
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
                    key: ValueKey(_participantsReload),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting || _participantsLoading) {
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
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Eliminar participante'),
                                  content: Text('¿Estás seguro de que deseas eliminar a ${user.name}?'),
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
                              if (confirm == true) {
                                setState(() => _participantsLoading = true);
                                await Provider.of<GroupProvider>(context, listen: false)
                                    .removeParticipantAndRedistribute(group.id, user.id);
                                await FirebaseFirestore.instance.collection('groups').doc(group.id).update({
                                  'participantIds': FieldValue.arrayRemove([user.id]),
                                  'roles': group.roles.where((r) => r['uid'] != user.id).toList(),
                                });
                                if (!mounted) return;
                                setState(() {
                                  _participantsLoading = false;
                                  _participantsReload++;
                                });
                              }
                            }
                          },
                        )).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  // --- RESUMEN DE SALDOS Y SIMPLIFICACIÓN DE DEUDAS (con nombres) ---
                  FutureBuilder<List<UserModel>>(
                    future: _fetchParticipantsByIds(group.participantIds),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final users = userSnapshot.data ?? [];
                      final idToName = {for (var u in users) u.id: u.name};
                      return StreamBuilder<List<ExpenseModel>>(
                        stream: _getGroupExpenses(group.id),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final expenses = snapshot.data ?? [];
                          if (expenses.isEmpty) {
                            return const Text('No hay gastos para calcular saldos.');
                          }
                          // --- RESUMEN DE TOTALES POR MONEDA ---
                          final Map<String, double> totalsByCurrency = {};
                          for (final e in expenses) {
                            totalsByCurrency[e.currency] = (totalsByCurrency[e.currency] ?? 0) + e.amount;
                          }
                          // --- RESUMEN DE SALDOS Y DEUDAS POR MONEDA ---
                          final Map<String, List<ExpenseModel>> expensesByCurrency = {};
                          for (final e in expenses) {
                            expensesByCurrency.putIfAbsent(e.currency, () => []).add(e);
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTotalsByCurrency(totalsByCurrency),
                              ...expensesByCurrency.entries.map((entry) {
                                final currency = entry.key;
                                final currencyExpenses = entry.value;
                                final balances = DebtCalculatorService().calculateBalances(currencyExpenses, group);
                                final transactions = DebtCalculatorService().simplifyDebts(balances);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Resumen de saldos ($currency):', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    ...balances.entries.map((e) => Text(
                                      '${idToName[e.key] ?? e.key}: '
                                      '${e.value >= 0 ? "+" : "-"}${_formatCurrency(e.value.abs(), currency)}',
                                      style: TextStyle(
                                        color: e.value > 0 ? Colors.green : (e.value < 0 ? Colors.red : Colors.black),
                                      ),
                                    )),
                                    const SizedBox(height: 8),
                                    Text('Quién le debe a quién ($currency):', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    if (transactions.isEmpty)
                                      const Text('No hay deudas pendientes.')
                                    else
                                      ...transactions.map((t) => Text(
                                        '${idToName[t['from']] ?? t['from']} le debe '
                                        '${_formatCurrency(t['amount'], currency)} a '
                                        '${idToName[t['to']] ?? t['to']}',
                                        style: const TextStyle(color: Colors.blueGrey),
                                      )),
                                    const SizedBox(height: 16),
                                  ],
                                );
                              }),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  // --- LISTA DE GASTOS AGRUPADOS POR FECHA CON PAGINACIÓN ---
                  FutureBuilder<List<UserModel>>(
                    future: _fetchParticipantsByIds(group.participantIds),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final users = userSnapshot.data ?? [];
                      final usersById = {for (var u in users) u.id: u};
                      final currentUserId = Provider.of<AuthProvider>(context, listen: false).user?.id ?? '';
                      return StreamBuilder<List<ExpenseModel>>(
                        stream: _getGroupExpenses(group.id),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final expenses = snapshot.data ?? [];
                          if (expenses.isEmpty) {
                            return const Text('No hay gastos registrados.');
                          }
                          // PAGINACIÓN
                          const int pageSize = 30;
                          final pageCount = (expenses.length / pageSize).ceil();
                          int currentPage = 0;
                          return StatefulBuilder(
                            builder: (context, setState) {
                              void goToPage(int page) {
                                setState(() {
                                  currentPage = page;
                                });
                              }
                              final start = currentPage * pageSize;
                              final end = (start + pageSize > expenses.length) ? expenses.length : start + pageSize;
                              final pageExpenses = expenses.sublist(start, end);
                              // Agrupar por fecha (yyyy-MM-dd)
                              final Map<String, List<ExpenseModel>> grouped = {};
                              for (final e in pageExpenses) {
                                final key = e.date.toLocal().toString().split(' ')[0];
                                grouped.putIfAbsent(key, () => []).add(e);
                              }
                              final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...sortedKeys.map((date) => Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Text(
                                          date,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
                                        ),
                                      ),
                                      ...grouped[date]!.map((e) => ExpenseTile(
                                            expense: e,
                                            usersById: usersById,
                                            currentUserId: currentUserId,
                                            onTap: () => _showExpenseDetail(context, e),
                                          )),
                                    ],
                                  )),
                                  const SizedBox(height: 16),
                                  if (pageCount > 1)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: Center(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.arrow_left),
                                              onPressed: currentPage > 0 ? () => goToPage(currentPage - 1) : null,
                                              color: Colors.grey[700],
                                              splashRadius: 22,
                                            ),
                                            ..._buildPaginationButtons(currentPage, pageCount, goToPage),
                                            IconButton(
                                              icon: const Icon(Icons.arrow_right),
                                              onPressed: currentPage < pageCount - 1 ? () => goToPage(currentPage + 1) : null,
                                              color: Colors.grey[700],
                                              splashRadius: 22,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  // --- SECCIÓN DE ACCIONES DE GRUPO ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.person_add),
                        label: const Text('Invitar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          setState(() => _participantsLoading = true);
                          final result = await showDialog(
                            context: context,
                            builder: (context) => _InviteParticipantDialog(groupId: group.id),
                          );
                          if (!mounted) return;
                          setState(() {
                            _participantsLoading = false;
                            if (result == true) _participantsReload++;
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar gasto'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
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
                  Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
                  const SizedBox(height: 24),
                  // --- SECCIÓN DE EXPORTAR/IMPORTAR ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.file_download),
                        label: const Text('Exportar CSV'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          final group = widget.group;
                          final users = await _fetchParticipantsByIds(group.participantIds);
                          final expensesSnap = await FirebaseFirestore.instance
                              .collection('groups')
                              .doc(group.id)
                              .collection('expenses')
                              .get();
                          final expenses = expensesSnap.docs.map((doc) => ExpenseModel.fromMap(doc.data(), doc.id)).toList();
                          final rows = [
                            [
                              'Descripción', 'Monto', 'Moneda', 'Fecha', 'Pagadores (email:monto)', 'Participantes (emails)', 'Categoría', 'Recurrente', 'Bloqueado'
                            ],
                            ...expenses.map((e) => [
                              e.description,
                              e.amount.toStringAsFixed(0),
                              e.currency,
                              e.date.toIso8601String(),
                              e.payers.map((p) {
                                final email = users.firstWhere((u) => u.id == p['userId'], orElse: () => UserModel(id: '', name: '', email: p['userId'], photoUrl: null)).email;
                                final monto = (p['amount'] is double) ? (p['amount'] as double).toInt() : p['amount'];
                                return '$email:$monto';
                              }).join(';'),
                              e.participantIds.map((id) => users.firstWhere((u) => u.id == id, orElse: () => UserModel(id: '', name: '', email: id, photoUrl: null)).email).join(';'),
                              e.category ?? '',
                              e.isRecurring ? 'Sí' : 'No',
                              e.isLocked ? 'Sí' : 'No',
                            ])
                          ];
                          final csv = const ListToCsvConverter().convert(rows);
                          final bom = '\uFEFF';
                          if (kIsWeb) {
                            // Web: descargar usando dart:html
                            final bytes = utf8.encode(bom + csv);
                            final blob = html.Blob([bytes], 'text/csv');
                            final url = html.Url.createObjectUrlFromBlob(blob);
                            html.AnchorElement(href: url)
                              ..download = 'gastos_${group.name}_${DateTime.now().millisecondsSinceEpoch}.csv'
                              ..click();
                            html.Url.revokeObjectUrl(url);
                          } else {
                            // Desktop/móvil: guardar en disco
                            final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
                            final filePath = '${dir.path}/gastos_${group.name}_${DateTime.now().millisecondsSinceEpoch}.csv';
                            final file = File(filePath);
                            await file.writeAsString(bom + csv, encoding: utf8);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Archivo exportado: $filePath')),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.file_upload),
                        label: const Text('Importar CSV'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _importExpensesFromCsv,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.download, size: 18, color: Colors.blue),
                      label: const Text(
                        'Descargar ejemplo CSV',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.1,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.blue),
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () async {
                        final rows = [
                          [
                            'Descripci\u00f3n', 'Monto', 'Moneda', 'Fecha', 'Pagadores (email:monto)', 'Participantes (emails)', 'Categor\u00eda', 'Recurrente', 'Bloqueado'
                          ],
                          [
                            'Ejemplo de gasto',
                            '10000',
                            'CLP',
                            '2025-04-27',
                            'usuario1@ejemplo.com:10000',
                            'usuario1@ejemplo.com;usuario2@ejemplo.com',
                            'Comida',
                            'No',
                            'No'
                          ]
                        ];
                        final csv = const ListToCsvConverter(fieldDelimiter: ',', eol: '\n', textDelimiter: '"').convert(rows);
                        if (kIsWeb) {
                          final bom = [0xEF, 0xBB, 0xBF];
                          final bytes = [...bom, ...utf8.encode(csv)];
                          final blob = html.Blob([Uint8List.fromList(bytes)], 'text/csv');
                          final url = html.Url.createObjectUrlFromBlob(blob);
                          html.AnchorElement(href: url)
                            ..download = 'gastos_ejemplo_importacion.csv'
                            ..click();
                          html.Url.revokeObjectUrl(url);
                        } else {
                          final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
                          final filePath = '${dir.path}/gastos_ejemplo_importacion.csv';
                          // Usar emails dummy en el archivo de ejemplo
                          await File(filePath).writeAsString('\uFEFF$csv', encoding: utf8);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Archivo de ejemplo guardado en: $filePath')),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  Divider(height: 1, thickness: 1, color: Color(0xFFE57373)),
                  const SizedBox(height: 40),
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          '¡Cuidado! Esta acción es irreversible.',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Builder(
                          builder: (context) {
                            final authProvider = Provider.of<AuthProvider>(context);
                            final user = authProvider.user;
                            final loading = authProvider.loading;
                            final isAdmin = user != null && group.adminId == user.id;
                            final isOnlyParticipant = user != null && group.participantIds.length == 1 && group.participantIds.first == user.id;
                            if (loading) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (isAdmin || isOnlyParticipant || !Navigator.canPop(context)) {
                              return ElevatedButton.icon(
                                icon: const Icon(Icons.delete),
                                label: const Text('Eliminar grupo'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPaginationButtons(int currentPage, int pageCount, void Function(int) goToPage) {
    const int maxButtons = 5;
    List<Widget> widgets = [];
    void addPage(int page) {
      final isActive = page == currentPage;
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: isActive ? null : () => goToPage(page),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: isActive
                  ? BoxDecoration(
                      color: kPrimaryColor, // color primario del proyecto
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Text(
                '${page + 1}',
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.black87,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (pageCount <= maxButtons) {
      for (int i = 0; i < pageCount; i++) {
        addPage(i);
      }
    } else {
      addPage(0);
      if (currentPage > 2) {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text('...', style: TextStyle(fontSize: 18, color: Colors.grey)),
        ));
      }
      int start = currentPage - 1;
      int end = currentPage + 1;
      if (start <= 1) {
        start = 1;
        end = 3;
      }
      if (end >= pageCount - 1) {
        end = pageCount - 2;
        start = end - 2;
      }
      for (int i = start; i <= end; i++) {
        if (i > 0 && i < pageCount - 1) addPage(i);
      }
      if (currentPage < pageCount - 3) {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text('...', style: TextStyle(fontSize: 18, color: Colors.grey)),
        ));
      }
      addPage(pageCount - 1);
    }
    return widgets;
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
            backgroundColor: kPrimaryColor,
            foregroundColor: Colors.white,
          ),
          onPressed: _loading
              ? null
              : () async {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  setState(() { _loading = true; _error = null; });
                  final email = _emailController.text.trim();
                  final currentUid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
                  try {
                    // Buscar usuario por email
                    final userSnap = await FirebaseFirestore.instance
                        .collection('users')
                        .where('email', isEqualTo: email)
                        .limit(1)
                        .get();
                    if (userSnap.docs.isEmpty) {
                      if (!mounted) return;
                      setState(() {
                        _loading = false;
                        _error = 'Usuario no encontrado';
                      });
                      return;
                    }
                    final userId = userSnap.docs.first.id;
                    // Obtener documento actual del grupo
                    final groupRef = FirebaseFirestore.instance.collection('groups').doc(widget.groupId);
                    final groupDoc = await groupRef.get();
                    if (!groupDoc.exists) {
                      setState(() {
                        _loading = false;
                        _error = 'El grupo no existe';
                      });
                      return;
                    }
                    final data = groupDoc.data();
                    final List participantIds = List.from(data?['participantIds'] ?? []);
                    // Validar permisos antes del update
                    if (currentUid == null) {
                      setState(() {
                        _loading = false;
                        _error = 'No autenticado';
                      });
                      return;
                    }
                    if (!participantIds.contains(currentUid)) {
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
                    await groupRef.update({
                      'participantIds': participantIds,
                      'roles': FieldValue.arrayUnion([{ 'uid': userId, 'role': 'miembro' }]),
                    });
                    if (!mounted) return;
                    setState(() => _loading = false);
                    if (!mounted) return;
                    Navigator.pop(context, true);
                  } catch (e) {
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
