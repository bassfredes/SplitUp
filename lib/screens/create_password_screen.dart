import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/constants.dart';
import '../widgets/header.dart';
import '../widgets/app_footer.dart';

class CreatePasswordScreen extends StatefulWidget {
  const CreatePasswordScreen({super.key});

  @override
  State<CreatePasswordScreen> createState() => _CreatePasswordScreenState();
}

class _CreatePasswordScreenState extends State<CreatePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _repeatController = TextEditingController();
  double _passwordStrength = 0;
  String _passwordStrengthLabel = '';
  bool _loading = false;
  String? _error;

  void _checkPasswordStrength(String password) {
    int score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'\\d').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$&*~]').hasMatch(password)) score++;
    setState(() {
      _passwordStrength = score / 5.0;
      if (score <= 2) {
        _passwordStrengthLabel = 'Weak';
      } else if (score == 3) {
        _passwordStrengthLabel = 'Medium';
      } else if (score == 4) {
        _passwordStrengthLabel = 'Strong';
      } else {
        _passwordStrengthLabel = 'Very strong';
      }
    });
  }

  Future<void> _createPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _error = null; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email;
      final password = _passwordController.text.trim();
      if (user != null && email != null) {
        final cred = EmailAuthProvider.credential(email: email, password: password);
        await user.linkWithCredential(cred);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password created successfully')));
        Navigator.pop(context);
      }
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
      backgroundColor: const Color(0xFFF6F8FA),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              Header(
                currentRoute: '/account',
                onDashboard: () => Navigator.pushReplacementNamed(context, '/dashboard'),
                onGroups: () => Navigator.pushReplacementNamed(context, '/groups'),
                onAccount: () => Navigator.pushReplacementNamed(context, '/account'),
                onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
              ),
              Container(
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
                      const Text('Create password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(labelText: 'New password'),
                        obscureText: true,
                        onChanged: _checkPasswordStrength,
                        validator: (value) {
                          if (value == null || value.length < 8) return 'Minimum 8 characters';
                          if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Must contain uppercase letter';
                          if (!RegExp(r'[a-z]').hasMatch(value)) return 'Must contain lowercase letter';
                          if (!RegExp(r'\\d').hasMatch(value)) return 'Must contain number';
                          if (!RegExp(r'[!@#\$&*~]').hasMatch(value)) return 'Must contain special character';
                          return null;
                        },
                        enabled: !_loading,
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _passwordStrength,
                        backgroundColor: Colors.grey[200],
                        color: _passwordStrength < 0.4
                            ? Colors.red
                            : _passwordStrength < 0.7
                                ? Colors.orange
                                : Colors.green,
                        minHeight: 6,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Text('Strength: $_passwordStrengthLabel', style: const TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _repeatController,
                        decoration: const InputDecoration(labelText: 'Repeat password'),
                        obscureText: true,
                        validator: (value) => value == _passwordController.text ? null : 'Passwords do not match',
                        enabled: !_loading,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loading ? null : _createPassword,
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
              const AppFooter(),
            ],
          ),
        ),
      ),
    );
  }
}
