import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../models/group_model.dart';
import '../models/expense_model.dart';
import '../models/user_model.dart';
import '../config/constants.dart';
import '../widgets/breadcrumb.dart';
import '../widgets/header.dart';
import '../utils/formatters.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ChangeNotifierProvider(
      create: (_) => GroupProvider()..loadUserGroups(user.id),
      child: const _DashboardContent(),
    );
  }
}

class _DashboardContent extends StatefulWidget {
  const _DashboardContent();

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  late Future<Map<String, double>> _balancesFuture;

  @override
  void initState() {
    super.initState();
    _balancesFuture = _loadBalances();
  }

  Future<Map<String, double>> _loadBalances() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    final user = authProvider.user!;
    final groups = groupProvider.groups;
    // Sumar balances por moneda
    final Map<String, double> totalBalances = {};
    for (final group in groups) {
      for (final item in group.participantBalances) {
        if (item['userId'] == user.id && item['balances'] is Map) {
          final balances = item['balances'] as Map;
          balances.forEach((currency, value) {
            if (value is num) {
              totalBalances[currency] = (totalBalances[currency] ?? 0) + value.toDouble();
            }
          });
        }
      }
    }
    return totalBalances;
  }

  Future<void> _refreshBalances() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    final user = authProvider.user!;
    await groupProvider.loadUserGroups(user.id);
    setState(() {
      _balancesFuture = _loadBalances();
    });
  }

  Widget _buildBalanceSummary(Map<String, double> balances) {
    if (balances.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No tienes saldos pendientes en ningún grupo.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[700]),
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resumen de tus balances', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            ...balances.entries.map((e) {
              final color = e.value > 0.01
                  ? Colors.green
                  : (e.value < -0.01 ? Colors.red : Colors.grey[700]);
              return Row(
                children: [
                  Text(
                    formatCurrency(e.value, e.key),
                    style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(e.key, style: TextStyle(color: Colors.grey[600])),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user!;
    final groupProvider = Provider.of<GroupProvider>(context);
    return Scaffold(
      appBar: Header(
        currentRoute: '/dashboard',
        onDashboard: () => Navigator.pushReplacementNamed(context, '/dashboard'),
        onGroups: () => Navigator.pushReplacementNamed(context, '/groups'),
        onAccount: () => Navigator.pushReplacementNamed(context, '/account'),
        onLogout: () async {
          await authProvider.signOut();
          Navigator.pushReplacementNamed(context, '/login');
        },
      ),
      backgroundColor: const Color(0xFFF6F8FA),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.group_add),
        label: const Text('Nuevo grupo', style: TextStyle(color: Colors.white)),
        onPressed: () => _showCreateGroupDialog(context, user.id),
      ),
      body: Container(
        width: double.infinity,
        color: const Color(0xFFF6F8FA),
        child: RefreshIndicator(
          onRefresh: _refreshBalances,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Breadcrumb(
                      items: [
                        BreadcrumbItem('Inicio'),
                        BreadcrumbItem('Dashboard'),
                      ],
                      onTap: (i) {
                        if (i == 0) Navigator.pushReplacementNamed(context, '/dashboard');
                      },
                    ),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: kPrimaryColor,
                          backgroundImage: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                              ? NetworkImage(user.photoUrl!)
                              : null,
                          child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                              ? Text(
                                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                  style: const TextStyle(fontSize: 28, color: Colors.white),
                                )
                              : null,
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.email,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // --- RESUMEN DE BALANCES ---
                    FutureBuilder<Map<String, double>>(
                      future: _balancesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text('Error al cargar balances', style: TextStyle(color: Colors.red[700])),
                          );
                        }
                        return _buildBalanceSummary(snapshot.data ?? {});
                      },
                    ),
                    // --- FIN RESUMEN DE BALANCES ---
                    Text(
                      'Tus grupos',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: kPrimaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 26,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aquí puedes ver y gestionar todos tus grupos de gastos compartidos.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 16),
                    if (groupProvider.loading)
                      const Center(child: CircularProgressIndicator())
                    else if (groupProvider.groups.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'No tienes grupos aún. ¡Crea uno nuevo!',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[700]),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: groupProvider.groups.length,
                        itemBuilder: (context, index) {
                          final g = groupProvider.groups[index];
                          return _GroupCard(group: g, currentUserId: user.id);
                        },
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

class _GroupCard extends StatelessWidget {
  final GroupModel group;
  final String currentUserId;
  const _GroupCard({required this.group, required this.currentUserId});

  // Función para obtener todos los participantes del grupo
  Future<Map<String, UserModel>> _fetchParticipants(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    final usersSnap = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: userIds)
        .get();
    return { for (var doc in usersSnap.docs) doc.id : UserModel.fromMap(doc.data(), doc.id) };
  }


  @override
  Widget build(BuildContext context) {
    if (group.id.isEmpty) {
      return const SizedBox.shrink();
    }
    // Usar un FutureBuilder principal para obtener los participantes Y el último gasto
    return FutureBuilder<Map<String, dynamic>>(
      future: () async {
        // Obtener participantes
        final participantsMap = await _fetchParticipants(group.participantIds);
        // Obtener último gasto
        final expenseSnap = await FirebaseFirestore.instance
            .collection('groups')
            .doc(group.id)
            .collection('expenses')
            .orderBy('date', descending: true)
            .limit(1)
            .get();
        ExpenseModel? lastExpense;
        if (expenseSnap.docs.isNotEmpty) {
          lastExpense = ExpenseModel.fromMap(expenseSnap.docs.first.data(), expenseSnap.docs.first.id);
        }
        return {'participants': participantsMap, 'lastExpense': lastExpense};
      }(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Puedes mostrar un placeholder mientras carga
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: const Padding(padding: EdgeInsets.all(24), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
           // Manejar error o falta de datos si es necesario
           return const SizedBox.shrink(); // O mostrar un mensaje de error
        }

        final participantsMap = snapshot.data!['participants'] as Map<String, UserModel>;
        final ExpenseModel? lastExpense = snapshot.data!['lastExpense'];

        final DateTime? lastDate = lastExpense?.date;
        final String? lastDesc = lastExpense?.description; 
        final String? lastCurrency = lastExpense?.currency;
        final double? lastAmount = lastExpense?.amount;
        
        // Intentar obtener el ID del creador o del primer pagador
        String? userIdToShow;
        if (lastExpense != null) {
          if (lastExpense.createdBy.isNotEmpty) {
            userIdToShow = lastExpense.createdBy;
          } else if (lastExpense.payers.isNotEmpty && lastExpense.payers[0]['userId'] != null) {
            userIdToShow = lastExpense.payers[0]['userId'];
            // --- DEBUG PRINT --- 
            print('[DEBUG Dashboard Card - Group: ${group.name}] Using Payer ID: $userIdToShow because createdBy is empty.');
            // --- END DEBUG --- 
          }
        }

        String? nameToShow = participantsMap[userIdToShow]?.name;

        // --- DEBUG PRINT --- 
        print('[DEBUG Dashboard Card - Group: ${group.name}] User ID to Show: $userIdToShow, Found in Map: ${nameToShow != null}, Name from Map: $nameToShow');
        // --- END DEBUG --- 

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          color: const Color(0xFAF8FBFF),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.pushNamed(context, '/group/${group.id}'),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Foto o placeholder
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: (group.photoUrl != null && group.photoUrl!.isNotEmpty)
                        ? NetworkImage(group.photoUrl!)
                        : null,
                    child: (group.photoUrl == null || group.photoUrl!.isEmpty)
                        ? const Icon(Icons.group, size: 38, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(width: 24),
                  // Info principal y balance + último gasto alineados
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group.name,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  if (group.description != null && group.description!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                                      child: Text(
                                        group.description!,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  // Mi balance en una sola línea
                                  FutureBuilder<QuerySnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('groups')
                                        .doc(group.id)
                                        .collection('expenses')
                                        .where('currency', isEqualTo: group.currency)
                                        .get(),
                                    builder: (context, snap) {
                                      double balance = 0;
                                      String currency = group.currency;
                                      if (snap.hasData) {
                                        for (var doc in snap.data!.docs) {
                                          final exp = ExpenseModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
                                          final pagado = exp.payers.where((p) => p['userId'] == currentUserId).fold<double>(0, (a, b) => a + (b['amount'] as num).toDouble());
                                          final esParticipante = exp.participantIds.contains(currentUserId);
                                          final parte = esParticipante
                                              ? (exp.splitType == 'equal' ? exp.amount / exp.participantIds.length : _getUserShare(exp, currentUserId))
                                              : 0;
                                          balance += pagado - parte;
                                        }
                                      }
                                      Color color;
                                      if (balance > 0.01) {
                                        color = Colors.green;
                                      } else if (balance < -0.01) {
                                        color = Colors.red;
                                      } else {
                                        color = Colors.grey[600]!;
                                      }
                                      String balanceStr = formatCurrency(balance, currency); // Usar formatCurrency
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Text(
                                          'Mi balance: $balanceStr',
                                          style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 16),
                                        ),
                                      );
                                    },
                                  ),
                                  // Último gasto (descripción y valor juntos, alineados a la izquierda)
                                  if (lastExpense != null)
                                    Padding( // Añadir padding para espaciado vertical
                                      padding: const EdgeInsets.only(bottom: 4.0), // Espacio debajo de esta línea
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.receipt_long, size: 16, color: Colors.grey), // Icono gris y más pequeño
                                          const SizedBox(width: 6),
                                          Text(
                                            'Último gasto: "${lastDesc ?? ''}"',
                                            style: const TextStyle(fontSize: 14, color: Colors.grey), // Texto gris
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            formatCurrency(lastAmount ?? 0, lastCurrency ?? group.currency), // Usar formatCurrency
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.grey), // Texto gris y peso normal
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (lastExpense != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 0), // Ajustar padding superior a 0
                                      child: Row(
                                        children: [
                                          const Icon(Icons.person, size: 16, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          // Lógica para mostrar el nombre:
                                          if (nameToShow != null)
                                            // Si lo encontramos en el mapa de participantes actuales, mostrarlo
                                            Text(
                                              'por $nameToShow',
                                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                                            )
                                          else if (userIdToShow != null && userIdToShow.isNotEmpty)
                                            // Si no está en el mapa pero tenemos ID, buscarlo con FutureBuilder
                                            FutureBuilder<DocumentSnapshot>(
                                              future: FirebaseFirestore.instance.collection('users').doc(userIdToShow).get(),
                                              builder: (context, userSnap) {
                                                String name = 'Alguien'; // Default
                                                if (userSnap.connectionState == ConnectionState.done && userSnap.hasData && userSnap.data!.exists) {
                                                  final data = userSnap.data!.data() as Map<String, dynamic>;
                                                  name = data['name'] ?? 'Alguien';
                                                } else if (userSnap.connectionState == ConnectionState.waiting) {
                                                  name = '...'; // Placeholder mientras carga
                                                }
                                                return Text(
                                                  'por $name',
                                                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                                                );
                                              },
                                            )
                                          else
                                            // Si no hay ID válido, mostrar "Alguien"
                                            const Text(
                                              'por Alguien',
                                              style: TextStyle(fontSize: 13, color: Colors.grey),
                                            ),
                                          const SizedBox(width: 12),
                                          const Icon(Icons.calendar_today, size: 15, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            formatDateShort(lastDate), // Usar formatDateShort
                                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static double _getUserShare(ExpenseModel exp, String userId) {
    if (exp.splitType == 'equal') {
      return exp.amount / exp.participantIds.length;
    }
    if (exp.customSplits != null) {
      final split = exp.customSplits!.firstWhere(
        (s) => s['userId'] == userId,
        orElse: () => <String, dynamic>{},
      );
      if (split['amount'] != null) {
        return (split['amount'] as num).toDouble();
      }
    }
    return 0;
  }
}

void _showCreateGroupDialog(BuildContext context, String userId) {
  final groupProvider = Provider.of<GroupProvider>(context, listen: false);
  final nameController = TextEditingController();
  final descController = TextEditingController();
  String currency = 'CLP';
  final currencies = [
    {'code': 'CLP', 'label': 'CLP', 'icon': '🇨🇱'},
    {'code': 'USD', 'label': 'USD', 'icon': '🇺🇸'},
    {'code': 'EUR', 'label': 'EUR', 'icon': '🇪🇺'},
  ];
  String? imagePath;
  final ImagePicker picker = ImagePicker();
  bool uploading = false;
  String? uploadError;
  showDialog(
    context: context,
    useRootNavigator: false,
    builder: (context) {
      String? errorMsg;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: FractionallySizedBox(
            widthFactor: 0.9,
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        setState(() => imagePath = image.path);
                      }
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        shape: BoxShape.circle,
                        image: imagePath != null
                            ? DecorationImage(image: FileImage(File(imagePath!)), fit: BoxFit.cover)
                            : null,
                      ),
                      child: imagePath == null
                          ? const Icon(Icons.camera_alt, color: Colors.white, size: 36)
                          : null,
                    ),
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Moneda: '),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: currency,
                        items: currencies.map((c) => DropdownMenuItem<String>(
                          value: c['code'],
                          child: Row(
                            children: [
                              Text(c['icon'] ?? ''),
                              const SizedBox(width: 4),
                              Text(c['label'] ?? ''),
                            ],
                          ),
                        )).toList(),
                        onChanged: (v) => setState(() => currency = v ?? 'CLP'),
                      ),
                    ],
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 16),
                    Text(errorMsg!, style: const TextStyle(color: Colors.red)),
                  ],
                  if (uploading) ...[
                    const SizedBox(height: 12),
                    const CircularProgressIndicator(),
                  ],
                  if (uploadError != null) ...[
                    const SizedBox(height: 12),
                    Text(uploadError!, style: const TextStyle(color: Colors.red)),
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
            Builder(
              builder: (dialogContext) => ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, foregroundColor: Colors.white),
                onPressed: uploading
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;
                        String? photoUrl;
                        if (imagePath != null) {
                          setState(() { uploading = true; uploadError = null; });
                          try {
                            final ref = FirebaseStorage.instance.ref().child('group_photos/${DateTime.now().millisecondsSinceEpoch}.jpg');
                            await ref.putFile(File(imagePath!));
                            photoUrl = await ref.getDownloadURL();
                          } catch (e) {
                            setState(() { uploading = false; uploadError = 'Error al subir la imagen'; });
                            return;
                          }
                          setState(() { uploading = false; });
                        }
                        final group = GroupModel(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: name,
                          description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                          participantIds: [userId],
                          adminId: userId,
                          roles: [
                            {'uid': userId, 'role': 'admin'}
                          ],
                          currency: currency,
                          photoUrl: photoUrl,
                        );
                        try {
                          await groupProvider.createGroup(group, userId);
                          Navigator.pop(dialogContext);
                        } catch (e) {
                          setState(() {
                            errorMsg = e.toString().contains('permission-denied')
                              ? 'No tienes permisos para crear el grupo. Verifica tus reglas de Firestore.'
                              : 'Error al crear el grupo: ${e.toString()}';
                          });
                        }
                      },
                child: const Text('Crear'),
              ),
            ),
          ],
        ),
      );
    },
  );
}
