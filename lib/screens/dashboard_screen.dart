import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../models/group_model.dart';
import '../models/expense_model.dart';
import '../models/user_model.dart';
import '../config/constants.dart';
import '../widgets/header.dart';
import '../utils/formatters.dart';
import '../widgets/app_footer.dart';

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
  GroupProvider? _groupProvider;

  @override
  void initState() {
    super.initState();
    _balancesFuture = _loadBalances();
    // Escuchar cambios en el provider para recargar balances automáticamente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      groupProvider.addListener(_onGroupsChanged);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _groupProvider ??= Provider.of<GroupProvider>(context, listen: false);
  }

  @override
  void dispose() {
    _groupProvider?.removeListener(_onGroupsChanged);
    super.dispose();
  }

  void _onGroupsChanged() {
    setState(() {
      _balancesFuture = _loadBalances();
    });
  }

  Future<Map<String, double>> _loadBalances() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    final user = authProvider.user!;
    final groups = groupProvider.groups;
    // Sum balances by currency
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


  Widget _buildBalanceSummary(Map<String, double> balances) {
    print('BALANCES DEBUG: ${balances.toString()}'); // DEBUG LOG
    if (balances.isEmpty) {
      return const SizedBox.shrink();
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
            const Text('Summary of your balances', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
            }),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              return Column(
                children: [
                  Header(
                    currentRoute: '/dashboard',
                    onDashboard: () => Navigator.pushReplacementNamed(context, '/dashboard'),
                    onGroups: () => Navigator.pushReplacementNamed(context, '/groups'),
                    onAccount: () => Navigator.pushReplacementNamed(context, '/account'),
                    onLogout: () async {
                      await authProvider.signOut();
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
                    padding: EdgeInsets.all(isMobile ? 0 : 32),
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
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 8 : 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 18),
                          Center(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Información del usuario ahora dentro del contenedor
                                Row(
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
                                const SizedBox(height: 18),
                                Card(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  elevation: 0,
                                  color: Colors.white,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: isMobile ? 18 : 28,
                                      horizontal: isMobile ? 8 : 28,
                                    ),
                                    child: isMobile
                                        ? Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Summary of your balances', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22)),
                                              FutureBuilder<Map<String, double>>(
                                                future: _balancesFuture,
                                                builder: (context, snapshot) {
                                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                                    return const Padding(
                                                      padding: EdgeInsets.only(top: 8.0),
                                                      child: CircularProgressIndicator(),
                                                    );
                                                  }
                                                  final balances = snapshot.data ?? {};
                                                  if (balances.isEmpty) {
                                                    return const Padding(
                                                      padding: EdgeInsets.only(top: 8.0),
                                                      child: Text('No balances', style: TextStyle(fontSize: 22, color: Colors.grey)),
                                                    );
                                                  }
                                                  final value = balances.values.first;
                                                  final currency = balances.keys.first;
                                                  final color = value < 0 ? Color(0xFFE14B4B) : Color(0xFF1BC47D);
                                                  return Padding(
                                                    padding: const EdgeInsets.only(top: 8.0),
                                                    child: Text(
                                                      formatCurrency(value, currency),
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 36,
                                                        color: color,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                              const SizedBox(height: 16),
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton(
                                                  onPressed: () {},
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF179D8B),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                                    elevation: 0,
                                                  ),
                                                  child: const Text('Settle up', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white)),
                                                ),
                                              ),
                                            ],
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text('Summary of your balances', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22)),
                                                    FutureBuilder<Map<String, double>>(
                                                      future: _balancesFuture,
                                                      builder: (context, snapshot) {
                                                        if (snapshot.connectionState == ConnectionState.waiting) {
                                                          return const Padding(
                                                            padding: EdgeInsets.only(top: 8.0),
                                                            child: CircularProgressIndicator(),
                                                          );
                                                        }
                                                        final balances = snapshot.data ?? {};
                                                        if (balances.isEmpty) {
                                                          return const Padding(
                                                            padding: EdgeInsets.only(top: 8.0),
                                                            child: Text('No balances', style: TextStyle(fontSize: 22, color: Colors.grey)),
                                                          );
                                                        }
                                                        final value = balances.values.first;
                                                        final currency = balances.keys.first;
                                                        final color = value < 0 ? Color(0xFFE14B4B) : Color(0xFF1BC47D);
                                                        return Padding(
                                                          padding: const EdgeInsets.only(top: 8.0),
                                                          child: Text(
                                                            formatCurrency(value, currency),
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 36,
                                                              color: color,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                fit: FlexFit.loose,
                                                child: ElevatedButton(
                                                  onPressed: () {},
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF179D8B),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                                    elevation: 0,
                                                  ),
                                                  child: const Text('Settle up', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white)),
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
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
                                          builder: (context, groupProvider, _) {
                                            if (groupProvider.loading) {
                                              return const Center(child: CircularProgressIndicator());
                                            }
                                            if (groupProvider.groups.isEmpty) {
                                              return const Text('No groups yet.');
                                            }
                                            return Column(
                                              children: groupProvider.groups.map((group) {
                                                return _GroupCard(group: group, currentUserId: user.id);
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

class _GroupCard extends StatefulWidget {
  final GroupModel group;
  final String currentUserId;
  const _GroupCard({required this.group, required this.currentUserId});

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _hovering = false;
  late Future<Map<String, dynamic>> _futureData;

  @override
  void initState() {
    super.initState();
    _futureData = () async {
      final participantsMap = await _fetchParticipants(widget.group.participantIds);
      final expenseSnap = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.group.id)
          .collection('expenses')
          .orderBy('date', descending: true)
          .limit(1)
          .get();
      ExpenseModel? lastExpense;
      if (expenseSnap.docs.isNotEmpty) {
        lastExpense = ExpenseModel.fromMap(expenseSnap.docs.first.data(), expenseSnap.docs.first.id);
      }
      return {'participants': participantsMap, 'lastExpense': lastExpense};
    }();
  }

  Future<Map<String, UserModel>> _fetchParticipants(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    final usersSnap = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: userIds)
        .get();
    return { for (var doc in usersSnap.docs) doc.id : UserModel.fromMap(doc.data(), doc.id) };
  }

  Future<double> _getUserBalance() async {
    final expensesSnap = await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.group.id)
        .collection('expenses')
        .where('currency', isEqualTo: widget.group.currency)
        .get();
    double balance = 0;
    for (var doc in expensesSnap.docs) {
      final exp = ExpenseModel.fromMap(doc.data(), doc.id);
      final paid = exp.payers.where((p) => p['userId'] == widget.currentUserId).fold<double>(0, (a, b) => a + (b['amount'] as num).toDouble());
      final isParticipant = exp.participantIds.contains(widget.currentUserId);
      final share = isParticipant
          ? (exp.splitType == 'equal' ? exp.amount / exp.participantIds.length : _GroupCardState._getUserShare(exp, widget.currentUserId))
          : 0;
      balance += paid - share;
    }
    return balance;
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
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(padding: EdgeInsets.all(24), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final ExpenseModel? lastExpense = snapshot.data!['lastExpense'];
        final group = widget.group;
        final currency = group.currency;

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
                  ? [BoxShadow(color: Colors.teal.withOpacity(0.10), blurRadius: 16, offset: const Offset(0, 4))]
                  : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.pushNamed(context, '/group/${group.id}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                  child: Row(
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
                          children: [
                            Text(
                              group.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            FutureBuilder<double>(
                              future: _getUserBalance(),
                              builder: (context, balSnap) {
                                final bal = balSnap.data ?? 0.0;
                                final color = bal < -0.01
                                    ? const Color(0xFFE14B4B)
                                    : (bal > 0.01 ? const Color(0xFF1BC47D) : Colors.grey[700]);
                                return Text(
                                  'My balance: ${formatCurrency(bal, currency)}',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 16),
                                );
                              },
                            ),
                            if (lastExpense != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Icon(Icons.receipt_long, size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    fit: FlexFit.loose,
                                    child: Text(
                                      'Last expense: "${lastExpense.description}"',
                                      style: const TextStyle(fontSize: 14, color: Colors.grey),
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
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF179D8B)),
                                      ),
                                    ],
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
  // Helper para obtener el share del usuario en un gasto
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
              child: const Text('Cancel'),
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
                            setState(() { uploading = false; uploadError = 'Error uploading image'; });
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
                          await FirebaseAnalytics.instance.logEvent(
                            name: 'join_group',
                            parameters: {
                              'group_id': group.id,
                              'group_name': group.name,
                              'method': 'manual',
                            },
                          );
                          Navigator.pop(dialogContext);
                        } catch (e) {
                          setState(() {
                            errorMsg = e.toString().contains('permission-denied')
                              ? 'You do not have permission to create the group. Check your Firestore rules.'
                              : 'Error creating group: ${e.toString()}';
                          });
                        }
                      },
                child: const Text('Create'),
              ),
            ),
          ],
        ),
      );
    },
  );
}
