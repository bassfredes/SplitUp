import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../widgets/edit_group_dialog.dart';
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
import '../widgets/category_spending_chart.dart';
import '../providers/expense_provider.dart';

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
          create: (_) => ExpenseProvider(null, [], {}), // Added create
          update: (context, groupProvider, previousExpenseProvider) => // Added update
              ExpenseProvider(
            groupProvider,
            groupProvider.groups,
            previousExpenseProvider?.expenses ?? {},
          ),
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
  // _balancesFuture is no longer strictly needed here if balances are primarily consumed from GroupProvider
  // However, if there's a separate aggregation logic for display, it might still be used.
  // For now, let's assume GroupProvider.userBalances is the primary source for _GroupCard.
  // The _loadBalances method as written seems to calculate overall balances per currency,
  // which might be for a summary header, not per group card.
  // I'll keep _loadBalances for now if it serves another purpose.
  late Future<Map<String, double>> _overallBalancesFuture;
  GroupProvider? _groupProvider;

  @override
  void initState() {
    super.initState();
    _overallBalancesFuture = _loadOverallBalances();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      _groupProvider = groupProvider; // Store instance
      groupProvider.addListener(_onGroupsChanged);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure _groupProvider is initialized if not done in initState's callback yet
    _groupProvider ??= Provider.of<GroupProvider>(context, listen: false);
  }

  @override
  void dispose() {
    _groupProvider?.removeListener(_onGroupsChanged);
    super.dispose();
  }

  void _onGroupsChanged() {
    if (mounted) { // Check if the widget is still in the tree
      setState(() {
        _overallBalancesFuture = _loadOverallBalances();
        // Potentially refresh other dependent states if necessary
      });
    }
  }

  Future<Map<String, double>> _loadOverallBalances() async {
    // This method calculates total balances across all groups for each currency.
    // It might be used for a summary display, not directly by _GroupCard.
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final groupProvider = Provider.of<GroupProvider>(context, listen: false); // Already have _groupProvider
    final user = authProvider.user!;
    final groups = groupProvider.groups;

    final Map<String, double> totalBalancesByCurrency = {};
    for (final group in groups) {
      // Assuming group.participantBalances is structured to provide balances per user per currency
      // The original code snippet for this part was:
      // for (final item in group.participantBalances) {
      //   if (item['userId'] == user.id && item['balances'] is Map) {
      //     final balances = item['balances'] as Map;
      //     balances.forEach((currency, value) {
      //       if (value is num) { totalBalancesByCurrency[currency] = (totalBalancesByCurrency[currency] ?? 0) + value.toDouble(); }
      //     });
      //   }
      // }
      // This structure depends on how `participantBalances` is defined in `GroupModel`.
      // For now, let's use the `groupProvider.userBalances[group.id]` which is simpler for per-group balance.
      // If `_loadOverallBalances` is for a different summary, its logic would need to be based on `GroupModel.participantBalances`.
      // Given the current task, this method might be less relevant if `GroupProvider.userBalances` is sufficient.
      // For simplicity, I'll assume it's for a general summary.
      // The provided snippet `if (value is num) {…}` was incomplete.
      // Let's assume a structure for group.participantBalances for this example:
      // group.participantBalances might be List<Map<String, dynamic>> where each map is {'userId': String, 'balances': Map<String, double>}
      // for (final balanceEntry in group.participantBalances) {…} // Commenting out incomplete loop
    }
    return totalBalancesByCurrency;
  }

  Widget _buildDashboardContent(
      String? selectedGroupId, UserModel user, GroupProvider groupProviderData, bool isMobile) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateGroupDialog(context, user.id),
        label: const Text('Crear Grupo'), // Added label
        icon: const Icon(Icons.add), // Added icon
      ),
      body: CustomScrollView( // Using CustomScrollView for more complex scroll effects if needed
        slivers: <Widget>[
          SliverAppBar(
            // Replace with your actual Header widget if it's an AppBar
            // For now, assuming Header is a custom widget placed in the body.
            // If Header is an AppBar, it should be outside CustomScrollView or configured as SliverAppBar
            title: const Text('Dashboard'), // Placeholder
            backgroundColor: const Color(0xFFF6F8FA),
            elevation: 0,
            pinned: true, // Example: make app bar pinned
            actions: [
              IconButton(
                icon: const Icon(Icons.account_circle),
                onPressed: () {
                  Navigator.pushNamed(context, '/account');
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Header(
                user: user, // Assuming Header takes a user
                // Add other necessary parameters for Header
                // onNavigate: (route) => Navigator.pushNamed(context, route), // Example
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Consumer<GroupProvider>(
              builder: (context, groupProvider, child) {
                if (groupProvider.loading && groupProvider.groups.isEmpty) {
                  return const Center(
                      child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ));
                }
                if (groupProvider.groups.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text('No groups yet. Tap "+" to create one!',
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: groupProvider.groups.length,
                  itemBuilder: (context, index) {
                    final group = groupProvider.groups[index];
                    return _GroupCard(
                      key: ValueKey(group.id), // Add key for better list performance
                      group: group,
                      currentUserId: user.id,
                      participants: groupProvider.participantsDetails,
                      userBalance: groupProvider.userBalances[group.id] ?? 0.0,
                      lastExpense: groupProvider.lastExpenses[group.id], // Ensure this line passes the last expense
                    );
                  },
                );
              },
            ),
          ),
          if (selectedGroupId != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 12 : 18),
                    child: CategorySpendingChart(groupId: selectedGroupId),
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: AppFooter()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user!;
    final groupProvider = Provider.of<GroupProvider>(context); // listen: true to rebuild on group changes

    final firstGroupId = groupProvider.groups.isNotEmpty
        ? groupProvider.groups.first.id
        : null;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return _buildDashboardContent(firstGroupId, user, groupProvider, isMobile);
  }
}

class _GroupCard extends StatefulWidget {
  final GroupModel group;
  final String currentUserId;
  final Map<String, UserModel> participants; // Should be participantsDetails from provider
  final double userBalance;
  final ExpenseModel? lastExpense; // Ensure this field is present

  const _GroupCard({
    required this.group,
    required this.currentUserId,
    required this.participants,
    required this.userBalance,
    this.lastExpense, // Ensure this parameter is present in the constructor
    super.key, // Ensure super.key is present
  });

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _hovering = false;

  // Any _fetchLastExpense() method and calls to it (e.g., in initState)
  // should be removed as the lastExpense is now passed as a parameter.
  // If an initState existed solely for calling _fetchLastExpense, it might be removed if not needed otherwise.
  // Example of what to remove if present:
  // @override
  // void initState() {
  //   super.initState();
  //   // _fetchLastExpense(); // Call to be removed
  // }

  // Future<void> _fetchLastExpense() async { /* old fetching logic */ } // Method to be removed

  @override
  Widget build(BuildContext context) {
    if (widget.group.id.isEmpty) {
      return const SizedBox.shrink();
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0), // Adjusted margin
        decoration: BoxDecoration(
          color: _hovering ? const Color(0xFFF2F7FA) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _hovering
                  ? const Color(0xFF179D8B)
                  : const Color(0xFFE6E6E6),
              width: 1.5),
          boxShadow: _hovering
              ? [
                  BoxShadow(
                      color: Colors.teal.withOpacity(0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 4))
                ]
              : [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.pushNamed(context, '/group/${widget.group.id}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.teal[100],
                    backgroundImage: (widget.group.photoUrl != null &&
                            widget.group.photoUrl!.isNotEmpty)
                        ? NetworkImage(widget.group.photoUrl!)
                        : null,
                    child: (widget.group.photoUrl == null ||
                            widget.group.photoUrl!.isEmpty)
                        ? const Icon(Icons.group, size: 32, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.group.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Group actions',
                              color: Colors.white,
                              elevation: 8,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              offset: const Offset(0, 36),
                              icon: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF179D8B)
                                      .withOpacity(_hovering ? 0.18 : 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.more_vert,
                                  size: 24,
                                  color: _hovering
                                      ? const Color(0xFF179D8B)
                                      : Colors.grey[700],
                                ),
                              ),
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  // Use widget.participants which should be the detailed map
                                  final participantsList = widget.participants.values.toList();
                                  await showEditGroupDialog(context, widget.group, participantsList);
                                } else if (value == 'delete') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete group'),
                                      content: const Text(
                                          'Are you sure you want to delete this group? This action cannot be undone.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.delete_outline,
                                              color: Colors.white),
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white),
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          label: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                    final user = authProvider.user;
                                    if (user != null) {
                                      // Ensure GroupProvider is available
                                      try {
                                        await Provider.of<GroupProvider>(context, listen: false)
                                            .deleteGroup(widget.group.id, user.id);
                                        if (mounted) {
                                          // Consider a less disruptive refresh or feedback
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('${widget.group.name} deleted.'))
                                          );
                                          // No need to pushNamedAndRemoveUntil if GroupProvider updates will refresh the list
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
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                    leading: Icon(Icons.edit,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                    title: const Text('Edit group'),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: const Icon(Icons.delete_outline,
                                        color: Color(0xFFE14B4B)),
                                    title: const Text('Delete group',
                                        style:
                                            TextStyle(color: Color(0xFFE14B4B))),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Directly use widget.userBalance
                        Builder(builder: (context) {
                          final bal = widget.userBalance;
                          final color = bal < -0.01
                              ? const Color(0xFFE14B4B)
                              : (bal > 0.01
                                  ? const Color(0xFF1BC47D)
                                  : Colors.grey[700]);
                          return Text(
                            'My balance: ${formatCurrency(bal, widget.group.currency)}',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: color,
                                fontSize: 16),
                          );
                        }),
                        if (widget.lastExpense != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(Icons.receipt_long,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Flexible(
                                fit: FlexFit.loose,
                                child: Text(
                                  'Last: "${widget.lastExpense!.description}"', // Simplified
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formatCurrency(widget.lastExpense!.amount,
                                    widget.lastExpense!.currency),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Color(0xFF179D8B)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 15, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                formatDateShort(widget.lastExpense!.date),
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.grey),
                              ),
                            ],
                          ),
                        ] else ...[
                           const SizedBox(height: 4),
                           const Text(
                            'No expenses yet.',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
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
  }
}

void _showCreateGroupDialog(BuildContext context, String userId) {
  final groupProvider = Provider.of<GroupProvider>(context, listen: false);
  final nameController = TextEditingController();
  final descController = TextEditingController(); // Description for the group
  String currency = 'USD'; // Default currency
  final currencies = [ // Ensure kCurrencies or a similar list is available
    {'code': 'USD', 'label': 'USD', 'icon': '🇺🇸'},
    {'code': 'EUR', 'label': 'EUR', 'icon': '🇪🇺'},
    {'code': 'GBP', 'label': 'GBP', 'icon': '🇬🇧'},
    {'code': 'JPY', 'label': 'JPY', 'icon': '🇯🇵'},
    {'code': 'CAD', 'label': 'CAD', 'icon': '🇨🇦'},
    {'code': 'AUD', 'label': 'AUD', 'icon': '🇦🇺'},
    {'code': 'CLP', 'label': 'CLP', 'icon': '🇨🇱'},
    // Add more currencies as needed
  ];
  XFile? pickedImage; // Use XFile for ImagePicker result
  final ImagePicker picker = ImagePicker();
  bool uploading = false;
  String? uploadError;
  String? formErrorMsg; // For form validation errors

  showDialog(
    context: context,
    useRootNavigator: false, // Good practice for dialogs within specific navigators
    builder: (dialogContext) { // Use dialogContext for clarity
      return StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Create New Group'),
          content: SingleChildScrollView( // Ensure content is scrollable
            child: SizedBox( // Use SizedBox to constrain width if needed, or rely on AlertDialog's sizing
              width: MediaQuery.of(context).size.width * 0.8, // Example width
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (formErrorMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(formErrorMsg!, style: const TextStyle(color: Colors.red)),
                    ),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Group Name',
                      hintText: 'e.g., Trip to Alps',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'e.g., Expenses for our skiing trip',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: currency,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      border: OutlineInputBorder(),
                    ),
                    items: currencies
                        .map((c) => DropdownMenuItem(
                              value: c['code']!,
                              child: Text('${c['icon']} ${c['label']}'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setStateDialog(() => currency = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: pickedImage == null
                            ? const Text('No image selected.')
                            : Text(pickedImage!.name, overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        icon: const Icon(Icons.photo_camera),
                        onPressed: () async {
                          final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                          if (image != null) {
                            setStateDialog(() {
                              pickedImage = image;
                              uploadError = null;
                            });
                          }
                        },
                        tooltip: 'Pick group image',
                      ),
                    ],
                  ),
                  if (uploading) const LinearProgressIndicator(),
                  if (uploadError != null)
                    Text(uploadError!, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: const Text('Create Group', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
              onPressed: uploading ? null : () async {
                if (nameController.text.isEmpty) {
                  setStateDialog(() => formErrorMsg = 'Group name cannot be empty.');
                  return;
                }
                setStateDialog(() {
                  uploading = true;
                  uploadError = null;
                  formErrorMsg = null;
                });

                String? photoUrl;
                if (pickedImage != null) {
                  try {
                    final ref = FirebaseStorage.instance
                        .ref()
                        .child('group_photos')
                        .child('${DateTime.now().toIso8601String()}_${pickedImage!.name}');
                    final uploadTask = await ref.putFile(File(pickedImage!.path));
                    photoUrl = await uploadTask.ref.getDownloadURL();
                  } catch (e) {
                    setStateDialog(() {
                      uploadError = 'Failed to upload image: $e';
                      uploading = false;
                    });
                    return; // Stop if image upload fails
                  }
                }

                final newGroup = GroupModel(
                  id: FirebaseFirestore.instance.collection('groups').doc().id, // Generate ID client-side
                  name: nameController.text,
                  description: descController.text,
                  currency: currency,
                  participantIds: [userId], // Creator is the first participant
                  adminIds: [userId], // Creator is the first admin
                  createdAt: Timestamp.now(),
                  photoUrl: photoUrl,
                  // Initialize other fields as necessary
                  participantBalances: [{'userId': userId, 'balances': {currency: 0.0}}], // Initial balance for creator
                  categorySpending: {},
                  defaultSplitType: 'equal',
                );

                try {
                  await groupProvider.createGroup(newGroup, userId);
                  if (Navigator.canPop(dialogContext)) {
                     Navigator.pop(dialogContext);
                  }
                  FirebaseAnalytics.instance.logEvent(name: 'create_group', parameters: {'group_id': newGroup.id, 'currency': currency});
                } catch (e) {
                   setStateDialog(() {
                      uploadError = 'Failed to create group: $e';
                      uploading = false;
                   });
                } finally {
                  // Ensure uploading is set to false if it hasn't been by an error return
                  if (uploading) { // Check if still true
                     setStateDialog(() => uploading = false);
                  }
                }
              },
            ),
          ],
        ),
      );
    },
  );
}
