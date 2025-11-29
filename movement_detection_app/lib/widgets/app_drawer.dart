
import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  final Map<String, dynamic>? loggedInUser;
  final VoidCallback onLogout;

  const AppDrawer({
    super.key,
    this.loggedInUser,
    required this.onLogout,
  });


  @override
  Widget build(BuildContext context) {
    // Fixed: Use full_name instead of email for display
    final String displayName = loggedInUser?['full_name'] ??
        loggedInUser?['fullName'] ??
        loggedInUser?['username'] ??
        'Guest User';
    final String avatarLetter = displayName.isNotEmpty && displayName != 'Guest User' ? displayName[0].toUpperCase() : '?';

    return Drawer(
      backgroundColor: Theme.of(context).primaryColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).hintColor.withOpacity(0.2),
            ),
            child: InkWell(
              onTap: () {
                Navigator.pop(context);
                if (loggedInUser != null) {
                  Navigator.pushNamed(context, '/profile');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please log in to view profile.')),
                  );
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Theme.of(context).primaryColorDark,
                    child: Text(
                      avatarLetter,
                      style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Show email as subtitle
                  Text(
                    loggedInUser?['email'] ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_outlined, color: Colors.white70),
            title: Text('Dashboard', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              if (ModalRoute.of(context)?.settings.name != '/home') {
                Navigator.pushReplacementNamed(context, '/home');
              }
            },
          ),
          // Added: Emergency Contacts option
          ListTile(
            leading: const Icon(Icons.contact_emergency_outlined, color: Colors.white70),
            title: Text('Emergency Contacts', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/emergency_contacts');
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined, color: Colors.white70),
            title: Text('Settings', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              if (ModalRoute.of(context)?.settings.name != '/settings') {
                Navigator.pushNamed(context, '/settings');
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined, color: Colors.white70),
            title: Text('Admin Panel', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/admin_login');
            },
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.logout_outlined, color: Colors.redAccent),
            title: Text('Logout', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.redAccent)),
            onTap: () {
              onLogout();
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined, color: Colors.white70),
            title: Text('High-Risk Zones', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/high_risk_zones');
            },
          ),
        ],
      ),
    );
  }
}