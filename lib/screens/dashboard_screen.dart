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
      backgroundColor: const Color(0xFFF6F8FA),
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
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: isMobile ? 18 : 28, left: isMobile ? 8 : 28, right: isMobile ? 8 : 28),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.grey[300],
                                backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty ? NetworkImage(user.photoUrl!) : null,
                                child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                                    ? Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 24, color: Colors.white))
                                    : null,
                              ),
                              const SizedBox(width: 18),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                                  if (user.email.isNotEmpty)
                                    Text(user.email, style: const TextStyle(color: Colors.grey, fontSize: 15)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        DashboardBalanceCard(
                          balancesFuture: _balancesFuture,
                          isMobile: isMobile,
                        ),
                        const SizedBox(height: 24),
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 0,
                          color: Colors.white,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: isMobile ? 12 : 24,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Your groups', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22)),
                                const SizedBox(height: 16),
                                Consumer<GroupProvider>(
                                  builder: (context, groupProviderConsumer, _) {
                                    if (groupProviderConsumer.loading) {
                                      return const Center(child: CircularProgressIndicator());
                                    }
                                    if (groupProviderConsumer.groups.isEmpty) {
                                      return const Text('No groups yet.');
                                    }
                                    return Column(
                                      children: groupProviderConsumer.groups.map((group) {
                                        return GroupCard(key: ValueKey(group.id), group: group, currentUserId: user.id);
                                      }).toList(),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (groupId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 24.0),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                          color: Colors.white,
                          child: Padding(
                            padding: EdgeInsets.all(isMobile ? 8 : 18),
                            child: CategorySpendingChart(groupId: groupId),
                          ),
                        ),
                      ),
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user!;
    final groupProviderInstance = Provider.of<GroupProvider>(context, listen: false);
    final firstGroupId = groupProviderInstance.groups.isNotEmpty ? groupProviderInstance.groups.first.id : null;
    final isMobile = MediaQuery.of(context).size.width < 600;

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
