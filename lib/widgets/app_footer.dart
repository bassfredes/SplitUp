import 'package:flutter/material.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      color: const Color(0xFFF6F8FA),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logo/logo-header.png',
                height: 32,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 12),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '© 2025 SplitUp. Todos los derechos reservados.',
            style: TextStyle(color: Colors.grey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {},
                child: const Text('Términos de uso', style: TextStyle(fontSize: 13)),
              ),
              const Text('·', style: TextStyle(color: Colors.grey)),
              TextButton(
                onPressed: () {},
                child: const Text('Privacidad', style: TextStyle(fontSize: 13)),
              ),
              const Text('·', style: TextStyle(color: Colors.grey)),
              TextButton(
                onPressed: () {},
                child: const Text('Contacto', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
