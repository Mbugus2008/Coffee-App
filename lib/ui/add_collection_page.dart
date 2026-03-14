import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/daily_collection_model.dart';
import '../data/daily_collection_repository.dart';
import '../data/farmer_model.dart';
import '../data/farmer_repository.dart';
import '../services/collection_settings_service.dart';
import '../services/classic_scale_service.dart';

class AddCollectionPage extends StatefulWidget {
  const AddCollectionPage({super.key});

  @override
  State<AddCollectionPage> createState() => _AddCollectionPageState();
}

class _AddCollectionPageState extends State<AddCollectionPage> {
  static final _random = Random();
  final _formKey = GlobalKey<FormState>();
  final _kgController = TextEditingController();
  final _bagsController = TextEditingController();
  bool _isSaving = false;
  bool _isConnectingScale = false;
  String _scaleStatus = 'Disconnected';
  StreamSubscription<double>? _weightSub;
  String _farmerNumber = '';
  String _farmerName = '';
  String _factory = '';

  @override
  void dispose() {
    _weightSub?.cancel();
    _kgController.dispose();
    _bagsController.dispose();
    super.dispose();
  }

  Future<void> _connectScale() async {
    setState(() {
      _isConnectingScale = true;
      _scaleStatus = 'Connecting...';
    });

    final connected = await ClassicScaleService.instance.connectToScale();

    await _weightSub?.cancel();
    if (connected) {
      _weightSub = ClassicScaleService.instance.weightStream.listen((weight) {
        _kgController.text = weight.toStringAsFixed(2);
      });
    }

    if (!mounted) return;
    setState(() {
      _isConnectingScale = false;
      _scaleStatus = connected ? 'Connected' : 'Disconnected';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repository = context.read<DailyCollectionRepository>();

    setState(() {
      _isSaving = true;
    });

    final now = DateTime.now();
    final no = now.millisecondsSinceEpoch;
    final uniqueSuffix = _random.nextInt(1000000).toString().padLeft(6, '0');
    final kg = double.tryParse(_kgController.text.trim());
    final noOfBags = int.tryParse(_bagsController.text.trim());
    final settings = await CollectionSettingsService.instance.load();
    final tare = noOfBags == null ? null : settings.tareWeight * noOfBags;

    final collection = DailyCollection(
      farmersNumber: _farmerNumber.trim(),
      collectionsDate: now,
      collectionNumber: 'COL-$no-$uniqueSuffix',
      coffeeType: '',
      no: no,
      farmersName: _farmerName,
      kgCollected: kg,
      cancelled: 'N',
      paid: 0,
      idNumber: '',
      factory: _factory,
      sent: false,
      comments: '',
      cumm: null,
      userName: 'local',
      can: '',
      collectionTime: now,
      collectType: 'Manual',
      crop: '',
      gross: null,
      tare: tare,
      noOfBags: noOfBags,
      deliveredBy: '',
      coffeTypeName: '',
      updated: false,
    );

    await repository.addCollection(collection);

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final farmers = context.watch<FarmerRepository>().farmers;
    final collections = context.watch<DailyCollectionRepository>().items;
    final filteredCollections = collections
        .where((item) => item.farmersNumber == _farmerNumber.trim())
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Add Collection')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Autocomplete<Farmer>(
                optionsBuilder: (textEditingValue) {
                  final query = textEditingValue.text.trim().toLowerCase();
                  if (query.isEmpty) return const Iterable<Farmer>.empty();
                  return farmers.where((farmer) {
                    return farmer.no.toLowerCase().contains(query) ||
                        farmer.name.toLowerCase().contains(query);
                  });
                },
                displayStringForOption: (farmer) => farmer.no,
                onSelected: (farmer) {
                  _farmerNumber = farmer.no;
                  _farmerName = farmer.name;
                  _factory = farmer.factory;
                },
                fieldViewBuilder:
                    (
                      context,
                      textEditingController,
                      focusNode,
                      onFieldSubmitted,
                    ) {
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        onChanged: (value) {
                          _farmerNumber = value;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Farmer Number',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter farmer number';
                          }
                          return null;
                        },
                      );
                    },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width - 40,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shrinkWrap: true,
                          itemCount: options.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final farmer = options.elementAt(index);
                            return ListTile(
                              title: Text(farmer.no),
                              subtitle: Text(farmer.name),
                              onTap: () => onSelected(farmer),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text('Scale: $_scaleStatus')),
                  FilledButton.icon(
                    onPressed: _isConnectingScale ? null : _connectScale,
                    icon: const Icon(Icons.bluetooth_connected),
                    label: const Text('Connect Scale'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _kgController,
                decoration: const InputDecoration(labelText: 'Kg Collected'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter collected kg';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bagsController,
                decoration: const InputDecoration(labelText: 'No of Bags'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return 'Enter number of bags';
                  }
                  final parsed = int.tryParse(trimmed);
                  if (parsed == null) {
                    return 'Enter a whole number';
                  }
                  if (parsed < 0) {
                    return 'Number of bags cannot be negative';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              if (_farmerNumber.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Previous deliveries',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (filteredCollections.isEmpty)
                  const Text('No deliveries recorded yet.')
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredCollections.length,
                    separatorBuilder: (_, __) => const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final item = filteredCollections[index];
                      final dateText = item.collectionsDate
                          .toIso8601String()
                          .split('T')
                          .first;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('$dateText • ${item.kgCollected ?? 0} kg'),
                        subtitle: Text(item.collectionNumber),
                      );
                    },
                  ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Collection'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
