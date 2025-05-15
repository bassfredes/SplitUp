import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../providers/auth_provider.dart';
import '../config/constants.dart';
import '../widgets/header.dart';
import '../widgets/app_footer.dart';

class EditNameScreen extends StatefulWidget {
  const EditNameScreen({super.key});

  @override
  State<EditNameScreen> createState() => _EditNameScreenState();
}

class _EditNameScreenState extends State<EditNameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    _nameController.text = user?.name ?? '';
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _error = null; });
    try {
      // Actualiza el nombre directamente en Firebase Auth
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      await user?.updateDisplayName(_nameController.text.trim());
      // Si tienes un backend o Firestore, aquí también deberías actualizarlo
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nombre actualizado correctamente')));
      Navigator.pop(context);
    } catch (e) {
      setState(() { _error = 'Error: ${e.toString()}'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F8FA),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Header(
              currentRoute: '/account',
              onDashboard: () => Navigator.pushReplacementNamed(context, '/dashboard'),
              onGroups: () => Navigator.pushReplacementNamed(context, '/groups'),
              onAccount: () => Navigator.pushReplacementNamed(context, '/account'),
              onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
            ),
            Center(
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
                      const Text('Edit name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Full Name'),
                        validator: (v) => v != null && v.trim().isNotEmpty ? null : 'Please enter a valid name',
                        enabled: !_loading,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loading ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Changes'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const AppFooter(),
          ],
        ),
      ),
    );
  }
}
