import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/farmer_model.dart';
import '../data/farmer_repository.dart';
import '../data/store_models.dart';
import '../data/store_repository.dart';
import '../data/user_repository.dart';
import '../services/bc/bc_settings_store.dart';
import '../services/bluetooth_printer_service.dart';
import '../services/session_store.dart';
import 'brand_logo.dart';
import 'store_lines_page.dart';

class AddStoreHeaderPage extends StatefulWidget {
  const AddStoreHeaderPage({super.key});

  @override
  State<AddStoreHeaderPage> createState() => _AddStoreHeaderPageState();
}

class _AddStoreHeaderPageState extends State<AddStoreHeaderPage> {
  static final _random = Random();
  final _formKey = GlobalKey<FormState>();
  final _clientController = TextEditingController();
  final _entryController = TextEditingController();
  final _collectorController = TextEditingController();
  final _collectorNoController = TextEditingController();
  final _factoryController = TextEditingController();
  final _totalController = TextEditingController();
  final _amountPaidController = TextEditingController();
  final _commentsController = TextEditingController();

  bool _isSaving = false;
  bool _initializingDefaults = true;
  bool _loadingLines = false;
  List<Store> _lines = const [];
  Farmer? _selectedFarmer;

  @override
  void initState() {
    super.initState();
    _entryController.addListener(_onEntryChanged);
    _initializeDefaults();
  }

  void _onEntryChanged() {
    _loadLines();
  }

  Future<void> _initializeDefaults() async {
    final users = context.read<UserRepository>().users;
    final now = DateTime.now();
    final sessionUsername =
        (await SessionStore.instance.getCurrentUsername())?.trim() ?? '';
    final settings = await BcSettingsStore.instance.load();

    String collectorName = sessionUsername;
    if (sessionUsername.isNotEmpty) {
      final localUser = users.where((u) {
        return u.username.trim().toLowerCase() == sessionUsername.toLowerCase();
      }).firstOrNull;
      if (localUser != null && localUser.name.trim().isNotEmpty) {
        collectorName = localUser.name.trim();
      }
    }

    if (!mounted) return;
    setState(() {
      _entryController.text = _generateEntryNo(sessionUsername, now);
      _collectorController.text = collectorName;
      _collectorNoController.text = sessionUsername;
      _factoryController.text = settings.factory.trim();
      _totalController.text = '0.00';
      _initializingDefaults = false;
    });
  }

  String _generateEntryNo(String username, DateTime now) {
    final token = username.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    final userPart = (token.isEmpty ? 'USR' : token);
    final millis = now.millisecondsSinceEpoch;
    final suffix = _random.nextInt(1000).toString().padLeft(3, '0');
    return '$userPart-$millis$suffix';
  }

  @override
  void dispose() {
    _clientController.dispose();
    _entryController.dispose();
    _collectorController.dispose();
    _collectorNoController.dispose();
    _factoryController.dispose();
    _totalController.dispose();
    _amountPaidController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  double? _toDouble(String text) {
    final value = text.trim();
    if (value.isEmpty) return null;
    return double.tryParse(value);
  }

  double _linesTotal() {
    return _lines.fold<double>(0, (sum, line) {
      final lineTotal =
          line.lineTotal ?? ((line.amount ?? 0) * (line.quantity ?? 0));
      return sum + lineTotal;
    });
  }

  StoreHeader _buildDraftHeader({DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    final total = _linesTotal();
    final amountPaid = _toDouble(_amountPaidController.text);
    final balance = total - (amountPaid ?? 0);

    return StoreHeader(
      client: _clientController.text.trim(),
      date: timestamp,
      entry: _entryController.text.trim(),
      total: total,
      posted: false,
      paymode: null,
      amountPaid: amountPaid,
      balance: balance,
      limit: null,
      stores: null,
      limitAvailable: null,
      collector: _collectorController.text.trim(),
      collectorNo: _collectorNoController.text.trim(),
      memberName: (_selectedFarmer?.name.trim().isNotEmpty ?? false)
          ? _selectedFarmer!.name.trim()
          : _clientController.text.trim(),
      collectorIsMember: null,
      mpesaCode: '',
      mpesaNo: '',
      mpesaName: '',
      cropYear: timestamp.year.toString(),
      factory: _factoryController.text.trim(),
      factoryName: _factoryController.text.trim(),
      servedBy: '',
      sent: false,
      creditAmount: null,
      comments: _commentsController.text.trim(),
      reversed: false,
      itemCount: _lines.length,
    );
  }

  Future<void> _loadLines() async {
    final entry = _entryController.text.trim();
    if (entry.isEmpty) {
      if (!mounted) return;
      setState(() {
        _lines = const [];
        _totalController.text = '0.00';
      });
      return;
    }

    setState(() {
      _loadingLines = true;
    });

    final loaded = await context.read<StoreRepository>().loadStoreLines(entry);
    if (!mounted) return;

    setState(() {
      _lines = loaded;
      _loadingLines = false;
      _totalController.text = _linesTotal().toStringAsFixed(2);
    });
  }

  Future<void> _openAddEditLines() async {
    final entry = _entryController.text.trim();
    final client = _clientController.text.trim();
    final factory = _factoryController.text.trim();

    if (entry.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter entry first.')));
      return;
    }
    if (client.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter farmer first.')));
      return;
    }
    if (factory.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter factory first.')));
      return;
    }

    final draftHeader = _buildDraftHeader();
    await context.read<StoreRepository>().addStoreHeader(draftHeader);

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StoreLinesPage(header: draftHeader)),
    );

    if (!mounted) return;
    await _loadLines();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final header = _buildDraftHeader(now: DateTime.now());

    await context.read<StoreRepository>().addStoreHeader(header);

    String saveMessage;
    try {
      var connected = await BluetoothPrinterService.instance
          .isAttachedPrinterConnected();
      if (!connected) {
        connected = await BluetoothPrinterService.instance
            .connectAttachedPrinter();
      }

      if (connected) {
        await BluetoothPrinterService.instance.printStoresReceipt(
          header,
          _lines,
        );
        saveMessage = 'Store header saved and stores receipt sent to printer.';
      } else {
        saveMessage =
            'Store header saved. Attach a printer to print the stores receipt.';
      }
    } catch (_) {
      saveMessage =
          'Store header saved, but printing the stores receipt failed.';
    }

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(saveMessage)));

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final farmers = context.watch<FarmerRepository>().farmers;

    return Scaffold(
      appBar: AppBar(
        title: const BrandedAppBarTitle('Add Store Header'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_initializingDefaults)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Autocomplete<Farmer>(
                  initialValue: TextEditingValue(text: _clientController.text),
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
                    setState(() {
                      _selectedFarmer = farmer;
                    });
                    _clientController.text = farmer.no;
                  },
                  fieldViewBuilder:
                      (
                        context,
                        textEditingController,
                        focusNode,
                        onFieldSubmitted,
                      ) {
                        if (textEditingController.text !=
                            _clientController.text) {
                          textEditingController.text = _clientController.text;
                          textEditingController.selection =
                              TextSelection.fromPosition(
                                TextPosition(
                                  offset: textEditingController.text.length,
                                ),
                              );
                        }

                        return TextFormField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Farmer Number',
                            hintText: 'Search by farmer number or name',
                          ),
                          onChanged: (value) {
                            _clientController.text = value;
                            final selected = _selectedFarmer;
                            if (selected != null &&
                                selected.no.toLowerCase() !=
                                    value.trim().toLowerCase()) {
                              setState(() {
                                _selectedFarmer = null;
                              });
                            }
                          },
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
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
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
              TextFormField(
                controller: _amountPaidController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Amount Paid'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _commentsController,
                decoration: const InputDecoration(labelText: 'Comments'),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Lines',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openAddEditLines,
                    icon: const Icon(Icons.playlist_add_outlined),
                    label: const Text('Add/Edit Lines'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_loadingLines)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_lines.isEmpty)
                const Text('No lines yet.')
              else
                Column(
                  children: _lines
                      .map(
                        (line) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          child: ListTile(
                            dense: true,
                            title: Text(line.item),
                            subtitle: Text(
                              'Qty ${(line.quantity ?? 0).toStringAsFixed(2)} • Amount ${(line.amount ?? 0).toStringAsFixed(2)}',
                            ),
                            trailing: Text(
                              (line.lineTotal ?? 0).toStringAsFixed(2),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Store Header'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Summary',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SizedBox(
                      width: 180,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _entryController,
                        builder: (context, value, _) {
                          return Text(
                            value.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 180,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _collectorController,
                        builder: (context, value, _) {
                          return Text(
                            value.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 180,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _factoryController,
                        builder: (context, value, _) {
                          return Text(
                            value.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 140,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _totalController,
                        builder: (context, value, _) {
                          return Text(
                            value.text,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
