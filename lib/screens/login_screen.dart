import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:g_recaptcha_v3/g_recaptcha_v3.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (firebaseUser != null && firebaseUser.emailVerified) {
        Future.microtask(() => Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false));
      } else {
        Future.microtask(() => Navigator.pushNamedAndRemoveUntil(context, '/email_verification', (route) => false));
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar sesión'),
        backgroundColor: const Color(0xFF159d9e),
        elevation: 0,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
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
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: [
                    Icon(Icons.account_balance_wallet_rounded, size: 56, color: const Color(0xFF159d9e)),
                    const SizedBox(height: 12),
                    Text('Bienvenido a SplitUp',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (authProvider.loading)
                const Center(child: CircularProgressIndicator())
              else ...[
                const _EmailPasswordLoginForm(),
                const SizedBox(height: 24),
                Builder(
                  builder: (context) {
                    final formState = _EmailPasswordLoginForm.of(context);
                    final isRegister = formState?._isRegister ?? false;
                    if (isRegister) return const SizedBox.shrink();
                    return Column(
                      children: [
                        Row(
                          children: const [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text('o inicia con redes'),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.login),
                          label: const Text('Iniciar sesión con Google'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF159d9e),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => authProvider.signInWithGoogle(),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmailPasswordLoginForm extends StatefulWidget {
  const _EmailPasswordLoginForm({Key? key}) : super(key: key);

  @override
  _EmailPasswordLoginFormState createState() => _EmailPasswordLoginFormState();

  static _EmailPasswordLoginFormState? of(BuildContext context) {
    return context.findAncestorStateOfType<_EmailPasswordLoginFormState>();
  }
}

class _EmailPasswordLoginFormState extends State<_EmailPasswordLoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _repeatPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  String? _error;
  bool _isRegister = false;
  double _passwordStrength = 0;
  String _passwordStrengthLabel = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _repeatPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength(String password) {
    // Reglas: min 8, mayúscula, minúscula, número, especial
    int score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'\d').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$&*~]').hasMatch(password)) score++;
    setState(() {
      _passwordStrength = score / 5.0;
      if (score <= 2) {
        _passwordStrengthLabel = 'Débil';
      } else if (score == 3) {
        _passwordStrengthLabel = 'Media';
      } else if (score == 4) {
        _passwordStrengthLabel = 'Fuerte';
      } else {
        _passwordStrengthLabel = 'Muy fuerte';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isRegister) ...[
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nombre completo',
                prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF159d9e)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) => value != null && value.trim().isNotEmpty ? null : 'El nombre es obligatorio',
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF159d9e)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            validator: (value) => value != null && value.contains('@') ? null : 'Correo inválido',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF159d9e)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            obscureText: true,
            onChanged: _isRegister ? _checkPasswordStrength : null,
            validator: (value) {
              if (value == null || value.length < 8) return 'Mínimo 8 caracteres';
              if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Debe tener mayúscula';
              if (!RegExp(r'[a-z]').hasMatch(value)) return 'Debe tener minúscula';
              if (!RegExp(r'\d').hasMatch(value)) return 'Debe tener número';
              if (!RegExp(r'[!@#\$&*~]').hasMatch(value)) return 'Debe tener carácter especial';
              return null;
            },
          ),
          if (_isRegister) ...[
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
              child: Text('Fortaleza: $_passwordStrengthLabel', style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _repeatPasswordController,
              decoration: InputDecoration(
                labelText: 'Repetir contraseña',
                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF159d9e)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              obscureText: true,
              validator: (value) => value == _passwordController.text ? null : 'Las contraseñas no coinciden',
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState?.validate() ?? false) {
                setState(() => _error = null);
                String? error;
                if (_isRegister) {
                  if (kIsWeb) {
                    final recaptchaKey = '6LfW0yUrAAAAAI7QFs_2qoY7KEHTQvhzIkNnLL13';
                    String? token;
                    try {
                      await GRecaptchaV3.ready(recaptchaKey);
                      token = await GRecaptchaV3.execute(recaptchaKey);
                    } catch (e) {
                      setState(() => _error = 'Error al validar reCAPTCHA: $e');
                      return;
                    }
                    if (token == null || token.isEmpty) {
                      setState(() => _error = 'No se pudo validar reCAPTCHA.');
                      return;
                    }
                  } else {
                    setState(() => _error = 'La validación reCAPTCHA solo está disponible en la versión web.');
                    return;
                  }
                  // --- FIN reCAPTCHA ---
                  error = await authProvider.registerWithEmail(
                    _emailController.text,
                    _passwordController.text,
                    name: _nameController.text.trim(),
                  );
                } else {
                  error = await authProvider.signInWithEmail(_emailController.text, _passwordController.text);
                }
                if (error != null) {
                  setState(() => _error = error);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF159d9e),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_isRegister ? 'Registrarse' : 'Iniciar Sesión'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _isRegister = !_isRegister);
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF159d9e),
            ),
            child: Text(_isRegister ? '¿Ya tienes cuenta? Inicia sesión' : '¿No tienes cuenta? Regístrate'),
          ),
        ],
      ),
    );
  }
}
