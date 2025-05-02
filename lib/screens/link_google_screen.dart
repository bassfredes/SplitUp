import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/constants.dart';
import '../widgets/header.dart';

class LinkGoogleScreen extends StatefulWidget {
  const LinkGoogleScreen({super.key});

  @override
  State<LinkGoogleScreen> createState() => _LinkGoogleScreenState();
}

class _LinkGoogleScreenState extends State<LinkGoogleScreen> {
  bool _loading = false;
  String? _error;
  bool _isLinked = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _isLinked = user?.providerData.any((p) => p.providerId == 'google.com') ?? false;
  }

  Future<void> _linkGoogle() async {
    setState(() { _loading = true; _error = null; });
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) throw Exception('No Google account selected');
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.currentUser?.linkWithCredential(credential);
      if (!mounted) return;
      setState(() { _isLinked = true; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google linked successfully')));
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() { _error = e.message; });
    } catch (e) {
      setState(() { _error = 'Error: ${e.toString()}'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _unlinkGoogle() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlink Google'),
        content: const Text('Are you sure you want to unlink your Google account? You may lose access if you do not have another login method.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseAuth.instance.currentUser?.unlink('google.com');
      if (!mounted) return;
      setState(() { _isLinked = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google unlinked successfully')));
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isLinked ? 'Unlink Google' : 'Link Google', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
              ],
              ElevatedButton.icon(
                icon: Icon(_isLinked ? Icons.link_off : Icons.link),
                label: Text(_isLinked ? 'Unlink Google' : 'Link Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isLinked ? Colors.red : kPrimaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _loading
                    ? null
                    : _isLinked
                        ? _unlinkGoogle
                        : _linkGoogle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
