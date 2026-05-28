import 'package:flutter/material.dart';

import '../services/app_settings_store.dart';
import '../services/bc/bc_odata_client.dart';
import '../services/bc/bc_settings.dart';
import '../services/bc/bc_settings_store.dart';
import '../services/collection_settings_service.dart';
import 'back_button_guard.dart';

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

class _BcSettingsPageState extends State<BcSettingsPage> with BackButtonGuard {
  final _formKey = GlobalKey<FormState>();

  final BcODataClient _odataClient = BcODataClient();

  final _baseUrlController = TextEditingController();
  final _companyController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _factoryController = TextEditingController();
  final _cropController = TextEditingController();
  final _coffeeTypeController = TextEditingController();
  final _tareWeightController = TextEditingController();

  String? _selectedFactory;
  String? _showCumulative;
  bool _loadingFactories = false;
  String? _factoriesError;
  List<_FactoryOption> _factories = const [];

  bool _loading = true;
  bool _saving = false;
  bool _loadingSetup = false;
  String? _setupError;
  bool _hidePassword = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await BcSettingsStore.instance.load();
    final collectionSettings = await CollectionSettingsService.instance.load();
    if (!mounted) return;
    _baseUrlController.text = settings.odataBaseUrl;
    _companyController.text = settings.company;
    _usernameController.text = settings.username;
    _passwordController.text = settings.password;
    _factoryController.text = settings.factory;
    _cropController.text = collectionSettings.crop;
    _coffeeTypeController.text = collectionSettings.coffeeType;
    _tareWeightController.text = collectionSettings.tareWeight.toStringAsFixed(
      2,
    );
    _selectedFactory = settings.factory.trim().isEmpty
        ? null
        : settings.factory.trim();
    _showCumulative = await AppSettingsStore.instance.loadShowCumulative();
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

  Future<void> _loadSetupFromBc() async {
    if (_loadingSetup) return;

    setState(() {
      _loadingSetup = true;
      _setupError = null;
    });

    try {
      final settings = _settingsFromForm();
      final setup = await CollectionSettingsService.instance.syncFromBcSetup(
        overrideSettings: settings,
        persistFactoryToStore: false,
      );

      if (!mounted) return;
      setState(() {
        _cropController.text = setup.crop;
        _coffeeTypeController.text = setup.coffeeType;
        _tareWeightController.text = setup.tareWeight.toStringAsFixed(2);
      });

      final rows = await _odataClient.getAll(settings, 'Setup', top: 1);
      if (rows.isNotEmpty) {
        final row = rows.first;
        final factory =
            ((row['Factory'] as String?) ??
                    (row['Factory_Name'] as String?) ??
                    (row['Factory Name'] as String?) ??
                    '')
                .trim();
        if (factory.isNotEmpty && mounted) {
          setState(() {
            _factoryController.text = factory;
            _selectedFactory = factory;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _setupError = 'Unable to load Setup: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingSetup = false;
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
    _cropController.dispose();
    _coffeeTypeController.dispose();
    _tareWeightController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
    });

    final settings = _settingsFromForm();
    final crop = _cropController.text.trim();
    final coffeeType = _coffeeTypeController.text.trim();
    final tareWeight = double.parse(_tareWeightController.text.trim());

    await BcSettingsStore.instance.save(settings);
    await CollectionSettingsService.instance.save(
      (await CollectionSettingsService.instance.load()).copyWith(
        crop: crop,
        coffeeType: coffeeType,
        tareWeight: tareWeight,
      ),
    );
    await AppSettingsStore.instance.saveShowCumulative(
      _showCumulative ?? AppSettingsStore.showCumulativeOptions.first,
    );

    if (!mounted) return;
    setState(() {
      _saving = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Settings saved.')));

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
    return guard(
      Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
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
                      Text(
                        'Business Central',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
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
                        decoration: const InputDecoration(
                          labelText: 'Username',
                        ),
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
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Collection Settings',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _loadingSetup ? null : _loadSetupFromBc,
                            icon: _loadingSetup
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.download_outlined),
                            label: const Text('Load Setup'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _cropController,
                        decoration: const InputDecoration(
                          labelText: 'Crop',
                          hintText: 'e.g. 2025/2026',
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Enter crop';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _coffeeTypeController,
                        decoration: const InputDecoration(
                          labelText: 'Coffee Type',
                          hintText: 'e.g. Cherry',
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Enter coffee type';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _tareWeightController,
                        decoration: const InputDecoration(
                          labelText: 'Tare Weight Per Bag (kg)',
                          hintText: '0.00',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return 'Enter tare weight';
                          }
                          final parsed = double.tryParse(trimmed);
                          if (parsed == null) {
                            return 'Enter a valid tare weight';
                          }
                          if (parsed < 0) {
                            return 'Tare weight cannot be negative';
                          }
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
                            onPressed: _loadingFactories
                                ? null
                                : _loadFactories,
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
                      if (_setupError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _setupError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _showCumulative,
                        decoration: const InputDecoration(
                          labelText: 'Show cumulative',
                        ),
                        items: AppSettingsStore.showCumulativeOptions
                            .map(
                              (option) => DropdownMenuItem(
                                value: option,
                                child: Text(option),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _showCumulative = value;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
