import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'data/daily_collection_repository.dart';
import 'data/farmer_repository.dart';
import 'data/store_repository.dart';
import 'data/user_database.dart';
import 'data/user_repository.dart';
import 'services/app_permission_service.dart';
import 'services/session_store.dart';
import 'ui/bc_settings_page.dart';
import 'ui/collection_settings_page.dart';
import 'ui/collections_list_page.dart';
import 'ui/dashboard.dart';
import 'ui/farmer_collections_page.dart';
import 'ui/farmers_page.dart';
import 'ui/items_page.dart';
import 'ui/login_page.dart';
import 'ui/printer_settings_page.dart';
import 'ui/store_headers_page.dart';
import 'ui/user_manual_page.dart';
import 'ui/users_page.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => UserRepository(UserDatabase.instance)..loadUsers(),
        ),
        ChangeNotifierProvider(
          create: (_) => FarmerRepository(UserDatabase.instance)..loadFarmers(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              DailyCollectionRepository(UserDatabase.instance)
                ..loadCollections(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              StoreRepository(UserDatabase.instance)..loadStoreHeaders(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    const coffeeScheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF6F4E37),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFF1DCC8),
      onPrimaryContainer: Color(0xFF2E1A10),
      secondary: Color(0xFFB7794B),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFF6DFC8),
      onSecondaryContainer: Color(0xFF3C2415),
      tertiary: Color(0xFF5A8A64),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFD6E9D9),
      onTertiaryContainer: Color(0xFF14301C),
      error: Color(0xFFBA1A1A),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: Color(0xFFFFF8F3),
      onSurface: Color(0xFF221A14),
      surfaceContainerHighest: Color(0xFFEDE0D6),
      onSurfaceVariant: Color(0xFF53443B),
      outline: Color(0xFF85736A),
      outlineVariant: Color(0xFFD7C3B7),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF382E28),
      onInverseSurface: Color(0xFFFDEEE3),
      inversePrimary: Color(0xFFD8BAA2),
      surfaceTint: Color(0xFF6F4E37),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Coffee',
      home: const _StartupPage(),
      builder: (context, child) {
        return _PermissionGate(child: child ?? const SizedBox.shrink());
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: coffeeScheme,
        scaffoldBackgroundColor: coffeeScheme.surface,
        appBarTheme: const AppBarTheme(centerTitle: false),
      ),
      // routes: {
      //   '/dashboard': (_) => const DailyCollectionsPage(),
      //   '/login': (_) => const LoginPage(),
      //   '/users': (_) => const UsersPage(),
      //   '/farmers': (_) => const FarmersPage(),
      //   '/farmer-collections': (_) => const FarmerCollectionsPage(),
      //   '/collections': (_) => const CollectionsListPage(),
      //   '/printer-settings': (_) => const PrinterSettingsPage(),
      //   '/bc-settings': (_) => const BcSettingsPage(),
      // },
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => const _StartupPage(),
              settings: const RouteSettings(name: '/'),
            );
          case '/dashboard':
            return MaterialPageRoute(
              builder: (_) => const Dashboard(),
              settings: const RouteSettings(name: '/dashboard'),
            );
          case '/collections':
            return MaterialPageRoute(
              builder: (_) => const CollectionsListPage(),
              settings: const RouteSettings(name: '/collections'),
            );
          case '/farmers':
            return MaterialPageRoute(
              builder: (_) => const FarmersPage(),
              settings: const RouteSettings(name: '/farmers'),
            );
          case '/farmer-collections':
            return MaterialPageRoute(
              builder: (_) => const FarmerCollectionsPage(),
              settings: const RouteSettings(name: '/farmer-collections'),
            );
          case '/printer-settings':
            return MaterialPageRoute(
              builder: (_) => const PrinterSettingsPage(),
              settings: const RouteSettings(name: '/printer-settings'),
            );
          case '/bc-settings':
            return MaterialPageRoute(
              builder: (_) => const BcSettingsPage(),
              settings: const RouteSettings(name: '/bc-settings'),
            );
          case '/collection-settings':
            return MaterialPageRoute(
              builder: (_) => const CollectionSettingsPage(),
              settings: const RouteSettings(name: '/collection-settings'),
            );
          case '/users':
            return MaterialPageRoute(
              builder: (_) => const UsersPage(),
              settings: const RouteSettings(name: '/users'),
            );
          case '/stores':
            return MaterialPageRoute(
              builder: (_) => const StoreHeadersPage(),
              settings: const RouteSettings(name: '/stores'),
            );
          case '/items':
            return MaterialPageRoute(
              builder: (_) => const ItemsPage(),
              settings: const RouteSettings(name: '/items'),
            );
          case '/login':
            return MaterialPageRoute(
              builder: (_) => const LoginPage(),
              settings: const RouteSettings(name: '/login'),
            );
          case '/user-manual':
            return MaterialPageRoute(
              builder: (_) => const UserManualPage(),
              settings: const RouteSettings(name: '/user-manual'),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const _StartupPage(),
              settings: const RouteSettings(name: '/'),
            );
        }
      },
      onUnknownRoute: (_) => MaterialPageRoute(
        builder: (_) => const _StartupPage(),
        settings: const RouteSettings(name: '/'),
      ),
    );
  }
}

class _StartupPage extends StatefulWidget {
  const _StartupPage();

  @override
  State<_StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<_StartupPage> {
  bool _loading = true;
  bool _needsSetup = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _decide();
    });
  }

  Future<void> _decide() async {
    final repo = context.read<UserRepository>();
    final rememberedUsername = await SessionStore.instance
        .getRememberedUsernameForToday();
    if (rememberedUsername != null) {
      final rememberedUser = await repo.getLocalUserByUsername(
        rememberedUsername,
      );
      if (rememberedUser != null) {
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/dashboard', (route) => false);
        return;
      }
      await SessionStore.instance.clearSession();
    }

    bool hasUsers = false;
    try {
      hasUsers = await repo.hasAnyUsers();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _loading = false;
      _needsSetup = !hasUsers;
    });
  }

  Future<void> _saveAndSync() async {
    if (_syncing) return;
    setState(() {
      _syncing = true;
    });

    final userRepo = context.read<UserRepository>();
    final farmerRepo = context.read<FarmerRepository>();
    try {
      await userRepo.refreshFromServer();
    } catch (_) {}

    try {
      await farmerRepo.refreshFromServer();
    } catch (_) {}

    bool hasUsers = false;
    try {
      hasUsers = await userRepo.hasAnyUsers();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _syncing = false;
      _needsSetup = !hasUsers;
    });

    if (!hasUsers) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No users loaded from Business Central. Check URL/company/credentials and try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_needsSetup) {
      return Stack(
        children: [
          BcSettingsPage(onSaved: _saveAndSync),
          if (_syncing) const Positioned.fill(child: _SyncOverlay()),
        ],
      );
    }

    return const LoginPage();
  }
}

class _SyncOverlay extends StatelessWidget {
  const _SyncOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.scrim.withAlpha(102),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _PermissionGate extends StatefulWidget {
  const _PermissionGate({required this.child});

  final Widget child;

  @override
  State<_PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<_PermissionGate> {
  bool _checking = true;
  bool _granted = false;
  bool _permanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final result = await AppPermissionService.instance.checkStatus().timeout(
      const Duration(seconds: 5),
      onTimeout: () => (granted: false, permanentlyDenied: false),
    );
    if (!mounted) return;
    setState(() {
      _checking = false;
      _granted = result.granted;
      _permanentlyDenied = result.permanentlyDenied;
    });
  }

  Future<void> _request() async {
    setState(() {
      _checking = true;
    });

    final result = await AppPermissionService.instance.ensureReady().timeout(
      const Duration(seconds: 10),
      onTimeout: () => (granted: false, permanentlyDenied: false),
    );
    if (!mounted) return;
    setState(() {
      _checking = false;
      _granted = result.granted;
      _permanentlyDenied = result.permanentlyDenied;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_granted) {
      return widget.child;
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.security, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Permissions required',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'This app needs Bluetooth and (on some Android versions) Location permission to discover and connect to the printer/scale.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _request,
                  child: const Text('Grant permissions'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _permanentlyDenied ? openAppSettings : null,
                  child: const Text('Open app settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
