import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/constants.dart';
import '../widgets/header.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _repeatController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _changePassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _error = null; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      final cred = EmailAuthProvider.credential(
        email: user!.email!,
        password: _currentController.text.trim(),
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_newController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully')));
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() { _error = e.message; });
    } catch (e) {
      setState(() { _error = 'Error: ${e.toString()}'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Header(
        currentRoute: '/account',
        onDashboard: () => Navigator.pushReplacementNamed(context, '/dashboard'),
        onGroups: () => Navigator.pushReplacementNamed(context, '/groups'),
        onAccount: () => Navigator.pushReplacementNamed(context, '/account'),
        onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
      ),
      backgroundColor: const Color(0xFFF6F8FA),
      body: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          constraints: const BoxConstraints(maxWidth: 400),
          margin: const EdgeInsets.only(top: 20, bottom: 20),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color.fromRGBO(0, 0, 0, 0.07),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Change password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _currentController,
                  decoration: const InputDecoration(labelText: 'Current password'),
                  obscureText: true,
                  validator: (v) => v != null && v.length >= 8 ? null : 'Minimum 8 characters',
                  enabled: !_loading,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newController,
                  decoration: const InputDecoration(labelText: 'New password'),
                  obscureText: true,
                  validator: (v) => v != null && v.length >= 8 ? null : 'Minimum 8 characters',
                  enabled: !_loading,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _repeatController,
                  decoration: const InputDecoration(labelText: 'Repeat new password'),
                  obscureText: true,
                  validator: (v) => v == _newController.text ? null : 'Passwords do not match',
                  enabled: !_loading,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
