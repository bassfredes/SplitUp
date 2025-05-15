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
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 500;
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: Container(
            width: width * 0.95,
            constraints: const BoxConstraints(maxWidth: 1280),
            height: isMobile ? 64 : kToolbarHeight + 50,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 16, vertical: isMobile ? 8 : 25),
            child: Row(
              children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: onDashboard,
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: isMobile ? 0 : 5),
                      height: isMobile ? 32 : 50,
                      child: Image.asset(
                        'assets/logo/logo-header.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isMobile ? 8 : 24),
                Expanded(child: Container()),
                IconButton(
                  icon: Icon(Icons.home, size: isMobile ? 22 : 28, color: currentRoute == '/dashboard' ? kPrimaryColor : Colors.grey[700]),
                  onPressed: onDashboard,
                  tooltip: 'Inicio',
                ),
                if (!isMobile) const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'Cuenta',
                  icon: (avatarUrl != null && avatarUrl!.isNotEmpty)
                    ? CircleAvatar(
                        backgroundImage: NetworkImage(avatarUrl!),
                        radius: isMobile ? 16 : 20,
                      )
                    : (displayName != null && displayName!.isNotEmpty)
                      ? CircleAvatar(
                          backgroundColor: Colors.blue[200],
                          radius: isMobile ? 16 : 20,
                          child: Text(
                            displayName!.substring(0, 1).toUpperCase(),
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isMobile ? 14 : 16),
                          ),
                        )
                      : CircleAvatar(
                          backgroundColor: Colors.grey[300],
                          radius: isMobile ? 16 : 20,
                          child: Icon(Icons.person, color: Colors.grey[700], size: isMobile ? 18 : 22),
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
