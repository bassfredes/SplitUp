import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../models/group_model.dart';
import '../config/constants.dart';
import '../widgets/breadcrumb.dart';
import '../widgets/header.dart';

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

class _DashboardContent extends StatelessWidget {
  const _DashboardContent();

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
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: const Icon(Icons.group, color: kPrimaryColor),
                            title: Text(g.name),
                            subtitle: g.description != null && g.description!.isNotEmpty ? Text(g.description!) : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'delete') {
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
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text('Eliminar'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true && context.mounted) {
                                        final user = Provider.of<AuthProvider>(context, listen: false).user!;
                                        await Provider.of<GroupProvider>(context, listen: false).deleteGroup(g.id, user.id);
                                      }
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Eliminar grupo'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/group/${g.id}',
                              );
                            },
                          ),
                        );
                      },
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
  final descController = TextEditingController();
  String currency = 'CLP';
  final currencies = [
    {'code': 'CLP', 'label': 'CLP', 'icon': '🇨🇱'},
    {'code': 'USD', 'label': 'USD', 'icon': '🇺🇸'},
    {'code': 'EUR', 'label': 'EUR', 'icon': '🇪🇺'},
  ];
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();
  bool _uploading = false;
  String? _uploadError;
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
                      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        setState(() => _imagePath = image.path);
                      }
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        shape: BoxShape.circle,
                        image: _imagePath != null
                            ? DecorationImage(image: FileImage(File(_imagePath!)), fit: BoxFit.cover)
                            : null,
                      ),
                      child: _imagePath == null
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
            Builder(
              builder: (dialogContext) => ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, foregroundColor: Colors.white),
                onPressed: _uploading
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;
                        String? photoUrl;
                        if (_imagePath != null) {
                          setState(() { _uploading = true; _uploadError = null; });
                          try {
                            final ref = FirebaseStorage.instance.ref().child('group_photos/${DateTime.now().millisecondsSinceEpoch}.jpg');
                            final uploadTask = await ref.putFile(File(_imagePath!));
                            photoUrl = await ref.getDownloadURL();
                          } catch (e) {
                            setState(() { _uploading = false; _uploadError = 'Error al subir la imagen'; });
                            return;
                          }
                          setState(() { _uploading = false; });
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
