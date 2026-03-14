import 'package:flutter/material.dart';

import '../data/collection_settings_model.dart';
import '../services/collection_settings_service.dart';
import 'brand_logo.dart';

class CollectionSettingsPage extends StatefulWidget {
  const CollectionSettingsPage({super.key});

  @override
  State<CollectionSettingsPage> createState() => _CollectionSettingsPageState();
}

class _CollectionSettingsPageState extends State<CollectionSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _tareWeightController = TextEditingController();

  CollectionSettings _settings = CollectionSettings.defaults;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tareWeightController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await CollectionSettingsService.instance.load();
    if (!mounted) return;
    _tareWeightController.text = settings.tareWeight.toStringAsFixed(2);
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final tareWeight = double.parse(_tareWeightController.text.trim());

    setState(() {
      _saving = true;
    });

    await CollectionSettingsService.instance.save(
      _settings.copyWith(tareWeight: tareWeight),
    );

    if (!mounted) return;
    setState(() {
      _settings = _settings.copyWith(tareWeight: tareWeight);
      _saving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Collection settings saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const BrandedAppBarTitle('Collection Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
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
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Settings'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}