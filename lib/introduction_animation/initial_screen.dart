import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../screens/login_screen.dart'; // Asegúrate que la ruta sea correcta
import 'introduction_animation_screen.dart'; // Asegúrate que la ruta sea correcta
import '../screens/dashboard_screen.dart'; // Para redirigir si ya está logueado
import 'package:firebase_auth/firebase_auth.dart';

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  @override
  void initState() {
    super.initState();
    _checkIntroductionStatus();
  }

  Future<void> _checkIntroductionStatus() async {
    await SettingsService.instance.init();
    final bool hasSeenIntro = SettingsService.instance.hasSeenIntro;
    final user = FirebaseAuth.instance.currentUser;

    if (!mounted) return;

    if (hasSeenIntro) {
      if (user != null) {
        if (user.emailVerified) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        } else {
          // Puedes redirigir a una pantalla de verificación de email si es necesario
          // Por ahora, vamos al login si el email no está verificado.
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => const IntroductionAnimationScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Muestra un loader mientras se decide a dónde redirigir
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
