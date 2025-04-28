import 'package:flutter/material.dart';
import 'package:splitup_application/config/constants.dart';

class Header extends StatelessWidget implements PreferredSizeWidget {
  final String currentRoute;
  final VoidCallback? onLogout;
  final VoidCallback? onAccount;
  final VoidCallback? onGroups;
  final VoidCallback? onDashboard;

  const Header({
    super.key,
    required this.currentRoute,
    this.onLogout,
    this.onAccount,
    this.onGroups,
    this.onDashboard,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            constraints: const BoxConstraints(maxWidth: 1280),
            height: kToolbarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
                children: [
                  GestureDetector(
                  onTap: onDashboard,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    height: 135,
                    child: Image.asset(
                    'assets/logo/header.png',
                    fit: BoxFit.contain,
                    ),
                  ),
                  ),
                  const SizedBox(width: 24),
                  // Espacio flexible
                  Expanded(child: Container()),
                  // Botón Grupos
                  TextButton(
                  onPressed: onGroups,
                  child: Text(
                    'Grupos',
                    style: TextStyle(
                    color: currentRoute == '/groups' || currentRoute == '/group_detail' || currentRoute == '/expense_detail' ? kPrimaryColor : Colors.grey[700],
                    fontWeight: currentRoute == '/groups' || currentRoute == '/group_detail' || currentRoute == '/expense_detail' ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  ),
                  const SizedBox(width: 8),
                // Menú Cuenta
                PopupMenuButton<String>(
                  icon: Icon(Icons.account_circle, color: currentRoute == '/account' ? kPrimaryColor : Colors.grey[700]),
                  onSelected: (value) {
                    if (value == 'account' && onAccount != null) onAccount!();
                    if (value == 'logout' && onLogout != null) onLogout!();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'account',
                      child: Text('Mi cuenta'),
                    ),
                    PopupMenuItem(
                      value: 'logout',
                      child: Text('Salir'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
