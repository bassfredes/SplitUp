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
import '../screens/add_expense_screen.dart';
import '../utils/formatters.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../widgets/app_footer.dart';

class GroupDetailScreen extends StatefulWidget {
  final GroupModel group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  // Optimization: Future to load participants only once
  Future<List<UserModel>>? _participantsFuture;
  // Key to force the reconstruction of the FutureBuilder of participants if necessary
  final GlobalKey _participantsFutureBuilderKey = GlobalKey();

  // Variable to force manual reload if necessary (e.g. after inviting)
  // int _participantsReload = 0; // Replaced by the Future update
  bool _participantsLoading = false; // Remains to indicate loading during actions

  @override
  void initState() {
    super.initState();
    // Load participants when the state is initialized
    _loadParticipants();
  }

  void _loadParticipants() {
    // Use setState so that FutureBuilders react to the new Future
    setState(() {
      _participantsFuture = _fetchParticipantsByIds(widget.group.participantIds);
    });
  }

  Future<List<UserModel>> _fetchParticipantsByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    // Optimization: Limit the number of IDs in the 'whereIn' query if it is too large
    // Firestore has a limit (currently 30), but it is good practice to consider it.
    // Split into chunks if userIds.length > 30
    List<UserModel> allUsers = [];
    List<List<String>> chunks = [];
    for (var i = 0; i < userIds.length; i += 30) {
      chunks.add(userIds.sublist(i, i + 30 > userIds.length ? userIds.length : i + 30));
    }

    for (final chunk in chunks) {
      if (chunk.isEmpty) continue;
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      allUsers.addAll(usersSnap.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)));
    }

    // Sort users according to the original order of userIds
    allUsers.sort((a, b) => userIds.indexOf(a.id).compareTo(userIds.indexOf(b.id)));
    return allUsers;
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
    // No need to pre-load users here if we pass them
    // await FirebaseFirestore.instance
    //     .collection('users')
    //     .where(FieldPath.documentId, whereIn: expense.participantIds)
    //     .get();
    if (!context.mounted) return;
    Navigator.pushNamed(
      context,
      '/group/${expense.groupId}/expense/${expense.id}',
      arguments: {
        'groupName': groupName,
        'participantsMap': usersById, // Pass the user map
      },
    );
  }

  Widget _buildTotalsByCurrency(Map<String, double> totalsByCurrency) {
    if (totalsByCurrency.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Totals by currency:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...totalsByCurrency.entries.map((entry) => Text(
          '${formatCurrency(entry.value, entry.key)} ${entry.key}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        )),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _importExpensesFromCsv(List<UserModel> users) async {
    final group = widget.group;
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (result != null) {
      Map<String, dynamic> importResult;
      if (kIsWeb) {
        // Web: read from bytes
        final bytes = result.files.single.bytes;
        if (bytes == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read the CSV file.')),
          );
          return;
        }
        // Decode to String (UTF-8)
        String content = utf8.decode(bytes);
        // Remove BOM if it exists
        if (content.startsWith('\uFEFF')) content = content.substring(1);
        importResult = await ExportService().importExpensesFromCsvContentWithValidation(content, users, group.id);
      } else if (result.files.single.path != null) {
        final file = File(result.files.single.path!);
        importResult = await ExportService().importExpensesFromCsvWithValidation(file, users, group.id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read the CSV file.')),
        );
        return;
      }
      final List<ExpenseModel> expenses = importResult['expenses'];
      final List<String> errors = importResult['errors'];
      if (errors.isNotEmpty) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Import errors'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('The following errors were found:'),
                    const SizedBox(height: 8),
                    ...errors.map((e) => Text(e, style: const TextStyle(color: Colors.red, fontSize: 13))),
                    const SizedBox(height: 16),
                    if (expenses.isNotEmpty)
                      Text('Still, you can import ${expenses.length} valid expenses.'),
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
                  child: const Text('Import valid'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      } else if (expenses.isNotEmpty) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm import'),
            content: Text('Do you want to import ${expenses.length} expenses?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Import'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await _saveImportedExpenses(expenses);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid expense was imported.')),
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
    // Registrar evento de Analytics para importación de gastos
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
      SnackBar(content: Text('Import completed: ${expenses.length} expenses imported.')),
    );
  }

  void _showEditGroupDialog(GroupModel group, List<UserModel> initialParticipants) async {
    final nameController = TextEditingController(text: group.name);
    final descController = TextEditingController(text: group.description ?? '');
    String? imagePath;
    String? photoUrl = group.photoUrl;
    bool uploading = false;
    String? uploadError;
    List<String> participantIds = List<String>.from(group.participantIds);
    Map<String, UserModel> participantsMap = { for (var u in initialParticipants) u.id : u };
    final ImagePicker picker = ImagePicker();
    final groupRef = FirebaseFirestore.instance.collection('groups').doc(group.id);
    await showDialog(
      context: context,
      barrierDismissible: false, // Cannot close by clicking outside
      builder: (context) {
        // This is the setState we should use for the dialog content
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Edit group'),
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
                            final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                            if (image != null) {
                              final allowedExtensions = ['jpg', 'jpeg', 'png'];
                              final ext = image.name.split('.').last.toLowerCase();
                              final bytes = await image.length();
                              if (!allowedExtensions.contains(ext)) {
                                setStateDialog(() => uploadError = 'Only JPG or PNG images are allowed');
                                return;
                              }
                              if (bytes > 2 * 1024 * 1024) {
                                setStateDialog(() => uploadError = 'The image must not exceed 2MB');
                                return;
                              }
                              setStateDialog(() {
                                imagePath = image.path;
                                uploadError = null;
                              });
                            }
                          },
                          child: FutureBuilder<DecorationImage?>(
                            future: () async {
                              if (imagePath != null) {
                                if (kIsWeb) {
                                  final bytes = await XFile(imagePath!).readAsBytes();
                                  return DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover);
                                } else {
                                  return DecorationImage(image: FileImage(File(imagePath!)), fit: BoxFit.cover);
                                }
                              } else if (photoUrl?.isNotEmpty == true) {
                                return DecorationImage(image: NetworkImage(photoUrl!), fit: BoxFit.cover);
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
                                child: (imagePath == null && (photoUrl?.isEmpty != false))
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
                      decoration: const InputDecoration(labelText: 'Group name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Description (optional)'),
                    ),
                    const SizedBox(height: 16),
                    const Text('Participants', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    // No longer needs FutureBuilder here, uses participantsMap
                    StatefulBuilder(
                      builder: (context, setStateDialog) {
                        // Filter the map based on the current IDs
                        final currentDialogParticipants = participantIds
                            .map((id) => participantsMap[id])
                            .where((user) => user != null)
                            .cast<UserModel>() // Ensure the type
                            .toList();

                        return Column(
                          children: currentDialogParticipants.map((user) => ListTile(
                            leading: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                                ? CircleAvatar(backgroundImage: NetworkImage(user.photoUrl!))
                                : CircleAvatar(child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?')),
                            title: Text(user.name),
                            subtitle: Text(user.email),
                            trailing: (user.id != group.adminId && participantIds.length > 1)
                                ? IconButton(
                                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                                    onPressed: () {
                                      // Update the list of IDs and the dialog state
                                      setStateDialog(() => participantIds.remove(user.id));
                                    },
                                  )
                                : null,
                          )).toList(),
                        );
                      }
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add participant'),
                      onPressed: () async {
                        final emailController = TextEditingController();
                        String? error;
                        // We use a second StatefulBuilder for the internal add email dialog
                        // so that its state (error) does not affect the main dialog.
                        await showDialog(
                          context: context,
                          builder: (contextInner) => StatefulBuilder(
                            builder: (contextInner, setStateInner) => AlertDialog(
                              title: const Text('Invite participant'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                    controller: emailController,
                                    decoration: const InputDecoration(labelText: 'Participant email'),
                                  ),
                                  if (error != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(error!, style: const TextStyle(color: Colors.red)),
                                    ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(contextInner),
                                  child: const Text('Cancel'),
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
                                      // Update the internal dialog state
                                      setStateInner(() => error = 'User not found');
                                      return;
                                    }
                                    final userId = userSnap.docs.first.id;
                                    if (!participantIds.contains(userId)) {
                                      // Update the list of IDs and the MAIN dialog state
                                      setStateDialog(() => participantIds.add(userId));
                                      // Optionally, update the map if the user was not there
                                      if (!participantsMap.containsKey(userId)) {
                                        final newUser = UserModel.fromMap(userSnap.docs.first.data(), userId);
                                        setStateDialog(() => participantsMap[userId] = newUser);
                                      }
                                    }
                                    Navigator.pop(contextInner); // Close internal dialog
                                  },
                                  child: const Text('Invite'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
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
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, foregroundColor: Colors.white),
                onPressed: uploading
                    ? null
                    : () async {
                        String? newPhotoUrl = photoUrl;
                        if (imagePath != null) {
                          setStateDialog(() { uploading = true; uploadError = null; });
                          try {
                            debugPrint('[DEBUG] Uploading image: $imagePath');
                            final ref = FirebaseStorage.instance.ref().child('group_photos/${DateTime.now().millisecondsSinceEpoch}.jpg');
                            if (kIsWeb) {
                              final bytes = await XFile(imagePath!).readAsBytes();
                              await ref.putData(bytes);
                            } else {
                              await ref.putFile(File(imagePath!));
                            }
                            final url = await ref.getDownloadURL();
                            debugPrint('[DEBUG] Image uploaded successfully. URL: $url');
                            newPhotoUrl = url;
                          } catch (e, st) {
                            debugPrint('[ERROR] Error uploading image: $e');
                            debugPrint(st.toString());
                            setStateDialog(() { uploading = false; uploadError = 'Error uploading image'; });
                            return;
                          }
                          setStateDialog(() { uploading = false; });
                        }
                        await groupRef.update({
                          'name': nameController.text.trim(),
                          'description': descController.text.trim(),
                          'photoUrl': newPhotoUrl,
                          'participantIds': participantIds,
                        });
                        if (!mounted) return;
                        Navigator.pop(context);
                        setState(() {});
                        _loadParticipants();
                      },
                child: const Text('Save'),
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
    final user = authProvider.user;
    final ScrollController scrollController = ScrollController();
    return Container(
      width: double.infinity,
      color: const Color(0xFFF6F8FA),
      child: ScrollConfiguration(
        behavior: const ScrollBehavior(),
        child: SingleChildScrollView(
          controller: scrollController,
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                Header(
                  currentRoute: '/group_detail',
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
                          padding: const EdgeInsets.all(18),
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
                              // --- GROUP PHOTO AND EDIT BUTTON ---
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
                                  FutureBuilder<List<UserModel>>(
                                    future: _participantsFuture,
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting || _participantsLoading) {
                                        return const CircularProgressIndicator();
                                      }
                                      if (snapshot.hasError) {
                                        return const Icon(Icons.error, color: Colors.red);
                                      }
                                      final users = snapshot.data ?? [];
                                      return IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.teal),
                                        tooltip: 'Edit group',
                                        onPressed: () => _showEditGroupDialog(group, users),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              if (group.description != null && group.description!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(group.description!, style: Theme.of(context).textTheme.bodyMedium),
                              ],
                              const SizedBox(height: 24),
                              const Text('Participants:', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              FutureBuilder<List<UserModel>>(
                                // Use the state's Future
                                future: _participantsFuture,
                                // Use a key to allow reconstruction if _participantsFuture changes
                                key: _participantsFutureBuilderKey,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting || _participantsLoading) {
                                    return const Center(child: CircularProgressIndicator());
                                  }
                                  if (snapshot.hasError) {
                                    debugPrint("Error loading participants: ${snapshot.error}");
                                    return const Text('Error loading participants.', style: TextStyle(color: Colors.red));
                                  }
                                  final users = snapshot.data ?? [];
                                  if (users.isEmpty) {
                                    return const Text('No participants');
                                  }
                                  // Save participants to use them elsewhere if necessary
                                  // final List<UserModel> currentParticipants = users;
                                  return Wrap(
                                    spacing: 8,
                                    runSpacing: 4, // Add vertical space
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
                                              title: const Text('Remove participant'),
                                              content: Text('Are you sure you want to remove ${user.name}?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                                  onPressed: () => Navigator.pop(context, true),
                                                  child: const Text('Remove'),
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
                                            });
                                            _loadParticipants();
                                          }
                                        }
                                      },
                                    )).toList(),
                                  );
                                },
                              ),
                              const SizedBox(height: 32),
                              // --- ADD EXPENSE BUTTON (ABOVE THE LIST) ---
                              Align(
                                alignment: Alignment.centerRight,
                                child: FutureBuilder<List<UserModel>>(
                                  // Use the state's Future
                                  future: _participantsFuture,
                                  builder: (context, snapshot) {
                                    // Do not show button while loading or if there is an error
                                    if (snapshot.connectionState != ConnectionState.done || snapshot.hasError || !snapshot.hasData) {
                                       return ElevatedButton.icon(
                                          icon: const Icon(Icons.add),
                                          label: const Text('Add expense'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.grey, // Visually disabled
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: null, // Disabled
                                        );
                                    }
                                    final users = snapshot.data!;
                                    return ElevatedButton.icon(
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add expense'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kPrimaryColor,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () async {
                                        // We already have the users from snapshot.data
                                        if (users.isEmpty) {
                                          final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
                                          if (scaffoldMessenger != null) {
                                            scaffoldMessenger.showSnackBar(
                                              const SnackBar(content: Text('Could not load group participants.')),
                                            );
                                          }
                                          return;
                                        }
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => AddExpenseScreen(
                                              groupId: group.id,
                                              participants: users,
                                              currentUserId: Provider.of<AuthProvider>(context, listen: false).user!.id,
                                              groupCurrency: group.currency,
                                              groupName: group.name,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),
                              // --- LIST OF EXPENSES GROUPED BY DATE WITH PAGINATION ---
                              FutureBuilder<List<UserModel>>(
                                // Use the state's Future
                                future: _participantsFuture,
                                builder: (context, userSnapshot) {
                                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                                    return const Center(child: CircularProgressIndicator());
                                  }
                                   if (userSnapshot.hasError) {
                                    debugPrint("Error loading participants for expense list: ${userSnapshot.error}");
                                    return const Text('Error loading user data.', style: TextStyle(color: Colors.red));
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
                                        return const Text('No expenses recorded.');
                                      }
                                      // PAGINATION
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
                                          // Group by date (yyyy-MM-dd)
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
                                                        // Pass groupName and usersById to onTap
                                                        onTap: () => _showExpenseDetail(context, e, widget.group.name, usersById),
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
                              // --- BALANCE SUMMARY AND DEBT SIMPLIFICATION (with names) ---
                              FutureBuilder<List<UserModel>>(
                                // Use the state's Future
                                future: _participantsFuture,
                                builder: (context, userSnapshot) {
                                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                                    return const Center(child: CircularProgressIndicator());
                                  }
                                   if (userSnapshot.hasError) {
                                    debugPrint("Error loading participants for balances: ${userSnapshot.error}");
                                    return const Text('Error loading user data for balances.', style: TextStyle(color: Colors.red));
                                  }
                                  final users = userSnapshot.data ?? [];
                                  final idToName = {for (var u in users) u.id: u.name};
                                  // Get the current user's ID here to use it in the map
                                  final currentUserId = Provider.of<AuthProvider>(context, listen: false).user?.id ?? '';

                                  return StreamBuilder<List<ExpenseModel>>(
                                    stream: _getGroupExpenses(group.id),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return const Center(child: CircularProgressIndicator());
                                      }
                                      final expenses = snapshot.data ?? [];
                                      if (expenses.isEmpty) {
                                        return const Text('No expenses to calculate balances.');
                                      }
                                      // --- TOTALS BY CURRENCY SUMMARY ---
                                      final Map<String, double> totalsByCurrency = {};
                                      for (final e in expenses) {
                                        totalsByCurrency[e.currency] = (totalsByCurrency[e.currency] ?? 0) + e.amount;
                                      }
                                      // --- BALANCE AND DEBT SUMMARY BY CURRENCY ---
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
                                                Text('Balance summary ($currency):', style: const TextStyle(fontWeight: FontWeight.bold)),
                                                const SizedBox(height: 8),
                                                // --- Modification here to highlight current user --- 
                                                ...balances.entries.map((e) {
                                                  final bool isCurrentUser = e.key == currentUserId; // Check if it is the current user
                                                  final userName = idToName[e.key] ?? e.key;
                                                  final balanceText = '${e.value >= 0 ? "+" : "-"}${formatCurrency(e.value.abs(), currency)}';
                                                  final textColor = e.value > 0 ? Colors.green : (e.value < 0 ? Colors.red : Colors.black);

                                                  return Container( // Wrap in Container for possible background
                                                    color: isCurrentUser ? const Color.fromRGBO(0, 128, 128, 0.1) : null, // Subtle background if it is the current user
                                                    padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
                                                    child: Text(
                                                      '${isCurrentUser ? '$userName (You)' : userName}: $balanceText',
                                                      style: TextStyle(
                                                        color: textColor,
                                                        // Apply bold if it is the current user
                                                        fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                                                      ),
                                                    ),
                                                  );
                                                }),
                                                // --- End Modification ---
                                                const SizedBox(height: 8),
                                                Text('Who owes whom ($currency):', style: const TextStyle(fontWeight: FontWeight.bold)),
                                                const SizedBox(height: 8),
                                                if (transactions.isEmpty)
                                                  const Text('No pending debts.')
                                                else
                                                  ...transactions.map((t) => Text(
                                                    '${idToName[t['from']] ?? t['from']} owes '
                                                    '${formatCurrency(t['amount'], currency)} to '
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
                              // --- GROUP ACTIONS SECTION ---
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.person_add),
                                    label: const Text('Invite'),
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
                                      setState(() => _participantsLoading = false);
                                      if (result == true) {
                                        _loadParticipants(); // Reload the participant list
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              Divider(height: 1, thickness: 1, color: const Color(0xFFE0E0E0)),
                              const SizedBox(height: 24),
                              // --- EXPORT/IMPORT SECTION ---
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.file_download),
                                    label: const Text('Export CSV'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () async {
                                      final users = await _participantsFuture;
                                      if (users == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Waiting for participant data...')),
                                        );
                                        return;
                                      }
                                      final expensesSnap = await FirebaseFirestore.instance
                                          .collection('groups')
                                          .doc(group.id)
                                          .collection('expenses')
                                          .get();
                                      final expenses = expensesSnap.docs.map((doc) => ExpenseModel.fromMap(doc.data(), doc.id)).toList();
                                      final rows = [
                                        [
                                          'Description', 'Amount', 'Currency', 'Date', 'Payers (email:amount)', 'Participants (emails)', 'Category', 'Recurring', 'Locked'
                                        ],
                                        ...expenses.map((e) => [
                                          e.description,
                                          e.amount.toStringAsFixed(0),
                                          e.currency,
                                          e.date.toIso8601String(),
                                          e.payers.map((p) {
                                            final email = users.firstWhere((u) => u.id == p['userId'], orElse: () => UserModel(id: '', name: '', email: p['userId'], photoUrl: null)).email;
                                            final amount = (p['amount'] is double) ? (p['amount'] as double).toInt() : p['amount'];
                                            return '$email:$amount';
                                          }).join(';'),
                                          e.participantIds.map((id) => users.firstWhere((u) => u.id == id, orElse: () => UserModel(id: '', name: '', email: id, photoUrl: null)).email).join(';'),
                                          e.category ?? '',
                                          e.isRecurring ? 'Yes' : 'No',
                                          e.isLocked ? 'Yes' : 'No',
                                        ])
                                      ];
                                      final csv = const ListToCsvConverter().convert(rows);
                                      final bom = '\uFEFF';
                                      if (kIsWeb) {
                                        // Web: download using dart:html
                                        final bytes = utf8.encode(bom + csv);
                                        final blob = html.Blob([bytes], 'text/csv');
                                        final url = html.Url.createObjectUrlFromBlob(blob);
                                        html.AnchorElement(href: url)
                                          ..download = 'expenses_${group.name}_${DateTime.now().millisecondsSinceEpoch}.csv'
                                          ..click();
                                        html.Url.revokeObjectUrl(url);
                                      } else {
                                        // Desktop/mobile: save to disk
                                        final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
                                        final filePath = '${dir.path}/expenses_${group.name}_${DateTime.now().millisecondsSinceEpoch}.csv';
                                        final file = File(filePath);
                                        await file.writeAsString(bom + csv, encoding: utf8);
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('File exported: $filePath')),
                                        );
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.file_upload),
                                    label: const Text('Import CSV'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () async {
                                      final users = await _participantsFuture;
                                      if (users == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Waiting for participant data...')),
                                        );
                                        return;
                                      }
                                      await _importExpensesFromCsv(users);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.download, size: 18, color: Colors.blue),
                                  label: const Text(
                                    'Download example CSV',
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
                                        'Description', 'Amount', 'Currency', 'Date', 'Payers (email:amount)', 'Participants (emails)', 'Category', 'Recurring', 'Locked'
                                      ],
                                      [
                                        'Example expense',
                                        '10000',
                                        'CLP',
                                        '2025-04-27',
                                        'user1@example.com:10000',
                                        'user1@example.com;user2@example.com',
                                        'Food',
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
                                        ..download = 'expenses_example_import.csv'
                                        ..click();
                                      html.Url.revokeObjectUrl(url);
                                    } else {
                                      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
                                      final filePath = '${dir.path}/expenses_example_import.csv';
                                      // Use dummy emails in the example file
                                      await File(filePath).writeAsString('\uFEFF$csv', encoding: utf8);
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Example file saved at: $filePath')),
                                      );
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(height: 32),
                              Divider(height: 1, thickness: 1, color: const Color(0xFFE57373)),
                              const SizedBox(height: 40),
                              Center(
                                child: Column(
                                  children: [
                                    const Text(
                                      'Warning! This action is irreversible.',
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
                                            label: const Text('Delete group'),
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
                                                  title: const Text('Delete group'),
                                                  content: const Text('Are you sure you want to delete this group? This action cannot be undone.'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context, false),
                                                      child: const Text('Cancel'),
                                                    ),
                                                    ElevatedButton(
                                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                                      onPressed: () => Navigator.pop(context, true),
                                                      child: const Text('Delete'),
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
                                            label: const Text('Leave group'),
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
                                                  title: const Text('Leave group'),
                                                  content: const Text('Are you sure you want to leave this group?'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context, false),
                                                      child: const Text('Cancel'),
                                                    ),
                                                    ElevatedButton(
                                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                                                      onPressed: () => Navigator.pop(context, true),
                                                      child: const Text('Leave'),
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
                              const SizedBox(height: 32),
                              AppFooter(), // Add the AppFooter widget here
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
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
                      color: kPrimaryColor, // primary color of the project
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
      title: const Text('Invite participant'),
      content: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Participant email'),
                validator: (v) => v != null && v.contains('@') ? null : 'Invalid email',
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
          child: const Text('Cancel'),
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
                    // Search user by email
                    final userSnap = await FirebaseFirestore.instance
                        .collection('users')
                        .where('email', isEqualTo: email)
                        .limit(1)
                        .get();
                    if (userSnap.docs.isEmpty) {
                      if (!mounted) return;
                      setState(() {
                        _loading = false;
                        _error = 'User not found';
                      });
                      return;
                    }
                    final userId = userSnap.docs.first.id;
                    // Get current group document
                    final groupRef = FirebaseFirestore.instance.collection('groups').doc(widget.groupId);
                    final groupDoc = await groupRef.get();
                    if (!groupDoc.exists) {
                      setState(() {
                        _loading = false;
                        _error = 'Group does not exist';
                      });
                      return;
                    }
                    final data = groupDoc.data();
                    final List participantIds = List.from(data?['participantIds'] ?? []);
                    // Validate permissions before the update
                    if (currentUid == null) {
                      setState(() {
                        _loading = false;
                        _error = 'Not authenticated';
                      });
                      return;
                    }
                    if (!participantIds.contains(currentUid)) {
                      setState(() {
                        _loading = false;
                        _error = 'You do not have permission to invite in this group';
                      });
                      return;
                    }
                    // Add the new user if not already there
                    if (!participantIds.contains(userId)) {
                      participantIds.add(userId);
                    }
                    await groupRef.update({
                      'participantIds': participantIds,
                      'roles': FieldValue.arrayUnion([{ 'uid': userId, 'role': 'member' }]),
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
          child: const Text('Invite'),
        ),
      ],
    );
  }
}
