import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:g_recaptcha_v3/g_recaptcha_v3.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../config/constants.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

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
      body: Center(
        child: SingleChildScrollView( 
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/icon/splitup-logo.png',
                        height: 100,
                      ),
                      const SizedBox(height: 12),
                      Text('Welcome to SplitUp',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                // Se elimina la condición authProvider.loading aquí
                const _EmailPasswordLoginForm(),
                const SizedBox(height: 24),
                Builder(
                    builder: (context) {
                      final formState = _EmailPasswordLoginForm.of(context);
                      final isRegister = formState?._isRegister ?? false;
                      if (isRegister) return const SizedBox.shrink();
                      return Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                side: const BorderSide(color: Color(0xFF747775)),
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                                padding: EdgeInsets.zero,
                                shadowColor: Colors.transparent,
                              ),
                              onPressed: () => authProvider.signInWithGoogle(),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    margin: const EdgeInsets.only(right: 12),
                                    child: SvgPicture.string(
                                      '''<svg version="1.1" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"></path><path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"></path><path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"></path><path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"></path><path fill="none" d="M0 0h48v48H0z"></path></svg>''',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const Text(
                                    'Sign in with Google',
                                    style: TextStyle(
                                      color: Color(0xFF1f1f1f),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                      fontFamily: 'Roboto',
                                      letterSpacing: 0.25,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                side: const BorderSide(color: Color(0xFF24292F)),
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                                padding: EdgeInsets.zero,
                                shadowColor: Colors.transparent,
                              ),
                              onPressed: () async {
                                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                final scaffoldMessenger = ScaffoldMessenger.of(context);
                                final error = await authProvider.signInWithGitHub();
                                if (error != null && error.isNotEmpty) {
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text(error, style: const TextStyle(color: Colors.white)),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    margin: const EdgeInsets.only(right: 12),
                                    child: SvgPicture.string(
                                      '''<svg width="98" height="96" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" clip-rule="evenodd" d="M48.854 0C21.839 0 0 22 0 49.217c0 21.756 13.993 40.172 33.405 46.69 2.427.49 3.316-1.059 3.316-2.362 0-1.141-.08-5.052-.08-9.127-13.59 2.934-16.42-5.867-16.42-5.867-2.184-5.704-5.42-7.17-5.42-7.17-4.448-3.015.324-3.015.324-3.015 4.934.326 7.523 5.052 7.523 5.052 4.367 7.496 11.404 5.378 14.235 4.074.404-3.178 1.699-5.378 3.074-6.6-10.839-1.141-22.243-5.378-22.243-24.283 0-5.378 1.94-9.778 5.014-13.2-.485-1.222-2.184-6.275.486-13.038 0 0 4.125-1.304 13.426 5.052a46.97 46.97 0 0 1 12.214-1.63c4.125 0 8.33.571 12.213 1.63 9.302-6.356 13.427-5.052 13.427-5.052 2.67 6.763.97 11.816.485 13.038 3.155 3.422 5.015 7.822 5.015 13.2 0 18.905-11.404 23.06-22.324 24.283 1.78 1.548 3.316 4.481 3.316 9.126 0 6.6-.08 11.897-.08 13.526 0 1.304.89 2.853 3.316 2.364 19.412-6.52 33.405-24.935 33.405-46.691C97.707 22 75.788 0 48.854 0z" fill="#24292f"/></svg>''',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const Text(
                                    'Sign in with GitHub',
                                    style: TextStyle(
                                      color: Color(0xFF24292F),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                      fontFamily: 'Roboto',
                                      letterSpacing: 0.25,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailPasswordLoginForm extends StatefulWidget {
  const _EmailPasswordLoginForm();

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
  // bool loading = false; // Ya no se usa para la UI de carga principal del formulario

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _repeatPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength(String password) {
    // Rules: min 8, uppercase, lowercase, number, special
    int score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'\d').hasMatch(password)) score++;
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

  Future<void> _showResetPasswordDialog() async {
    final emailController = TextEditingController(text: _emailController.text);
    await showDialog(
      context: context,
      builder: (context) {
        String? error;
        bool sent = false;
        bool loading = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Reset password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Enter your email and we will send you a link to reset your password.'),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error ?? 'Unknown error', style: const TextStyle(color: Colors.red)),
                ],
                if (sent) ...[
                  const SizedBox(height: 8),
                  Text('Email sent. Check your inbox.', style: TextStyle(color: Colors.green)),
                ]
              ],
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.red,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(sent ? 'Close' : 'Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: (sent || loading)
                          ? null
                          : () async {
                              setState(() { loading = true; error = null; });
                              final email = emailController.text.trim();
                              if (!email.contains('@')) {
                                setState(() { error = 'Invalid email'; loading = false; });
                                return;
                              }
                              try {
                                await firebase_auth.FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                                setState(() {
                                  error = null;
                                  sent = true;
                                  loading = false;
                                });
                              } catch (e) {
                                setState(() { error = 'Error: ${e.toString()}'; loading = false; });
                              }
                            },
                      child: sent
                          ? const Text('Email sent')
                          : loading
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Send'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleSignUpOrLogin({required bool isSignUp}) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (mounted) {
      setState(() {
        _error = null; 
        // El estado de carga ahora es manejado por AuthProvider y escuchado en el build.
      });
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    String? methodError;

    // AuthProvider internamente gestionará su estado de _loading.
    try {
      if (isSignUp) {
        if (kIsWeb) {
          final recaptchaKey = '6LfW0yUrAAAAAI7QFs_2qoY7KEHTQvhzIkNnLL13';
          String? token;
          try {
            await GRecaptchaV3.ready(recaptchaKey);
            token = await GRecaptchaV3.execute(recaptchaKey);
          } catch (e) {
            methodError = 'Error validating reCAPTCHA: $e';
          }
          if (methodError == null && (token == null || token.isEmpty)) {
            methodError = 'Could not validate reCAPTCHA.';
          }
        } else {
          methodError = 'reCAPTCHA validation is only available on the web version.';
        }
        
        if (methodError == null) { // Solo intentar registrar si no hay error de reCAPTCHA
          methodError = await authProvider.registerWithEmail(
            _emailController.text,
            _passwordController.text,
            name: _nameController.text.trim(),
          );
        }
      } else {
        methodError = await authProvider
            .signInWithEmail(_emailController.text, _passwordController.text);
      }
    } catch (e) {
        methodError = 'An unexpected error occurred: ${e.toString()}';
    }

    if (!mounted) return; 

    if (methodError != null) {
      setState(() {
        _error = methodError;
      });
    }
    // No es necesario setState para 'loading' aquí, el widget reaccionará a AuthProvider.
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar el estado de carga del AuthProvider
    final authLoading = context.watch<AuthProvider>().loading;

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction, // Para limpiar errores de input al escribir
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isRegister) ...[
            TextFormField(
              controller: _nameController,
              enabled: !authLoading, // Deshabilitar si está cargando
              decoration: InputDecoration(
                labelText: 'Full name',
                prefixIcon: const Icon(Icons.person_outline, color: kPrimaryColor),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) => value != null && value.trim().isNotEmpty ? null : 'Name is required',
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _emailController,
            enabled: !authLoading, // Deshabilitar si está cargando
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email_outlined, color: kPrimaryColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            validator: (value) => value != null && value.contains('@') ? null : 'Invalid email',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            enabled: !authLoading, // Deshabilitar si está cargando
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline, color: kPrimaryColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            obscureText: true,
            onChanged: _isRegister ? _checkPasswordStrength : null,
            validator: (value) {
              if (!_isRegister) {
                // Login: solo verificar si está vacío
                return (value == null || value.isEmpty) ? 'Password is required' : null;
              } else {
                // Register: validación de fortaleza existente
                if (value == null || value.length < 8) return 'Minimum 8 characters';
                if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Must contain uppercase letter';
                if (!RegExp(r'[a-z]').hasMatch(value)) return 'Must contain lowercase letter';
                if (!RegExp(r'\d').hasMatch(value)) return 'Must contain number';
                if (!RegExp(r'[!@#\$&*~]').hasMatch(value)) return 'Must contain special character';
                return null;
              }
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
              child: Text('Strength: $_passwordStrengthLabel', style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _repeatPasswordController,
              enabled: !authLoading, // Deshabilitar si está cargando
              decoration: InputDecoration(
                labelText: 'Repeat password',
                prefixIcon: const Icon(Icons.lock_outline, color: kPrimaryColor),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              obscureText: true,
              validator: (value) => value == _passwordController.text ? null : 'Passwords do not match',
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error ?? 'Unknown error', style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: authLoading ? null : () => _handleSignUpOrLogin(isSignUp: _isRegister),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: authLoading 
                   ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                   : Text(_isRegister ? 'Sign up' : 'Log in'),
          ),
          if (!_isRegister) ...[
            TextButton(
              onPressed: _showResetPasswordDialog,
              style: TextButton.styleFrom(foregroundColor: kPrimaryColor),
              child: const Text('Forgot your password?'),
            ),
          ],
          TextButton(
            onPressed: authLoading ? null : () { // Deshabilitar si está cargando
              setState(() => _isRegister = !_isRegister);
            },
            style: TextButton.styleFrom(
              foregroundColor: kPrimaryColor,
            ),
            child: Text(_isRegister ? 'Already have an account? Log in' : 'Don\'t have an account? Sign up'),
          ),
        ],
      ),
    );
  }
}
