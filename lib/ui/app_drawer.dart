import 'package:flutter/material.dart';

import '../services/session_store.dart';
import 'brand_logo.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.currentRoute});

  final String currentRoute;

  void _navigate(BuildContext context, String route) {
    if (route == currentRoute) {
      Navigator.of(context).pop();
      return;
    }
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CoffeeBeanLogo(size: 40),
                const SizedBox(height: 12),
                Text(
                  'Coffee App',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Collections & Printing',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.people_alt_outlined),
            title: const Text('Farmers'),
            selected: currentRoute == '/farmers',
            onTap: () => _navigate(context, '/farmers'),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Dashboard'),
            selected: currentRoute == '/dashboard',
            onTap: () => _navigate(context, '/dashboard'),
          ),
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: const Text('Users'),
            selected: currentRoute == '/users',
            onTap: () => _navigate(context, '/users'),
          ),
          ListTile(
            leading: const Icon(Icons.local_shipping_outlined),
            title: const Text('Collections'),
            selected: currentRoute == '/collections',
            onTap: () => _navigate(context, '/collections'),
          ),
          ListTile(
            leading: const Icon(Icons.shopping_bag_outlined),
            title: const Text('Stores'),
            selected: currentRoute == '/stores',
            onTap: () => _navigate(context, '/stores'),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Items'),
            selected: currentRoute == '/items',
            onTap: () => _navigate(context, '/items'),
          ),
          ListTile(
            leading: const Icon(Icons.assessment_outlined),
            title: const Text('Farmer Collections'),
            selected: currentRoute == '/farmer-collections',
            onTap: () => _navigate(context, '/farmer-collections'),
          ),
          ListTile(
            leading: const Icon(Icons.print_outlined),
            title: const Text('Bluetooth Settings'),
            selected: currentRoute == '/printer-settings',
            onTap: () => _navigate(context, '/printer-settings'),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Business Central'),
            selected: currentRoute == '/bc-settings',
            onTap: () => _navigate(context, '/bc-settings'),
          ),
          ListTile(
            leading: const Icon(Icons.tune_outlined),
            title: const Text('Collection Settings'),
            selected: currentRoute == '/collection-settings',
            onTap: () => _navigate(context, '/collection-settings'),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('User Manual'),
            selected: currentRoute == '/user-manual',
            onTap: () => _navigate(context, '/user-manual'),
          ),
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await SessionStore.instance.clearSession();
              if (!context.mounted) return;
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
        ],
      ),
    );
  }
}
