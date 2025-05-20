import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';

Future<UserModel?> showInviteParticipantDialog(BuildContext context) async {
  final emailController = TextEditingController();
  String? error;

  return await showDialog<UserModel>(
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
              onChanged: (_) {
                if (error != null) {
                  setStateInner(() => error = null);
                }
              },
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
            onPressed: () => Navigator.pop(contextInner, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) {
                setStateInner(() => error = 'Email cannot be empty.');
                return;
              }
              if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(email)) {
                setStateInner(() => error = 'Enter a valid email.');
                return;
              }

              final userSnap = await FirebaseFirestore.instance
                  .collection('users')
                  .where('email', isEqualTo: email)
                  .limit(1)
                  .get();

              if (userSnap.docs.isEmpty) {
                setStateInner(() => error = 'User not found with that email.');
                return;
              }

              final invitedUser = UserModel.fromMap(userSnap.docs.first.data(), userSnap.docs.first.id);
              Navigator.pop(contextInner, invitedUser);
            },
            child: const Text('Invite'),
          ),
        ],
      ),
    ),
  );
}
