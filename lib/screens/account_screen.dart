import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../providers/auth_provider.dart';
import '../config/constants.dart';
import '../widgets/header.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: Header(
        currentRoute: '/account',
        onDashboard: () => Navigator.pushReplacementNamed(context, '/dashboard'),
        onGroups: () => Navigator.pushReplacementNamed(context, '/groups'),
        onAccount: () {},
        onLogout: () async {
          // Save the context before the async gap
          final navigator = Navigator.of(context);
          await authProvider.signOut();
          // Use the saved context
          navigator.pushReplacementNamed('/login');
        },
      ),
      backgroundColor: const Color(0xFFF6F8FA),
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            return Container(
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
              child: user == null
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.all(18), // Espacio interior extra
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 28, // Same as in dashboard
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
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(user.name, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(user.email, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit name'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryColor,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Navigator.pushNamed(context, '/account/edit_name'),
                          ),
                          const SizedBox(height: 12),
                          if (firebaseUser?.providerData.any((p) => p.providerId == 'password') ?? false)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.lock),
                              label: const Text('Change password'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimaryColor,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => Navigator.pushNamed(context, '/account/change_password'),
                            )
                          else
                            ElevatedButton.icon(
                              icon: const Icon(Icons.lock_open),
                              label: const Text('Create password'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimaryColor,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => Navigator.pushNamed(context, '/account/create_password'),
                            ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.account_circle),
                            label: Text((firebaseUser?.providerData.any((p) => p.providerId == 'google.com') ?? false)
                                ? 'Unlink Google'
                                : 'Link Google'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: kPrimaryColor,
                              side: const BorderSide(color: kPrimaryColor),
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Navigator.pushNamed(context, '/account/link_google'),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.account_circle),
                            label: Text((firebaseUser?.providerData.any((p) => p.providerId == 'github.com') ?? false)
                                ? 'Unlink GitHub'
                                : 'Link GitHub'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              side: const BorderSide(color: Colors.black),
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              if (firebaseUser?.providerData.any((p) => p.providerId == 'github.com') ?? false) {
                                await authProvider.unlinkGitHub();
                              } else {
                                await authProvider.linkWithGitHub();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }
}
