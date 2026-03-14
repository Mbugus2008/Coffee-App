import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/daily_collection_model.dart';
import '../data/daily_collection_repository.dart';
import '../data/farmer_model.dart';
import '../data/farmer_repository.dart';
import 'brand_logo.dart';
import '../services/classic_scale_service.dart';
import '../services/collection_settings_service.dart';

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

  String _formatShortDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }

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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final farmers = context.watch<FarmerRepository>().farmers;
    final collections = context.watch<DailyCollectionRepository>().items;
    final filteredCollections = collections
        .where((item) => item.farmersNumber == _farmerNumber.trim())
        .toList();
    final latestCollection = filteredCollections.isEmpty
        ? null
        : ([...filteredCollections]
              ..sort(
                (a, b) => (b.collectionTime ?? b.collectionsDate).compareTo(
                  a.collectionTime ?? a.collectionsDate,
                ),
              ))
            .first;

    return Scaffold(
      appBar: AppBar(
        title: const BrandedAppBarTitle('Add Collection'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: colors.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Farmer',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Autocomplete<Farmer>(
                        optionsBuilder: (textEditingValue) {
                          final query = textEditingValue.text.trim().toLowerCase();
                          if (query.isEmpty) {
                            return const Iterable<Farmer>.empty();
                          }
                          return farmers.where((farmer) {
                            return farmer.no.toLowerCase().contains(query) ||
                                farmer.name.toLowerCase().contains(query);
                          });
                        },
                        displayStringForOption: (farmer) => farmer.no,
                        onSelected: (farmer) {
                          setState(() {
                            _farmerNumber = farmer.no;
                            _farmerName = farmer.name;
                            _factory = farmer.factory;
                          });
                        },
                        fieldViewBuilder:
                            (
                              context,
                              textEditingController,
                              focusNode,
                              onFieldSubmitted,
                            ) {
                              if (_farmerNumber.isNotEmpty &&
                                  textEditingController.text != _farmerNumber) {
                                textEditingController.text = _farmerNumber;
                              }
                              return TextFormField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                onChanged: (value) {
                                  setState(() {
                                    _farmerNumber = value;
                                  });
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Farmer Number',
                                  hintText: 'Search by farmer number or name',
                                  prefixIcon: Icon(Icons.search),
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
                              borderRadius: BorderRadius.circular(16),
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width - 32,
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
                                      trailing: farmer.factory.trim().isEmpty
                                          ? null
                                          : Text(farmer.factory),
                                      onTap: () => onSelected(farmer),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      if (_farmerName.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _farmerName,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_factory.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('Factory: $_factory'),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: colors.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Weight & Bags',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _scaleStatus == 'Connected'
                                  ? colors.tertiaryContainer
                                  : colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _scaleStatus,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _isConnectingScale ? null : _connectScale,
                        icon: const Icon(Icons.bluetooth_connected),
                        label: Text(
                          _isConnectingScale ? 'Connecting Scale...' : 'Connect Scale',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _kgController,
                              decoration: const InputDecoration(
                                labelText: 'Kg Collected',
                                hintText: '0.00',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
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
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _bagsController,
                              decoration: const InputDecoration(
                                labelText: 'No of Bags',
                                hintText: '0',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                final trimmed = value?.trim() ?? '';
                                if (trimmed.isEmpty) {
                                  return 'Enter bags';
                                }
                                final parsed = int.tryParse(trimmed);
                                if (parsed == null) {
                                  return 'Whole number only';
                                }
                                if (parsed < 0) {
                                  return 'Cannot be negative';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_farmerNumber.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Previous deliveries',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (latestCollection != null)
                          Text(
                            'Latest: ${latestCollection.kgCollected ?? 0} kg on ${_formatShortDate(latestCollection.collectionTime ?? latestCollection.collectionsDate)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        const SizedBox(height: 12),
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
                              final timestamp = item.collectionTime ?? item.collectionsDate;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: colors.secondaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.scale_outlined),
                                ),
                                title: Text(
                                  '${item.kgCollected ?? 0} kg • ${item.noOfBags ?? 0} bags',
                                ),
                                subtitle: Text(
                                  '${_formatShortDate(timestamp)} • ${item.collectionNumber}',
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Saving...' : 'Save Collection'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
