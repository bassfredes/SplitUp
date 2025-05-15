import 'package:flutter/material.dart';
import 'package:splitup_application/config/constants.dart';

class Header extends StatelessWidget implements PreferredSizeWidget {
  final String currentRoute;
  final VoidCallback? onLogout;
  final VoidCallback? onAccount;
  final VoidCallback? onGroups;
  final VoidCallback? onDashboard;
  final String? avatarUrl;
  final String? displayName;
  final String? email;

  const Header({
    super.key,
    required this.currentRoute,
    this.onLogout,
    this.onAccount,
    this.onGroups,
    this.onDashboard,
    this.avatarUrl,
    this.displayName,
    this.email,
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
            height: kToolbarHeight + 50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 25),
            child: Row(
              children: [
                // Logo con link al dashboard y cursor pointer
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: onDashboard,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      height: 50,
                      child: Image.asset(
                        'assets/logo/logo-header.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Flexible space
                Expanded(child: Container()),
                // Botón Home (icono)
                IconButton(
                  icon: Icon(Icons.home, color: currentRoute == '/dashboard' ? kPrimaryColor : Colors.grey[700]),
                  onPressed: onDashboard,
                  tooltip: 'Inicio',
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'Cuenta',
                  icon: (avatarUrl != null && avatarUrl!.isNotEmpty)
                    ? CircleAvatar(
                        backgroundImage: NetworkImage(avatarUrl!),
                        radius: 20,
                      )
                    : (displayName != null && displayName!.isNotEmpty)
                      ? CircleAvatar(
                          backgroundColor: Colors.blue[200],
                          radius: 20,
                          child: Text(
                            displayName!.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        )
                      : CircleAvatar(
                          backgroundColor: Colors.grey[300],
                          radius: 20,
                          child: Icon(Icons.person, color: Colors.grey[700]),
                        ),
                  onSelected: (value) {
                    if (value == 'account' && onAccount != null) onAccount!();
                    if (value == 'logout' && onLogout != null) onLogout!();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      enabled: false,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          (avatarUrl != null && avatarUrl!.isNotEmpty)
                            ? CircleAvatar(backgroundImage: NetworkImage(avatarUrl!), radius: 22)
                            : (displayName != null && displayName!.isNotEmpty)
                              ? CircleAvatar(
                                  backgroundColor: Colors.blue[200],
                                  radius: 22,
                                  child: Text(
                                    displayName!.substring(0, 1).toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                                  ),
                                )
                              : CircleAvatar(
                                  backgroundColor: Colors.grey[300],
                                  radius: 22,
                                  child: Icon(Icons.person, color: Colors.grey[700]),
                                ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  email ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'account',
                      child: Row(
                        children: const [
                          Icon(Icons.person_outline, size: 20, color: Colors.teal),
                          SizedBox(width: 10),
                          Text('My Account'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          const Icon(Icons.logout, size: 20, color: Colors.red),
                          const SizedBox(width: 10),
                          Text('Logout', style: TextStyle(color: Colors.red[700])),
                        ],
                      ),
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
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 50);
}
