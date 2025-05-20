import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:io';
import '../models/group_model.dart';
import '../models/user_model.dart';
import '../config/constants.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

Future<void> showEditGroupDialog(BuildContext context, GroupModel group, List<UserModel> initialParticipants) async {
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

  Future<DecorationImage?> loadGroupImageFuture(String? imagePath, String? photoUrl) async {
    if (imagePath != null) {
      if (kIsWeb) {
        final bytes = await XFile(imagePath).readAsBytes();
        return DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover);
      } else {
        return DecorationImage(image: FileImage(File(imagePath)), fit: BoxFit.cover);
      }
    } else if (photoUrl?.isNotEmpty == true) {
      return DecorationImage(image: NetworkImage(photoUrl!), fit: BoxFit.cover);
    }
    return null;
  }

  Future<DecorationImage?>? imageFuture = loadGroupImageFuture(imagePath, photoUrl);
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          void updateImageFuture() {
            imageFuture = loadGroupImageFuture(imagePath, photoUrl);
          }
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 28, left: 28, right: 28, bottom: 0),
                    child: Column(
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
                                    updateImageFuture();
                                  });
                                }
                              },
                              child: FutureBuilder<DecorationImage?>(
                                future: imageFuture,
                                builder: (context, snapshot) {
                                  return Container(
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      shape: BoxShape.circle,
                                      image: snapshot.data,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: (imagePath == null && (photoUrl?.isEmpty != false))
                                        ? const Icon(Icons.group, color: Colors.white, size: 44)
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
                                  color: Colors.teal,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(6),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 22),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: nameController,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                          decoration: InputDecoration(
                            labelText: 'Group name',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: descController,
                          minLines: 1,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Description (optional)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Participants', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: participantIds
                              .map((id) => participantsMap[id])
                              .where((user) => user != null)
                              .cast<UserModel>()
                              .map((user) => Chip(
                                    avatar: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                                        ? CircleAvatar(backgroundImage: NetworkImage(user.photoUrl!))
                                        : CircleAvatar(child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?')),
                                    label: Text(user.name),
                                    deleteIcon: (user.id != group.adminId && participantIds.length > 1)
                                        ? const Icon(Icons.close, size: 18, color: Colors.red)
                                        : null,
                                    onDeleted: (user.id != group.adminId && participantIds.length > 1)
                                        ? () => setStateDialog(() => participantIds.remove(user.id))
                                        : null,
                                    backgroundColor: Colors.grey[100],
                                    labelStyle: const TextStyle(fontWeight: FontWeight.w500),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  if (uploadError != null) ...[
                    const SizedBox(height: 18),
                    Text(uploadError!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w500)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save, size: 20),
                          label: const Text('Save', style: TextStyle(fontWeight: FontWeight.w500)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: uploading
                              ? null
                              : () async {
                                  String? newPhotoUrl = photoUrl;
                                  if (imagePath != null) {
                                    setStateDialog(() { uploading = true; uploadError = null; });
                                    try {
                                      final ref = FirebaseStorage.instance.ref().child('group_photos/${DateTime.now().millisecondsSinceEpoch}.jpg');
                                      if (kIsWeb) {
                                        final bytes = await XFile(imagePath!).readAsBytes();
                                        await ref.putData(bytes);
                                      } else {
                                        await ref.putFile(File(imagePath!));
                                      }
                                      final url = await ref.getDownloadURL();
                                      newPhotoUrl = url;
                                    } catch (e) {
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
                                    'roles': FieldValue.arrayUnion(
                                      group.roles
                                          .where((r) => participantIds.contains(r['uid']))
                                          .toList(),
                                    ),
                                  });
                                  await FirebaseAnalytics.instance.logEvent(
                                    name: 'edit_group',
                                    parameters: {
                                      'group_id': group.id,
                                      'group_name': nameController.text.trim(),
                                    },
                                  );
                                  if (!context.mounted) return;
                                  Navigator.pop(context);
                                },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
