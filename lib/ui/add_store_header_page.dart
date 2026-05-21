import 'dart:async';
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
import '../services/collection_settings_service.dart';
import '../services/session_store.dart';
import 'brand_logo.dart';

String _formatAmount(num? value, {int decimalPlaces = 2}) {
  final fixed = (value ?? 0).toStringAsFixed(decimalPlaces);
  final parts = fixed.split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
  if (parts.length == 1) return whole;
  return '$whole.${parts[1]}';
}

String _displayItemLabel(Store line) {
  final description = line.itemDescription.trim();
  if (description.isNotEmpty) return description;
  return line.item;
}

class AddStoreHeaderPage extends StatefulWidget {
  const AddStoreHeaderPage({super.key, this.initialHeader});

  final StoreHeader? initialHeader;

  @override
  State<AddStoreHeaderPage> createState() => _AddStoreHeaderPageState();
}

class _AddStoreHeaderPageState extends State<AddStoreHeaderPage> {
  static const int _cashPaymode = 0;
  static const int _creditPaymode = 1;
  static final _random = Random();
  final _formKey = GlobalKey<FormState>();
  final _clientController = TextEditingController();
  final _clientFocusNode = FocusNode();
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
  int? _selectedPaymode;
  String _bcCompanyName = '';

  bool get _isEditing => widget.initialHeader != null;
  bool get _isPostedHeader => widget.initialHeader?.posted == true;
  bool get _isReadOnly => _isEditing && _isPostedHeader;

  @override
  void initState() {
    super.initState();
    _entryController.addListener(_onEntryChanged);
    _initializeForm();
  }

  void _onEntryChanged() {
    if (!mounted) return;
    _loadLines();
  }

  Future<void> _initializeForm() async {
    final users = context.read<UserRepository>().users;
    final settings = await BcSettingsStore.instance.load();
    final bcCompanyName = settings.company.trim();

    if (_isEditing) {
      final header = widget.initialHeader!;
      if (!mounted) return;
      setState(() {
        _bcCompanyName = bcCompanyName;
        _clientController.text = header.client;
        _entryController.text = header.entry;
        _collectorController.text = header.collector;
        _collectorNoController.text = header.collectorNo;
        _factoryController.text = header.factory.trim().isNotEmpty
            ? header.factory
            : header.factoryName;
        _totalController.text = (header.total ?? 0).toStringAsFixed(2);
        _selectedPaymode = header.paymode;
        _amountPaidController.text =
            header.amountPaid?.toStringAsFixed(2) ?? '';
        _commentsController.text = header.comments;
        _initializingDefaults = false;
      });
      await _loadLines();
      return;
    }

    final now = DateTime.now();
    final sessionUsername =
        (await SessionStore.instance.getCurrentUsername())?.trim() ?? '';

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
      _bcCompanyName = bcCompanyName;
      _entryController.text = _generateEntryNo(sessionUsername, now);
      _collectorController.text = collectorName;
      _collectorNoController.text = sessionUsername;
      _factoryController.text = settings.factory.trim().isNotEmpty
          ? settings.factory.trim()
          : bcCompanyName;
      _totalController.text = '0.00';
      _selectedPaymode = null;
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
    _entryController.removeListener(_onEntryChanged);
    _clientFocusNode.dispose();
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
      return sum + (line.amount ?? 0);
    });
  }

  void _onPaymodeChanged(int? value) {
    setState(() {
      _selectedPaymode = value;
      if (value == _creditPaymode) {
        _amountPaidController.text = '0.00';
      }
    });
  }

  String? _validateAmountPaid(String? value) {
    final amountPaid = _toDouble(value ?? '');
    if (_selectedPaymode == _creditPaymode) {
      return null;
    }
    if (amountPaid == null) {
      return 'Enter amount paid';
    }
    if (amountPaid < 0) {
      return 'Amount paid cannot be negative';
    }

    final total = _linesTotal();
    if (_selectedPaymode == _cashPaymode && amountPaid < total) {
      return 'Amount paid must be equal to or greater than Total';
    }

    return null;
  }

  StoreHeader _buildDraftHeader({DateTime? now}) {
    final timestamp = now ?? widget.initialHeader?.date ?? DateTime.now();
    final total = _linesTotal();
    final paymode = _selectedPaymode;
    final amountPaid = _toDouble(_amountPaidController.text);
    final balance = total - (amountPaid ?? 0);
    final factoryLabel = _factoryController.text.trim();
    final companyName = _bcCompanyName.trim();

    return StoreHeader(
      id: widget.initialHeader?.id,
      client: _clientController.text.trim(),
      date: timestamp,
      entry: _entryController.text.trim(),
      total: total,
      posted: false,
      paymode: paymode,
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
      factory: factoryLabel,
      factoryName: factoryLabel.isNotEmpty ? factoryLabel : companyName,
      servedBy: '',
      sent: false,
      creditAmount: null,
      comments: _commentsController.text.trim(),
      reversed: false,
      itemCount: _lines.length,
    );
  }

  Future<void> _loadLines() async {
    if (!mounted) return;
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

    try {
      final loaded = await context.read<StoreRepository>().loadStoreLines(
        entry,
      );
      if (!mounted) return;

      setState(() {
        _lines = loaded;
        _loadingLines = false;
        _totalController.text = _linesTotal().toStringAsFixed(2);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingLines = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load store lines.')),
      );
    }
  }

  Future<void> _editLineFromList(Store line) async {
    if (_isReadOnly) return;

    final repo = context.read<StoreRepository>();
    await repo.loadItems();
    final items = repo.items;

    if (!mounted) return;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No item master data found.')),
      );
      return;
    }

    final draft = await showDialog<_StoreLineDraft>(
      context: context,
      builder: (dialogContext) {
        return _StoreLineFormDialog(items: items, initialLine: line);
      },
    );

    if (draft == null || !mounted) return;

    final selectedItem = items
        .where((item) => item.no == draft.item)
        .firstOrNull;

    final updated = line.copyWith(
      item: draft.item,
      itemDescription: selectedItem?.description ?? line.itemDescription,
      variant: draft.variant,
      amount: draft.amount,
      quantity: draft.quantity,
      status: draft.status,
      stock: draft.stock,
      crop: draft.crop,
      comments: draft.comments,
      lineTotal: draft.amount,
    );

    await repo.updateStore(updated);
    await _loadLines();
  }

  Future<void> _removeLineFromList(Store line) async {
    if (_isReadOnly) return;

    final id = line.id;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove item?'),
          content: const Text('This line item will be removed.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await context.read<StoreRepository>().deleteStore(
      id: id,
      entry: line.entry,
    );
    await _loadLines();
  }

  Future<void> _save() async {
    if (_isReadOnly) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      if (!_isEditing) {
        final settings = await BcSettingsStore.instance.load();
        final liveFactory = settings.factory.trim();
        if (liveFactory.isNotEmpty) {
          _factoryController.text = liveFactory;
        }
      }

      final header = _buildDraftHeader(now: _isEditing ? null : DateTime.now());

      if (_isEditing) {
        await context.read<StoreRepository>().updateStoreHeader(header);
      } else {
        await context.read<StoreRepository>().addStoreHeader(header);
      }

      final saveMessage = _isEditing
          ? 'Store header updated locally.'
          : 'Store header saved locally.';

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(saveMessage)));

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      final action = _isEditing ? 'update' : 'save';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to $action store header.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _postHeader() async {
    if (!_isEditing || _isReadOnly || _isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPaymode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a paymode before posting.')),
      );
      return;
    }
    if (_loadingLines) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for lines to finish loading.'),
        ),
      );
      return;
    }
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one line before posting.')),
      );
      return;
    }

    final invalidIndex = _lines.indexWhere(
      (line) =>
          (line.quantity == null || line.quantity! <= 0) ||
          (line.amount == null || line.amount! <= 0),
    );
    if (invalidIndex != -1) {
      final invalidLine = _lines[invalidIndex];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Line "${_displayItemLabel(invalidLine)}" must have quantity and amount greater than 0 before posting.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final header = _buildDraftHeader().copyWith(posted: true);
      await context.read<StoreRepository>().updateStoreHeader(header);

      String postMessage;
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
          postMessage =
              'Store header posted, locked, and stores receipt sent to printer.';
        } else {
          postMessage =
              'Store header posted and locked. Attach a printer to print the stores receipt.';
        }
      } catch (_) {
        postMessage =
            'Store header posted and locked, but printing the stores receipt failed.';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(postMessage)));

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to post store header.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmers = context.watch<FarmerRepository>().farmers;

    return Scaffold(
      appBar: AppBar(
        title: BrandedAppBarTitle(
          _isEditing
              ? (_isReadOnly ? 'Store Header (Posted)' : 'Edit Store Header')
              : 'Add Store Header',
        ),
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
                  textEditingController: _clientController,
                  focusNode: _clientFocusNode,
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
                        return TextFormField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          enabled: !_isReadOnly,
                          decoration: const InputDecoration(
                            labelText: 'Farmer Number',
                            hintText: 'Search by farmer number or name',
                          ),
                          onChanged: (value) {
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
              DropdownButtonFormField<int>(
                initialValue: _selectedPaymode,
                decoration: const InputDecoration(labelText: 'Paymode'),
                items: const [
                  DropdownMenuItem(value: _cashPaymode, child: Text('Cash')),
                  DropdownMenuItem(
                    value: _creditPaymode,
                    child: Text('Credit'),
                  ),
                ],
                onChanged: _isReadOnly
                    ? null
                    : (value) {
                        setState(() {
                          _onPaymodeChanged(value);
                        });
                      },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amountPaidController,
                      enabled:
                          !_isReadOnly && _selectedPaymode != _creditPaymode,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount Paid',
                      ),
                      validator: _validateAmountPaid,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _totalController,
                      readOnly: true,
                      decoration: const InputDecoration(labelText: 'Total'),
                    ),
                  ),
                ],
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
                    onPressed: _isReadOnly
                        ? null
                        : () async {
                            var entry = _entryController.text.trim();
                            final client = _clientController.text.trim();
                            final factory = _factoryController.text.trim();

                            if (entry.isEmpty) {
                              entry = _generateEntryNo(
                                _collectorNoController.text.trim(),
                                DateTime.now(),
                              );
                              _entryController.text = entry;
                            }

                            if (!mounted) return;
                            await showDialog<void>(
                              context: context,
                              builder: (dialogContext) {
                                return _StoreLinesEditorDialog(
                                  entry: entry,
                                  client: client,
                                  factory: factory,
                                  openNewLineDirectly: true,
                                );
                              },
                            );

                            if (!mounted) return;
                            await _loadLines();
                          },
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
                  children: _lines.asMap().entries.map((entry) {
                    final line = entry.value;
                    final scheme = Theme.of(context).colorScheme;
                    final quantity = line.quantity ?? 0;
                    final unitPrice = quantity > 0
                        ? (line.amount ?? 0) / quantity
                        : 0;
                    final total = _formatAmount(line.amount);
                    final itemLabel = _displayItemLabel(line);
                    final variant = line.variant.trim();
                    final lineDetails =
                        '${variant.isEmpty ? '' : '$variant • '}'
                        ' • Qty ${_formatAmount(line.quantity)}'
                        ' @ ${_formatAmount(unitPrice)}'
                        ' • Total $total';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 4),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: scheme.outline.withValues(alpha: 0.15),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _isReadOnly
                            ? null
                            : () => _editLineFromList(line),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                scheme.primary.withValues(alpha: 0.04),
                                scheme.surface,
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        itemLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        lineDetails,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove item',
                                  onPressed: _isReadOnly
                                      ? null
                                      : () => _removeLineFromList(line),
                                  icon: const Icon(Icons.delete_outline),
                                  iconSize: 18,
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: (_isSaving || _isReadOnly) ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _isEditing
                            ? 'Update Store Header'
                            : 'Save Store Header',
                      ),
              ),
              if (_isEditing && !_isReadOnly) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _postHeader,
                  icon: Icon(Icons.check_circle_outline),
                  label: const Text('Post Store Header'),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreLinesEditorDialog extends StatefulWidget {
  const _StoreLinesEditorDialog({
    required this.entry,
    required this.client,
    required this.factory,
    this.openNewLineDirectly = false,
  });

  final String entry;
  final String client;
  final String factory;
  final bool openNewLineDirectly;

  @override
  State<_StoreLinesEditorDialog> createState() =>
      _StoreLinesEditorDialogState();
}

class _StoreLinesEditorDialogState extends State<_StoreLinesEditorDialog> {
  bool _loading = true;
  String? _loadError;
  bool _openedDirectFlow = false;
  List<Store> _lines = const [];
  List<Item> _items = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final repo = context.read<StoreRepository>();
      await repo.loadItems().timeout(const Duration(seconds: 15));

      if (widget.openNewLineDirectly) {
        if (!mounted) return;
        setState(() {
          _items = repo.items;
          _lines = const [];
          _loading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _openDirectLineFlow();
        });
        return;
      }

      final lines = await repo
          .readStoresByEntry(widget.entry)
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      setState(() {
        _items = repo.items;
        _lines = lines;
        _loading = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Loading lines timed out. Please retry.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Failed to load lines. Please retry.';
      });
    }
  }

  Future<void> _openDirectLineFlow() async {
    if (!mounted || _loading || _openedDirectFlow || _loadError != null) {
      return;
    }

    _openedDirectFlow = true;

    await _openLineDetails();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openLineForm({Store? existing}) async {
    final draft = await showDialog<_StoreLineDraft>(
      context: context,
      builder: (dialogContext) {
        return _StoreLineFormDialog(items: _items, initialLine: existing);
      },
    );

    if (draft == null) return;
    if (!mounted) return;

    final repo = context.read<StoreRepository>();
    final now = DateTime.now();
    final selectedItem = _items
        .where((item) => item.no == draft.item)
        .firstOrNull;
    final line = Store(
      id: existing?.id,
      entry: widget.entry,
      client: widget.client,
      item: draft.item,
      itemDescription:
          selectedItem?.description ?? existing?.itemDescription ?? '',
      variant: draft.variant,
      amount: draft.amount,
      quantity: draft.quantity,
      time: existing?.time ?? now,
      date: existing?.date ?? now,
      servedBy: existing?.servedBy ?? '',
      status: draft.status,
      factory: widget.factory,
      sent: existing?.sent ?? false,
      comments: draft.comments,
      lineTotal: draft.quantity * draft.amount,
      stock: draft.stock,
      crop: draft.crop,
      balance: existing?.balance,
      paymode: existing?.paymode,
      amountPaid: existing?.amountPaid,
    );

    if (existing == null) {
      await repo.createStore(line);
    } else {
      await repo.updateStore(line);
    }

    if (widget.openNewLineDirectly) {
      return;
    }

    await _loadData();
  }

  Future<void> _deleteLine(Store line) async {
    final id = line.id;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete line?'),
          content: const Text(
            'This line item will be removed from this entry.',
          ),
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
    if (!mounted) return;

    await context.read<StoreRepository>().deleteStore(
      id: id,
      entry: widget.entry,
    );
    await _loadData();
  }

  Future<void> _openLineDetails([Store? line]) async {
    if (line == null) {
      await _openLineForm();
      return;
    }

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final quantity = line.quantity ?? 0;
        final unitPrice = quantity > 0 ? (line.amount ?? 0) / quantity : 0;
        return AlertDialog(
          title: const Text('Line item'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Item: ${_displayItemLabel(line)}'),
                  Text('Variant: ${line.variant}'),
                  Text('Quantity: ${_formatAmount(line.quantity)}'),
                  Text('@ ${_formatAmount(unitPrice)}'),
                  Text('Total: ${_formatAmount(line.amount)}'),
                  if (line.status.trim().isNotEmpty)
                    Text('Status: ${line.status}'),
                  if (line.stock.trim().isNotEmpty)
                    Text('Stock: ${line.stock}'),
                  if (line.crop.trim().isNotEmpty) Text('Crop: ${line.crop}'),
                  if (line.comments.trim().isNotEmpty)
                    Text('Comments: ${line.comments}'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('close'),
              child: const Text('Close'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop('edit'),
              child: const Text('Edit'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop('delete'),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (action == 'edit') {
      await _openLineForm(existing: line);
      return;
    }
    if (action == 'delete') {
      await _deleteLine(line);
    }
  }

  Future<void> _onLineMenuAction(String action, Store line) async {
    if (action == 'view') {
      await _openLineDetails(line);
      return;
    }
    if (action == 'edit') {
      await _openLineForm(existing: line);
      return;
    }
    if (action == 'delete') {
      await _deleteLine(line);
    }
  }

  Widget _buildLinesList({required bool isCompact}) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_lines.isEmpty) {
      return const Center(child: Text('No lines yet.'));
    }

    return ListView.separated(
      itemCount: _lines.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final line = _lines[index];
        final scheme = Theme.of(context).colorScheme;
        final quantity = line.quantity ?? 0;
        final unitPrice = quantity > 0 ? (line.amount ?? 0) / quantity : 0;
        final total = _formatAmount(line.amount);
        final variant = line.variant.trim();
        final lineText =
            '${_displayItemLabel(line)}'
            '${variant.isEmpty ? '' : ' • $variant'}'
            ' • Qty ${_formatAmount(line.quantity)}'
            ' @ ${_formatAmount(unitPrice)}'
            ' • Total $total';
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: scheme.outline.withValues(alpha: 0.15)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openLineDetails(line),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.secondary.withValues(alpha: 0.05),
                    scheme.surface,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 2, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        lineText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) => _onLineMenuAction(value, line),
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'view', child: Text('View')),
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final isCompact = media.width < 720;
    if (isCompact) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              'Edit Lines: ${widget.entry}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: _buildLinesList(isCompact: true),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _items.isEmpty ? null : () => _openLineForm(),
            icon: const Icon(Icons.add),
            label: const Text('Create line'),
          ),
        ),
      );
    }

    final horizontalInset = isCompact ? 8.0 : 16.0;
    final verticalInset = isCompact ? 12.0 : 24.0;
    final maxWidth = media.width - (horizontalInset * 2);
    final maxHeight = media.height - (verticalInset * 2);
    final dialogWidth = isCompact ? maxWidth : min(760.0, maxWidth);
    final dialogHeight = isCompact ? maxHeight : min(520.0, maxHeight);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: verticalInset,
      ),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Edit Lines: ${widget.entry}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _items.isEmpty ? null : () => _openLineForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Create line'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildLinesList(isCompact: false)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreLineDraft {
  const _StoreLineDraft({
    required this.item,
    required this.variant,
    required this.quantity,
    required this.amount,
    required this.status,
    required this.stock,
    required this.crop,
    required this.comments,
  });

  final String item;
  final String variant;
  final double quantity;
  final double amount;
  final String status;
  final String stock;
  final String crop;
  final String comments;
}

class _StoreLineFormDialog extends StatefulWidget {
  const _StoreLineFormDialog({required this.items, this.initialLine});

  final List<Item> items;
  final Store? initialLine;

  @override
  State<_StoreLineFormDialog> createState() => _StoreLineFormDialogState();
}

class _StoreLineFormDialogState extends State<_StoreLineFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantityController;
  final _quantityFocusNode = FocusNode();
  late final TextEditingController _amountController;
  String? _selectedItemNo;

  Item? get _selectedItem {
    return widget.items.where((item) => item.no == _selectedItemNo).firstOrNull;
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialLine;
    _quantityController = TextEditingController(
      text: initial == null ? '' : (initial.quantity ?? 0).toStringAsFixed(2),
    );
    _amountController = TextEditingController(
      text: initial == null ? '' : (initial.amount ?? 0).toStringAsFixed(2),
    );
    _quantityController.addListener(_updateAmount);

    if (initial != null) {
      _selectedItemNo = initial.item;
      _updateAmount();
    } else if (widget.items.isNotEmpty) {
      _selectedItemNo = widget.items.first.no;
      _updateAmount();
    }
  }

  void _updateAmount() {
    final quantity = _toDouble(_quantityController.text) ?? 0;
    final unitPrice = _selectedItem?.unitPrice ?? 0;
    final amount = quantity * unitPrice;
    _amountController.text = amount.toStringAsFixed(2);
  }

  void _prepareQuantityForSelectedItem() {
    _quantityController.text = '1';
    _updateAmount();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _quantityFocusNode.requestFocus();
      _quantityController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _quantityController.text.length,
      );
    });
  }

  @override
  void dispose() {
    _quantityController.removeListener(_updateAmount);
    _quantityFocusNode.dispose();
    _quantityController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  double? _toDouble(String text) {
    final value = text.trim();
    if (value.isEmpty) return null;
    return double.tryParse(value);
  }

  String _selectedItemLabel() {
    final selected = _selectedItem;
    if (selected == null) return 'Select item';
    return '${selected.no} • ${selected.description}';
  }

  Future<String?> _showItemSearchDialog() async {
    final searchController = TextEditingController();
    String query = '';

    final selectedNo = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final normalized = query.trim().toLowerCase();
            final filtered = widget.items.where((item) {
              if (normalized.isEmpty) return true;
              final no = item.no.toLowerCase();
              final description = item.description.toLowerCase();
              return no.contains(normalized) ||
                  description.contains(normalized);
            }).toList();

            return AlertDialog(
              title: const Text('Select item'),
              content: SizedBox(
                width: 520,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search item',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          query = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No matching items'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    '${item.no} • ${item.description}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    'Unit Price: ${(item.unitPrice ?? 0).toStringAsFixed(2)}',
                                  ),
                                  onTap: () =>
                                      Navigator.of(context).pop(item.no),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );

    searchController.dispose();
    return selectedNo;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final setup = await CollectionSettingsService.instance.load();

    Navigator.of(context).pop(
      _StoreLineDraft(
        item: _selectedItemNo ?? '',
        variant: '',
        quantity: _toDouble(_quantityController.text) ?? 0,
        amount: _toDouble(_amountController.text) ?? 0,
        status: 'Open',
        stock: '',
        crop: setup.crop.trim(),
        comments: '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialLine == null ? 'Add line item' : 'Edit line item',
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FormField<String>(
                  initialValue: _selectedItemNo,
                  validator: (value) {
                    if (widget.items.isEmpty) {
                      return 'No item master data found';
                    }
                    if ((value ?? '').trim().isEmpty) {
                      return 'Select item';
                    }
                    return null;
                  },
                  builder: (field) {
                    return InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Item',
                        errorText: field.errorText,
                        border: const OutlineInputBorder(),
                      ),
                      child: InkWell(
                        onTap: () async {
                          final value = await _showItemSearchDialog();
                          if (value == null || value.trim().isEmpty) return;
                          setState(() {
                            _selectedItemNo = value;
                          });
                          if (widget.initialLine == null) {
                            _prepareQuantityForSelectedItem();
                          } else {
                            _updateAmount();
                          }
                          field.didChange(value);
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedItemLabel(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.search),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (_selectedItem != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Unit Price: ${(_selectedItem!.unitPrice ?? 0).toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _quantityController,
                  focusNode: _quantityFocusNode,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  validator: (value) {
                    final number = _toDouble(value ?? '');
                    if (number == null) return 'Enter quantity';
                    if (number <= 0) return 'Quantity must be greater than 0';
                    return null;
                  },
                  onChanged: (_) => _updateAmount(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  readOnly: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount (Qty x Unit Price)',
                  ),
                  validator: (value) {
                    final number = _toDouble(value ?? '');
                    if (number == null) return 'Enter amount';
                    if (number < 0) return 'Amount cannot be negative';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
