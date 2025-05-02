import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/constants.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isSending = false;
  bool _isSent = false;
  bool _isReloading = false;
  String? _error;

  Future<void> _sendVerificationEmail() async {
    setState(() { _isSending = true; _isSent = false; _error = null; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();
      setState(() { _isSent = true; });
    } catch (e) {
      setState(() { _error = 'Error sending email: $e'; });
    } finally {
      setState(() { _isSending = false; });
    }
  }

  Future<void> _checkVerification() async {
    setState(() { _isReloading = true; _error = null; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      if (user != null && user.emailVerified) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        setState(() { _error = 'You have not verified your email yet.'; });
      }
    } catch (e) {
      setState(() { _error = 'Error verifying: $e'; });
    } finally {
      setState(() { _isReloading = false; });
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify your email'),
        backgroundColor: kPrimaryColor,
        automaticallyImplyLeading: false,
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
                // Corrected: Use Color.fromRGBO or Color.fromARGB
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
              const Icon(Icons.email_outlined, size: 56, color: kPrimaryColor),
              const SizedBox(height: 16),
              Text('We sent a verification email to:', textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(user?.email ?? '', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
              ],
              if (_isSent)
                const Text('Email sent. Check your inbox or spam folder.', style: TextStyle(color: Colors.green)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('I have verified my email'),
                onPressed: _isReloading ? null : _checkVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: Text(_isSending ? 'Sending...' : 'Resend email'),
                onPressed: _isSending ? null : _sendVerificationEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _logout,
                child: const Text('Log out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
