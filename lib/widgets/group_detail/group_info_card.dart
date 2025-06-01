import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/group_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../dialogs/edit_group_dialog.dart'; // Necesario para showEditGroupDialog

typedef OnParticipantsLoaded = void Function();
typedef OnParticipantRemoved = void Function(); // Callback para cuando un participante es removido y se necesita recargar

class GroupInfoCard extends StatelessWidget {
  final GroupModel group;
  final Future<List<UserModel>>? participantsFuture;
  final bool participantsLoading;
  final VoidCallback onEditGroupParticipantsLoaded; // Para recargar participantes después de editar
  final OnParticipantRemoved onParticipantRemoved; // Para recargar participantes después de remover

  const GroupInfoCard({
    super.key,
    required this.group,
    required this.participantsFuture,
    required this.participantsLoading,
    required this.onEditGroupParticipantsLoaded,
    required this.onParticipantRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bool isAdmin = group.adminId == authProvider.user?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                overflow: TextOverflow.ellipsis,
              ),
            ),
            FutureBuilder<List<UserModel>>(
              future: participantsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting || participantsLoading) {
                  return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5));
                }
                if (snapshot.hasError) {
                  return const Icon(Icons.error_outline, color: Colors.red, size: 24);
                }
                final users = snapshot.data ?? [];
                // Solo el admin puede editar el grupo
                if (isAdmin) {
                  return IconButton(
                    icon: const Icon(Icons.edit, color: Colors.teal),
                    tooltip: 'Edit group',
                    onPressed: () => showEditGroupDialog(context, group, users, onEditGroupParticipantsLoaded),
                  );
                }
                return const SizedBox.shrink(); // No mostrar botón si no es admin
              },
            ),
          ],
        ),
        if (group.description != null && group.description!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(group.description!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
        ],
        const SizedBox(height: 24),
        Text('Participants:', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        FutureBuilder<List<UserModel>>(
          future: participantsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting || participantsLoading) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ));
            }
            if (snapshot.hasError) {
              debugPrint("Error loading participants in GroupInfoCard: ${snapshot.error}");
              return const Text('Error loading participants.', style: TextStyle(color: Colors.red));
            }
            final users = snapshot.data ?? [];
            if (users.isEmpty) {
              return const Text('No participants in this group yet.');
            }
            return Wrap(
              spacing: 8,
              runSpacing: 6,
              children: users.map((user) {
                bool canDelete = isAdmin && user.id != group.adminId; // Admin no se puede auto-eliminar
                return Chip(
                  avatar: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                      ? CircleAvatar(backgroundImage: NetworkImage(user.photoUrl!))
                      : CircleAvatar(
                          backgroundColor: Colors.teal[100],
                          child: Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                            style: TextStyle(color: Colors.teal[800], fontWeight: FontWeight.bold),
                          ),
                        ),
                  label: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  onDeleted: canDelete ? () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Remove Participant'),
                        content: Text('Are you sure you want to remove ${user.name} from the group? Their outstanding debts will be redistributed among the remaining participants.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      // No es necesario setState(() => _participantsLoading = true); aquí, se maneja en la pantalla principal
                      try {
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        final currentUserId = authProvider.user?.id;
                        if (currentUserId == null) {
                          throw Exception("User not authenticated");
                        }
                        await Provider.of<GroupProvider>(context, listen: false)
                            .removeParticipantFromGroup(group.id, user.id, currentUserId);

                        // La actualización de Firestore para participantIds y roles AHORA se maneja DENTRO de FirestoreService.removeParticipantFromGroup.
                        // Por lo tanto, las siguientes líneas que actualizan Firestore directamente aquí son redundantes y pueden ser eliminadas.
                        // final groupRef = FirebaseFirestore.instance.collection('groups').doc(group.id);
                        // final currentGroupDoc = await groupRef.get();
                        // final currentRoles = List<Map<String, dynamic>>.from(currentGroupDoc.data()?['roles'] ?? []);
                        
                        // await groupRef.update({
                        //   'participantIds': FieldValue.arrayRemove([user.id]),
                        //   'roles': currentRoles.where((r) => r['uid'] != user.id).toList(),
                        // });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${user.name} removed.')), // Mensaje actualizado ya que la redistribución es parte de la operación
                        );
                        onParticipantRemoved(); // Llama al callback para recargar
                      } catch (e) {
                         ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error removing participant: ${e.toString()}')),
                        );
                      }
                    }
                  } : null, // No mostrar el icono de eliminar si no se puede borrar
                  deleteIcon: canDelete ? const Icon(Icons.cancel, size: 18) : null,
                  deleteIconColor: Colors.red[700],
                  backgroundColor: Colors.grey[200],
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
