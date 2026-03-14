import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/store_models.dart';
import '../data/store_repository.dart';
import 'brand_logo.dart';

class AddStoreLinePage extends StatefulWidget {
  const AddStoreLinePage({
    super.key,
    required this.entry,
    required this.client,
    required this.factory,
  });

  final String entry;
  final String client;
  final String factory;

  @override
  State<AddStoreLinePage> createState() => _AddStoreLinePageState();
}

class _AddStoreLinePageState extends State<AddStoreLinePage> {
  final _formKey = GlobalKey<FormState>();
  final _variantController = TextEditingController();
  final _quantityController = TextEditingController();
  final _amountController = TextEditingController();
  final _statusController = TextEditingController(text: 'Open');
  final _stockController = TextEditingController();
  final _cropController = TextEditingController();
  final _commentsController = TextEditingController();
  String? _selectedItemNo;
  List<Item> _items = const [];

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final repo = context.read<StoreRepository>();
    await repo.loadItems();
    final loaded = repo.items;
    if (!mounted) return;
    setState(() {
      _items = loaded;
      if (_selectedItemNo == null && loaded.isNotEmpty) {
        _selectedItemNo = loaded.first.no;
        _amountController.text = (loaded.first.unitPrice ?? 0).toStringAsFixed(2);
      }
    });
  }

  @override
  void dispose() {
    _variantController.dispose();
    _quantityController.dispose();
    _amountController.dispose();
    _statusController.dispose();
    _stockController.dispose();
    _cropController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  double? _toDouble(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
    });

    final quantity = _toDouble(_quantityController.text) ?? 0;
    final amount = _toDouble(_amountController.text) ?? 0;
    final now = DateTime.now();

    final line = Store(
      entry: widget.entry,
      client: widget.client,
      item: _selectedItemNo ?? '',
      variant: _variantController.text.trim(),
      amount: amount,
      quantity: quantity,
      time: now,
      date: now,
      servedBy: '',
      status: _statusController.text.trim(),
      factory: widget.factory,
      sent: false,
      comments: _commentsController.text.trim(),
      lineTotal: quantity * amount,
      stock: _stockController.text.trim(),
      crop: _cropController.text.trim(),
      balance: null,
      paymode: null,
      amountPaid: null,
    );

    await context.read<StoreRepository>().addStoreLineAndUpdateHeader(line);

    if (!mounted) return;
    setState(() {
      _saving = false;
    });

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandedAppBarTitle('Add Store Line'),
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
            padding: const EdgeInsets.all(20),
            children: [
              Text('Entry: ${widget.entry}'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedItemNo,
                items: _items
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.no,
                        child: Text('${item.no} • ${item.description}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedItemNo = value;
                    final selected = _items.where((x) => x.no == value).firstOrNull;
                    if (selected != null && (_amountController.text.trim().isEmpty || _amountController.text.trim() == '0')) {
                      _amountController.text = (selected.unitPrice ?? 0).toStringAsFixed(2);
                    }
                  });
                },
                decoration: const InputDecoration(labelText: 'Item'),
                validator: (value) {
                  if (_items.isEmpty) {
                    return 'No item master data found';
                  }
                  if (value == null || value.trim().isEmpty) {
                    return 'Select item';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _variantController,
                decoration: const InputDecoration(labelText: 'Variant'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Quantity'),
                validator: (value) {
                  final number = _toDouble(value ?? '');
                  if (number == null) return 'Enter quantity';
                  if (number <= 0) return 'Quantity must be greater than 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount'),
                validator: (value) {
                  final number = _toDouble(value ?? '');
                  if (number == null) return 'Enter amount';
                  if (number < 0) return 'Amount cannot be negative';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _statusController,
                decoration: const InputDecoration(labelText: 'Status'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stockController,
                decoration: const InputDecoration(labelText: 'Stock'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cropController,
                decoration: const InputDecoration(labelText: 'Crop'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _commentsController,
                decoration: const InputDecoration(labelText: 'Comments'),
                minLines: 2,
                maxLines: 4,
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
                    : const Text('Save Store Line'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
