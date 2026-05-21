import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/collection_settings_model.dart';
import '../data/company_info_model.dart';
import '../services/bc/bc_settings_store.dart';
import '../services/collection_settings_service.dart';
import '../services/company_info_service.dart';
import '../services/session_store.dart';
import 'brand_logo.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.currentRoute});

  final String currentRoute;

  Future<_DrawerHeaderData> _loadHeaderData() async {
    final results = await Future.wait([
      CompanyInfoService.instance.loadLocal(),
      CollectionSettingsService.instance.load(),
      BcSettingsStore.instance.load(),
    ]);

    return _DrawerHeaderData(
      companyInfo: results[0] as CompanyInfo,
      collectionSettings: results[1] as CollectionSettings,
      selectedFactory: (results[2] as dynamic).factory.toString().trim(),
    );
  }

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
          FutureBuilder(
            future: _loadHeaderData(),
            builder: (context, snapshot) {
              final data = snapshot.data;
              final companyName = data?.companyInfo.name.trim() ?? '';
              final address = data?.companyInfo.address.trim() ?? '';
              final phoneNo = data?.companyInfo.phoneNo.trim() ?? '';
              final email = data?.companyInfo.email.trim() ?? '';
              final crop = data?.collectionSettings.crop.trim() ?? '';
              final coffeeType =
                  data?.collectionSettings.coffeeType.trim() ?? '';
              final selectedFactory = data?.selectedFactory.trim() ?? '';
              final picture = data?.companyInfo.pictureBytes;
              final title = companyName.isNotEmpty ? companyName : 'Coffee App';
              final infoLines = <String>[
                if (selectedFactory.isNotEmpty)
                  'Selected Factory: $selectedFactory',
                if (crop.isNotEmpty) 'Crop: $crop',
                if (coffeeType.isNotEmpty) 'Coffee Type: $coffeeType',
                if (address.isNotEmpty) address,
                if (phoneNo.isNotEmpty) 'Phone: $phoneNo',
                if (email.isNotEmpty) email,
              ];

              return DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildHeaderLogo(picture),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    if (infoLines.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      ...infoLines
                          .take(3)
                          .map(
                            (line) => Text(
                              line,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                  ),
                            ),
                          ),
                    ],
                  ],
                ),
              );
            },
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
            title: const Text('Settings'),
            selected:
                currentRoute == '/settings' ||
                currentRoute == '/bc-settings' ||
                currentRoute == '/collection-settings',
            onTap: () => _navigate(context, '/settings'),
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

  Widget _buildHeaderLogo(Uint8List? picture) {
    if (picture == null || picture.isEmpty) {
      return const CoffeeBeanLogo(size: 40);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(
        picture,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const CoffeeBeanLogo(size: 40),
      ),
    );
  }
}

class _DrawerHeaderData {
  const _DrawerHeaderData({
    required this.companyInfo,
    required this.collectionSettings,
    required this.selectedFactory,
  });

  final CompanyInfo companyInfo;
  final CollectionSettings collectionSettings;
  final String selectedFactory;
}
