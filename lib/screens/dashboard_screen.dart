import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../models/group_model.dart';
import '../models/user_model.dart';
import '../config/constants.dart';
import '../widgets/header.dart';
import '../widgets/app_footer.dart';
import '../widgets/category_spending_chart.dart';
import '../providers/expense_provider.dart';
import '../widgets/dashboard_balance_card.dart'; 
import '../widgets/group_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => GroupProvider()..loadUserGroups(user.id),
        ),
        ChangeNotifierProxyProvider<GroupProvider, ExpenseProvider>(
          create: (_) => ExpenseProvider(),
          update: (_, groupProvider, expenseProvider) {
            final firstGroupId = groupProvider.groups.isNotEmpty ? 
              groupProvider.groups.first.id : null;
            
            if (expenseProvider != null && firstGroupId != null && 
                (expenseProvider.currentGroupId == null || expenseProvider.currentGroupId != firstGroupId)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // Corregido: Usar la instancia de expenseProvider directamente
                // y asegurarse de que el contexto para el Provider.of sea el correcto si fuera necesario en otro lugar,
                // pero aquí basta con la instancia y verificar que el grupo aún exista.
                if (groupProvider.groups.any((g) => g.id == firstGroupId)) {
                   expenseProvider.loadExpenses(firstGroupId);
                }
              });
            }
            return expenseProvider!;
          },
        ),
      ],
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
  GroupProvider? _groupProvider;
  ExpenseProvider? _expenseProvider;

  @override
  void initState() {
    super.initState();
    _balancesFuture = Future.value({}); 

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _groupProvider = Provider.of<GroupProvider>(context, listen: false);
        _expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);

        _groupProvider?.addListener(_onProvidersChanged);
        _expenseProvider?.addListener(_onProvidersChanged);

        if (mounted) {
          setState(() {
            _balancesFuture = _loadBalances();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _groupProvider?.removeListener(_onProvidersChanged);
    _expenseProvider?.removeListener(_onProvidersChanged);
    super.dispose();
  }

  void _onProvidersChanged() {
    if (mounted) {
      setState(() {
        _balancesFuture = _loadBalances();
      });
    }
  }

  Future<Map<String, double>> _loadBalances() async {
    if (!mounted || _groupProvider == null) {
      return Future.value({});
    }
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null) {
      return Future.value({});
    }

    final groups = _groupProvider!.groups;
    final Map<String, double> totalBalances = {};

    for (final group in groups) {
      for (final item in group.participantBalances) {
        if (item['userId'] == user.id) {
          final balances = item['balances'] as Map<String, dynamic>; 
          balances.forEach((currency, value) {
            totalBalances[currency] = (totalBalances[currency] ?? 0) + (value as num).toDouble();
          });
        }
      }
    }
    return totalBalances;
  }

  Widget _buildDashboardScreenContent(String? groupId, UserModel user, GroupProvider groupProvider, bool isMobile) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 225, 247, 244), // Fondo general de la pantalla
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.group_add),
        label: const Text('New group', style: TextStyle(color: Colors.white)),
        onPressed: () => _showCreateGroupDialog(context, user.id),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              Header(
                currentRoute: '/dashboard',
                onDashboard: () => Navigator.pushReplacementNamed(context, '/dashboard'),
                onGroups: () => Navigator.pushReplacementNamed(context, '/groups'),
                onAccount: () => Navigator.pushReplacementNamed(context, '/account'),
                onLogout: () async {
                  await Provider.of<AuthProvider>(context, listen: false).signOut();
                  Navigator.pushReplacementNamed(context, '/login');
                },
                avatarUrl: user.photoUrl,
                displayName: user.name,
                email: user.email,
              ),
              Container(
                width: isMobile ? double.infinity : MediaQuery.of(context).size.width * 0.95,
                constraints: isMobile ? null : const BoxConstraints(maxWidth: 1280),
                margin: EdgeInsets.only(top: isMobile ? 8 : 20, bottom: isMobile ? 8 : 20, left: isMobile ? 10 : 0, right: isMobile ? 10 : 0),
                padding: EdgeInsets.all(isMobile ? 8 : 18),
                decoration: BoxDecoration(
                  color: Colors.white, // Fondo blanco para el contenedor principal del contenido
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
                  children: <Widget>[
                    // Sección de Información de Usuario y Balance General
                    Padding(
                      padding: EdgeInsets.only(
                        top: isMobile ? 18 : 28,
                        left: isMobile ? 8 : 28,
                        right: isMobile ? 8 : 28,
                        bottom: isMobile ? 12 : 20, // Espacio antes de la siguiente sección
                      ),
                      child: Column(
                        children: [
                          Row( // Encabezado de Usuario
                            children: [
                              CircleAvatar(
                                radius: isMobile ? 24 : 28, // Ajuste de tamaño para móvil
                                backgroundColor: Colors.grey[300],
                                backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty ? NetworkImage(user.photoUrl!) : null,
                                child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                                    ? Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?', style: TextStyle(fontSize: isMobile ? 20 : 24, color: Colors.white))
                                    : null,
                              ),
                              const SizedBox(width: 18),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 18 : 22)),
                                  if (user.email.isNotEmpty)
                                    Text(user.email, style: TextStyle(color: Colors.grey, fontSize: isMobile ? 13 : 15)),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: isMobile ? 16 : 24), // Espacio aumentado
                          // DashboardBalanceCard ahora incluye el título "Summary of your balances"
                          DashboardBalanceCard(
                            balancesFuture: _balancesFuture,
                            isMobile: isMobile,
                            // Podríamos pasar un callback para "Settle up" aquí si fuera necesario
                            // onSettleUp: () { /* Lógica para Settle Up */ },
                          ),
                        ],
                      ),
                    ),
                    
                    // Divisor visual sutil
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 28, vertical: isMobile ? 8 : 16),
                      child: Divider(color: Colors.grey[300], height: 1),
                    ),

                    // Sección de Grupos y Gastos por Categoría
                    if (isMobile) ...[
                      // VISTA MOBILE: Columnas
                      _buildGroupsSection(user, groupProvider, isMobile),
                      if (groupId != null) _buildCategorySpendingSection(groupId, isMobile),
                    ] else ...[
                      // VISTA DESKTOP: Filas
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10), // Padding para la sección de Row
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 1, // Los grupos toman MENOS espacio
                              child: _buildGroupsSection(user, groupProvider, isMobile),
                            ),
                            const SizedBox(width: 24), // Espacio entre las dos columnas
                            Expanded(
                              flex: 2, // El gráfico de categorías toma MÁS espacio
                              child: groupId != null 
                                  ? _buildCategorySpendingSection(groupId, isMobile)
                                  : const SizedBox(), // Si no hay groupId, no mostrar nada
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const AppFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // Nuevo widget helper para la sección de grupos
  Widget _buildGroupsSection(UserModel user, GroupProvider groupProvider, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            bottom: 16,
            left: isMobile ? 0 : 0,
            top: isMobile ? 20 : 10,
            right: isMobile ? 0 : 0,
          ),
          child: Row(
            children: [
              Icon(Icons.group_outlined, color: Colors.black54, size: isMobile ? 20 : 22), // Ajustado
              const SizedBox(width: 8), // Ajustado
              Text(
                'Your Groups',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: isMobile ? 18 : 20, // Ajustado
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        Consumer<GroupProvider>(
          builder: (context, groupProviderConsumer, _) {
            if (groupProviderConsumer.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (groupProviderConsumer.groups.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: Text('No groups yet. Create one to get started!', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey))),
              );
            }
            return ListView.builder( // Usar ListView.builder para mejor rendimiento si hay muchos grupos
              shrinkWrap: true, // Necesario dentro de otra SingleChildScrollView/Column
              physics: const NeverScrollableScrollPhysics(), // Deshabilitar scroll propio
              itemCount: groupProviderConsumer.groups.length,
              itemBuilder: (context, index) {
                final group = groupProviderConsumer.groups[index];
                return GroupCard(key: ValueKey(group.id), group: group, currentUserId: user.id);
              },
            );
          },
        ),
      ],
    );
  }

  // Nuevo widget helper para la sección de gastos por categoría
  Widget _buildCategorySpendingSection(String groupId, bool isMobile) {
    return Card( // Envolver CategorySpendingChart directamente con Card
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.08),
      color: Colors.white,
      margin: EdgeInsets.only(
        top: isMobile ? 16 : 0, // Ajustado para desktop
        bottom: isMobile ? 16 : 10,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isMobile ? 12 : 18, // left
          isMobile ? 12 : 10,  // top
          isMobile ? 12 : 18, // right
          isMobile ? 12 : 18  // bottom
        ),
        child: CategorySpendingChart(groupId: groupId), // Pasar el groupId
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user!;
    final groupProviderInstance = Provider.of<GroupProvider>(context, listen: false);
    final firstGroupId = groupProviderInstance.groups.isNotEmpty ? groupProviderInstance.groups.first.id : null;
    final isMobile = MediaQuery.of(context).size.width < 1000; // Changed breakpoint to 1000px

    return _buildDashboardScreenContent(firstGroupId, user, groupProviderInstance, isMobile);
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
  String? uploadErrorText;
  String? errorMsgText;

  showDialog(
    context: context,
    useRootNavigator: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Create New Group'),
          content: FractionallySizedBox(
            widthFactor: 0.9,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        setStateDialog(() => imagePath = image.path);
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
                    decoration: const InputDecoration(labelText: 'Group name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Description (optional)'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Currency: '),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: currency,
                        items: currencies.map((c) => DropdownMenuItem<String>(
                          value: c['code']!,
                          child: Row(
                            children: [
                              Text(c['icon'] ?? ''),
                              const SizedBox(width: 4),
                              Text(c['label'] ?? ''),
                            ],
                          ),
                        )).toList(),
                        onChanged: (v) => setStateDialog(() => currency = v ?? 'CLP'),
                      ),
                    ],
                  ),
                  if (errorMsgText != null) ...[
                    const SizedBox(height: 16),
                    Text(errorMsgText!, style: const TextStyle(color: Colors.red)),
                  ],
                  if (uploading) ...[
                    const SizedBox(height: 12),
                    const CircularProgressIndicator(),
                  ],
                  if (uploadErrorText != null) ...[
                    const SizedBox(height: 12),
                    Text(uploadErrorText!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, foregroundColor: Colors.white),
              onPressed: uploading
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        setStateDialog(() {
                           errorMsgText = 'Group name cannot be empty.';
                        });
                        return;
                      }
                      setStateDialog(() {
                        errorMsgText = null;
                      });

                      String? photoUrl;
                      if (imagePath != null) {
                        setStateDialog(() { uploading = true; uploadErrorText = null; });
                        try {
                          final ref = FirebaseStorage.instance.ref().child('group_photos/${DateTime.now().millisecondsSinceEpoch}.jpg');
                          await ref.putFile(File(imagePath!));
                          photoUrl = await ref.getDownloadURL();
                        } catch (e) {
                          setStateDialog(() { uploading = false; uploadErrorText = 'Error uploading image: $e'; });
                          return;
                        }
                        setStateDialog(() { uploading = false; });
                      }
                      // Create a unique ID for the new group
                      final newGroupId = DateTime.now().millisecondsSinceEpoch.toString();

                      final newGroup = GroupModel(
                        id: newGroupId, // Use the generated ID
                        name: name,
                        description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                        participantIds: [userId],
                        adminId: userId,
                        roles: [
                          {'uid': userId, 'role': 'admin'}
                        ],
                        currency: currency,
                        photoUrl: photoUrl,
                        participantBalances: [], 
                      );
                      try {
                        await groupProvider.createGroup(newGroup, userId);
                        await FirebaseAnalytics.instance.logEvent(
                          name: 'create_group',
                          parameters: {
                            'group_id': newGroup.id,
                            'group_name': newGroup.name,
                            'currency': newGroup.currency,
                          },
                        );
                        Navigator.pop(dialogContext);
                      } catch (e) {
                        setStateDialog(() {
                          errorMsgText = e.toString().contains('permission-denied')
                            ? 'Permission denied. Check Firestore rules.'
                            : 'Error creating group: ${e.toString()}';
                        });
                      }
                    },
              child: const Text('Create'),
            ),
          ],
        ),
      );
    },
  );
}
