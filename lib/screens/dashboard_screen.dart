import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../models/group_model.dart';
import '../models/expense_model.dart';
import '../models/user_model.dart';
import '../config/constants.dart';
import '../widgets/breadcrumb.dart';
import '../widgets/header.dart';
import '../utils/formatters.dart';
import '../screens/add_expense_screen.dart';

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
    // Escuchar cambios en el provider para recargar balances automáticamente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      groupProvider.addListener(_onGroupsChanged);
    });
  }

  @override
  void dispose() {
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    groupProvider.removeListener(_onGroupsChanged);
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
        label: const Text('New group', style: TextStyle(color: Colors.white)),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  return Container(
                    width: isMobile ? double.infinity : MediaQuery.of(context).size.width * 0.95,
                    constraints: isMobile ? null : const BoxConstraints(maxWidth: 1200),
                    margin: EdgeInsets.only(top: isMobile ? 8 : 20, bottom: isMobile ? 8 : 20, left: isMobile ? 10 : 0, right: isMobile ? 10 : 0),
                    padding: EdgeInsets.all(isMobile ? 0 : 40),
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
                      padding: const EdgeInsets.all(18), // Espacio interior extra
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Breadcrumb(
                            items: [
                              BreadcrumbItem('Home'),
                              BreadcrumbItem('Dashboard'),
                            ],
                            onTap: (i) {
                              if (i == 0) Navigator.pushReplacementNamed(context, '/dashboard');
                            },
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: isMobile ? 20 : 28,
                                backgroundColor: kPrimaryColor,
                                backgroundImage: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                                    ? NetworkImage(user.photoUrl!)
                                    : null,
                                child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                                    ? Text(
                                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                        style: TextStyle(fontSize: isMobile ? 18 : 28, color: Colors.white),
                                      )
                                    : null,
                              ),
                              SizedBox(width: isMobile ? 10 : 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.name,
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: isMobile ? 18 : null),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      user.email,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700], fontSize: isMobile ? 13 : null),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isMobile ? 18 : 32),
                          // --- BALANCE SUMMARY ---
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
                                  child: Text('Error loading balances', style: TextStyle(color: Colors.red[700])),
                                );
                              }
                              return _buildBalanceSummary(snapshot.data ?? {});
                            },
                          ),
                          // --- END BALANCE SUMMARY ---
                          Text(
                            'Your groups',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: kPrimaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 26,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Here you can view and manage all your shared expense groups.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 16),
                          if (groupProvider.loading)
                            const Center(child: CircularProgressIndicator())
                          else if (groupProvider.groups.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Text(
                                'You have no groups yet. Create a new one!',
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
                  );
                },
              ),
            ),
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

  void _openAddExpense(BuildContext context, List<UserModel> participants, String currency) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddExpenseScreen(
          groupId: widget.group.id,
          participants: participants,
          currentUserId: widget.currentUserId,
          groupCurrency: currency,
          groupName: widget.group.name,
        ),
      ),
    );
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
            margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: const Padding(padding: EdgeInsets.all(24), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final participantsMap = snapshot.data!['participants'] as Map<String, UserModel>;
        final ExpenseModel? lastExpense = snapshot.data!['lastExpense'];
        final participants = participantsMap.values.toList();
        final group = widget.group;
        final currency = group.currency;

        Widget cardContent = Card(
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
                  // Photo or placeholder
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
                  // Main info and balance + last expense aligned
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
                                  // My balance in a single line
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
                                          final paid = exp.payers.where((p) => p['userId'] == widget.currentUserId).fold<double>(0, (a, b) => a + (b['amount'] as num).toDouble());
                                          final isParticipant = exp.participantIds.contains(widget.currentUserId);
                                          final share = isParticipant
                                              ? (exp.splitType == 'equal' ? exp.amount / exp.participantIds.length : _getUserShare(exp, widget.currentUserId))
                                              : 0;
                                          balance += paid - share;
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
                                      String balanceStr = formatCurrency(balance, currency); // Use formatCurrency
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Text(
                                          'My balance: $balanceStr',
                                          style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 16),
                                        ),
                                      );
                                    },
                                  ),
                                  // Último gasto (diferente para mobile y desktop)
                                  if (lastExpense != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4.0),
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final isMobile = constraints.maxWidth < 600;
                                          if (isMobile) {
                                            // MOBILE: líneas separadas
                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.receipt_long, size: 16, color: Colors.grey),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        'Last expense: "${lastExpense.description}"',
                                                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      formatCurrency(lastExpense.amount, lastExpense.currency),
                                                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Colors.grey),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.person, size: 15, color: Colors.grey),
                                                    const SizedBox(width: 4),
                                                    if (participantsMap[lastExpense.createdBy]?.name != null)
                                                      Text('by ${participantsMap[lastExpense.createdBy]?.name}', style: const TextStyle(fontSize: 13, color: Colors.grey))
                                                    else if (lastExpense.createdBy.isNotEmpty)
                                                      FutureBuilder<DocumentSnapshot>(
                                                        future: FirebaseFirestore.instance.collection('users').doc(lastExpense.createdBy).get(),
                                                        builder: (context, userSnap) {
                                                          String name = 'Someone';
                                                          if (userSnap.connectionState == ConnectionState.done && userSnap.hasData && userSnap.data!.exists) {
                                                            final data = userSnap.data!.data() as Map<String, dynamic>;
                                                            name = data['name'] ?? 'Someone';
                                                          } else if (userSnap.connectionState == ConnectionState.waiting) {
                                                            name = '...';
                                                          }
                                                          return Text('by $name', style: const TextStyle(fontSize: 13, color: Colors.grey));
                                                        },
                                                      )
                                                    else
                                                      const Text('by Someone', style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                                            );
                                          } else {
                                            // DESKTOP/WEB: cada dato en su línea, como antes
                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.receipt_long, size: 16, color: Colors.grey),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        'Last expense: "${lastExpense.description}"',
                                                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      formatCurrency(lastExpense.amount, lastExpense.currency),
                                                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Colors.grey),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.person, size: 15, color: Colors.grey),
                                                    const SizedBox(width: 4),
                                                    if (participantsMap[lastExpense.createdBy]?.name != null)
                                                      Text('by ${participantsMap[lastExpense.createdBy]?.name}', style: const TextStyle(fontSize: 13, color: Colors.grey))
                                                    else if (lastExpense.createdBy.isNotEmpty)
                                                      FutureBuilder<DocumentSnapshot>(
                                                        future: FirebaseFirestore.instance.collection('users').doc(lastExpense.createdBy).get(),
                                                        builder: (context, userSnap) {
                                                          String name = 'Someone';
                                                          if (userSnap.connectionState == ConnectionState.done && userSnap.hasData && userSnap.data!.exists) {
                                                            final data = userSnap.data!.data() as Map<String, dynamic>;
                                                            name = data['name'] ?? 'Someone';
                                                          } else if (userSnap.connectionState == ConnectionState.waiting) {
                                                            name = '...';
                                                          }
                                                          return Text('by $name', style: const TextStyle(fontSize: 13, color: Colors.grey));
                                                        },
                                                      )
                                                    else
                                                      const Text('by Someone', style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                                            );
                                          }
                                        },
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

        // --- WEB/DESKTOP: Mostrar botón flotante en hover ---
        if (kIsWeb || Theme.of(context).platform == TargetPlatform.macOS || Theme.of(context).platform == TargetPlatform.windows || Theme.of(context).platform == TargetPlatform.linux) {
          return MouseRegion(
            onEnter: (_) => setState(() => _hovering = true),
            onExit: (_) => setState(() => _hovering = false),
            child: Stack(
              children: [
                cardContent,
                if (_hovering)
                  Positioned(
                    bottom: 24,
                    right: 24,
                    child: FloatingActionButton(
                      heroTag: 'add_expense_${group.id}',
                      backgroundColor: kPrimaryColor,
                      mini: true,
                      onPressed: () => _openAddExpense(context, participants, currency),
                      child: const Icon(Icons.add, color: Colors.white),
                      shape: const CircleBorder(),
                      elevation: 4,
                    ),
                  ),
              ],
            ),
          );
        }
        // --- MOBILE: Mostrar botón al deslizar (por detrás) ---
        return Dismissible(
          key: ValueKey('group_card_${group.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 32),
            child: FloatingActionButton(
              heroTag: 'add_expense_${group.id}',
              backgroundColor: kPrimaryColor,
              mini: true,
              onPressed: () => _openAddExpense(context, participants, currency),
              child: const Icon(Icons.add, color: Colors.white),
              shape: const CircleBorder(),
              elevation: 4,
            ),
          ),
          confirmDismiss: (_) async {
            _openAddExpense(context, participants, currency);
            return false; // No eliminar la tarjeta
          },
          child: cardContent,
        );
      },
    );
  }

  // Helper to get the user's share in an expense
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
