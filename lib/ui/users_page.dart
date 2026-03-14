import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/user_model.dart';
import '../data/user_repository.dart';
import '../services/session_store.dart';
import 'app_drawer.dart' as app_drawer;
import 'brand_logo.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserRepository>().loadUsers();
    });
  }

  Future<void> _showUserDialog({User? user}) async {
    final message = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return _UserEditorDialog(user: user);
      },
    );

    if (!mounted || message == null || message.isEmpty) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _deleteUser(User user) async {
    final repo = context.read<UserRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete User'),
          content: Text('Delete ${user.username} from this device?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await repo.deleteUser(user);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('User deleted locally.')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to delete user: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = context.watch<UserRepository>().users;
    final routeName = ModalRoute.of(context)?.settings.name;
    final currentRoute = routeName ?? '/users';

    return Scaffold(
      appBar: AppBar(
        title: const BrandedAppBarTitle('Coffee Users'),
        automaticallyImplyLeading: false,
        leadingWidth: 96,
        leading: Builder(
          builder: (context) {
            return Row(
              children: [
                IconButton(
                  tooltip: 'Back to home',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/dashboard', (route) => false);
                  },
                ),
                IconButton(
                  tooltip: 'Menu',
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Reload local users',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<UserRepository>().loadUsers();
            },
          ),
          IconButton(
            tooltip: 'Farmers',
            icon: const Icon(Icons.agriculture_outlined),
            onPressed: () {
              Navigator.of(context).pushNamed('/farmers');
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await SessionStore.instance.clearSession();
              if (!context.mounted) return;
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
        ],
      ),
      drawer: app_drawer.AppDrawer(currentRoute: currentRoute),
      body: Center(
        child: users.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No users found.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _showUserDialog,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Add User'),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                separatorBuilder: (_, __) => const Divider(height: 24),
                itemBuilder: (context, index) {
                  final user = users[index];
                  final details = <String>[
                    user.username,
                    if (user.rights.trim().isNotEmpty)
                      'Rights: ${user.rights.trim()}',
                    if (user.email.trim().isNotEmpty) user.email.trim(),
                    if (user.phone.trim().isNotEmpty) user.phone.trim(),
                  ];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        user.name.trim().isEmpty
                            ? user.username.trim().substring(0, 1).toUpperCase()
                            : user.name.trim().substring(0, 1).toUpperCase(),
                      ),
                    ),
                    title: Text(
                      user.name.trim().isEmpty ? user.username : user.name,
                    ),
                    subtitle: Text(details.join(' • ')),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _showUserDialog(user: user);
                          case 'delete':
                            _deleteUser(user);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Text('Edit'),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showUserDialog,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add User'),
      ),
    );
  }
}

class _UserEditorDialog extends StatefulWidget {
  const _UserEditorDialog({this.user});

  final User? user;

  @override
  State<_UserEditorDialog> createState() => _UserEditorDialogState();
}

class _UserEditorDialogState extends State<_UserEditorDialog> {
  static const _rightsOptions = <String>['Admin', 'Clerk', 'Supervisor'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  bool _isSaving = false;
  bool _obscurePassword = true;
  late String? _selectedRights;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _usernameController = TextEditingController(text: user?.username ?? '');
    _passwordController = TextEditingController(text: user?.password ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    final initialRights = user?.rights.trim() ?? '';
    _selectedRights = _rightsOptions.contains(initialRights)
        ? initialRights
        : (_rightsOptions.isNotEmpty ? _rightsOptions.first : null);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final draft = User(
      id: widget.user?.id,
      name: _nameController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      rights: (_selectedRights ?? '').trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      updated: false,
    );

    try {
      final repo = context.read<UserRepository>();
      if (widget.user == null) {
        await repo.addUser(draft);
      } else {
        await repo.updateUser(draft);
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        widget.user == null
            ? 'User created and pushed to BC.'
            : 'User updated in BC and locally.',
      );
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save user: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return AlertDialog(
      title: Text(user == null ? 'Add User' : 'Edit User'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _usernameController,
                  enabled: user == null,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter username';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedRights,
                  decoration: const InputDecoration(labelText: 'Rights'),
                  items: _rightsOptions
                      .map(
                        (right) => DropdownMenuItem<String>(
                          value: right,
                          child: Text(right),
                        ),
                      )
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() {
                            _selectedRights = value;
                          });
                        },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Select rights';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(user == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}
