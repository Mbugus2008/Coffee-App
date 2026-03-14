import 'package:flutter/material.dart';

import '../services/bc/bc_odata_client.dart';
import '../services/bc/bc_settings.dart';
import '../services/bc/bc_settings_store.dart';

class _FactoryOption {
  const _FactoryOption({required this.code, required this.name});

  final String code;
  final String name;
}

class BcSettingsPage extends StatefulWidget {
  const BcSettingsPage({super.key, this.popAfterSave = false, this.onSaved});

  final bool popAfterSave;
  final Future<void> Function()? onSaved;

  @override
  State<BcSettingsPage> createState() => _BcSettingsPageState();
}

class _BcSettingsPageState extends State<BcSettingsPage> {
  final _formKey = GlobalKey<FormState>();

  final BcODataClient _odataClient = BcODataClient();

  final _baseUrlController = TextEditingController();
  final _companyController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _factoryController = TextEditingController();

  String? _selectedFactory;
  bool _loadingFactories = false;
  String? _factoriesError;
  List<_FactoryOption> _factories = const [];

  bool _loading = true;
  bool _saving = false;
  bool _hidePassword = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await BcSettingsStore.instance.load();
    if (!mounted) return;
    _baseUrlController.text = settings.odataBaseUrl;
    _companyController.text = settings.company;
    _usernameController.text = settings.username;
    _passwordController.text = settings.password;
    _factoryController.text = settings.factory;
    _selectedFactory = settings.factory.trim().isEmpty
        ? null
        : settings.factory.trim();
    setState(() {
      _loading = false;
    });
  }

  BcSettings _settingsFromForm() {
    return BcSettings(
      odataBaseUrl: _baseUrlController.text.trim(),
      company: _companyController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      factory: _factoryController.text.trim(),
    );
  }

  Future<void> _loadFactories() async {
    if (_loadingFactories) return;

    setState(() {
      _loadingFactories = true;
      _factoriesError = null;
      _factories = const [];
    });

    try {
      final settings = _settingsFromForm();
      final rows = await _odataClient.getAll(settings, 'Factories', top: 2000);

      String pickString(Map<String, Object?> json, List<String> keys) {
        for (final key in keys) {
          final v = json[key];
          if (v is String && v.trim().isNotEmpty) return v.trim();
        }
        return '';
      }

      final factories = <_FactoryOption>[];
      for (final row in rows) {
        // For Dimension Value-based services, Code/Name are typical.
        final code = pickString(row, ['Code', 'code']);
        if (code.isEmpty) continue;
        final name = pickString(row, ['Name', 'name']);
        factories.add(_FactoryOption(code: code, name: name));
      }

      factories.sort(
        (a, b) => a.code.toLowerCase().compareTo(b.code.toLowerCase()),
      );

      if (!mounted) return;
      setState(() {
        _factories = factories;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _factoriesError = 'Unable to load factories: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingFactories = false;
      });
    }
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _companyController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _factoryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
    });

    final settings = _settingsFromForm();

    await BcSettingsStore.instance.save(settings);

    if (!mounted) return;
    setState(() {
      _saving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Business Central settings saved.')),
    );

    if (widget.onSaved != null) {
      try {
        await widget.onSaved!();
      } catch (_) {}
    }

    if (widget.popAfterSave) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Central Settings'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _baseUrlController,
                      decoration: const InputDecoration(
                        labelText: 'OData Base URL',
                        hintText: 'http://host:port/BC240/ODataV4',
                      ),
                      validator: (value) {
                        final v = (value ?? '').trim();
                        if (v.isEmpty) return 'Enter base URL';
                        final uri = Uri.tryParse(v);
                        if (uri == null || !uri.hasScheme) {
                          return 'Enter a valid URL';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _companyController,
                      decoration: const InputDecoration(labelText: 'Company'),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Enter company';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(labelText: 'Username'),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Enter username';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _hidePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          tooltip: _hidePassword ? 'Show' : 'Hide',
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _hidePassword = !_hidePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').isEmpty) return 'Enter password';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _factories.isEmpty
                              ? TextFormField(
                                  controller: _factoryController,
                                  decoration: const InputDecoration(
                                    labelText: 'Factory (filter)',
                                    hintText: 'e.g. FACTORY-001',
                                  ),
                                  validator: (value) {
                                    if ((value ?? '').trim().isEmpty) {
                                      return 'Select a factory';
                                    }
                                    return null;
                                  },
                                )
                              : DropdownButtonFormField<String>(
                                  value: _selectedFactory,
                                  decoration: const InputDecoration(
                                    labelText: 'Factory (filter)',
                                  ),
                                  items: _factories
                                      .map(
                                        (f) => DropdownMenuItem(
                                          value: f.code,
                                          child: Text(
                                            f.name.isEmpty
                                                ? f.code
                                                : '${f.code} • ${f.name}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedFactory = value;
                                      _factoryController.text = value ?? '';
                                    });
                                  },
                                  validator: (value) {
                                    if ((value ?? '').trim().isEmpty) {
                                      return 'Select a factory';
                                    }
                                    return null;
                                  },
                                ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _loadingFactories ? null : _loadFactories,
                          icon: _loadingFactories
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh),
                          label: const Text('Load'),
                        ),
                      ],
                    ),
                    if (_factoriesError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _factoriesError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
