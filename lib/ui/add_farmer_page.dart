import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/farmer_model.dart';
import '../data/farmer_repository.dart';
import '../services/bc/bc_settings_store.dart';
import 'brand_logo.dart';

class AddFarmerPage extends StatefulWidget {
  const AddFarmerPage({super.key});

  @override
  State<AddFarmerPage> createState() => _AddFarmerPageState();
}

class _AddFarmerPageState extends State<AddFarmerPage> {
  final _formKey = GlobalKey<FormState>();
  final _noController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _idNoController = TextEditingController();
  final _bankController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _acreageController = TextEditingController();
  final _noOfTreesController = TextEditingController();
  String? _selectedFactory;
  bool _multipleDelivery = false;
  bool? _gender;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadDefaultFactory();
  }

  Future<void> _loadDefaultFactory() async {
    final settings = await BcSettingsStore.instance.load();
    final defaultFactory = settings.factory.trim();
    if (!mounted || defaultFactory.isEmpty) {
      return;
    }
    setState(() {
      _selectedFactory = defaultFactory;
    });
  }

  @override
  void dispose() {
    _noController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _idNoController.dispose();
    _bankController.dispose();
    _bankAccountController.dispose();
    _acreageController.dispose();
    _noOfTreesController.dispose();
    super.dispose();
  }

  double? _toDouble(TextEditingController controller) {
    final value = controller.text.trim();
    if (value.isEmpty) return null;
    return double.tryParse(value);
  }

  int? _toInt(TextEditingController controller) {
    final value = controller.text.trim();
    if (value.isEmpty) return null;
    return int.tryParse(value);
  }

  bool _isDuplicateFarmerNo() {
    return context.read<FarmerRepository>().hasFarmerNo(_noController.text);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if ((_selectedFactory ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a factory before saving.')),
      );
      return;
    }

    if (_isDuplicateFarmerNo()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Farmer number already exists.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final farmer = Farmer(
      no: _noController.text.trim(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      idNo: _idNoController.text.trim(),
      cumCherry: null,
      cumMbuni: null,
      updated: false,
      accountCategory: null,
      factory: _selectedFactory?.trim() ?? '',
      comments: '',
      gender: _gender,
      bank: _bankController.text.trim(),
      bankAccount: _bankAccountController.text.trim(),
      multipleDelivery: _multipleDelivery,
      acreage: _toDouble(_acreageController),
      noOfTrees: _toInt(_noOfTreesController),
      otherLoans: null,
      previousCropCollection: null,
      limitPercentage: null,
      limit: null,
      totalStores: null,
      currentCropCollectionCherry1: null,
      currentCropCollectionCherry2: null,
      currentCropCollection: null,
      bankCode: '',
      bankName: '',
    );

    final result = await context.read<FarmerRepository>().addFarmer(farmer);

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });

    if (!result.savedLocally) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.syncError ?? 'Unable to save farmer.')),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.syncedToBc
              ? 'Farmer saved and synced to BC.'
              : 'Farmer saved locally. Marked for BC sync when connection is available.',
        ),
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final farmers = context.watch<FarmerRepository>().farmers;
    final factoryOptions = <String>{
      for (final farmer in farmers)
        if (farmer.factory.trim().isNotEmpty) farmer.factory.trim(),
      if ((_selectedFactory ?? '').trim().isNotEmpty) _selectedFactory!.trim(),
    }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const BrandedAppBarTitle('Add Farmer'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back to home',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/farmers', (route) => false);
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF0FDFA), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                  decoration: BoxDecoration(
                    color: colors.surface.withAlpha(240),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colors.outlineVariant),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _noController,
                        decoration: const InputDecoration(
                          labelText: 'Farmer No',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter farmer number';
                          }
                          if (context.read<FarmerRepository>().hasFarmerNo(
                            value,
                          )) {
                            return 'Farmer number already exists';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
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
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter phone';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<bool?>(
                              value: _gender,
                              decoration: const InputDecoration(
                                labelText: 'Gender',
                              ),
                              items: const [
                                DropdownMenuItem<bool?>(
                                  value: null,
                                  child: Text('Not set'),
                                ),
                                DropdownMenuItem<bool?>(
                                  value: true,
                                  child: Text('Male'),
                                ),
                                DropdownMenuItem<bool?>(
                                  value: false,
                                  child: Text('Female'),
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _gender = value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                final email = value?.trim() ?? '';
                                if (email.isNotEmpty && !email.contains('@')) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _idNoController,
                              decoration: const InputDecoration(
                                labelText: 'ID No',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter ID No';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: (_selectedFactory ?? '').isEmpty
                                  ? null
                                  : _selectedFactory,
                              decoration: const InputDecoration(
                                labelText: 'Factory',
                              ),
                              items: factoryOptions
                                  .map(
                                    (factory) => DropdownMenuItem<String>(
                                      value: factory,
                                      child: Text(factory),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedFactory = value;
                                });
                              },
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Select factory';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SwitchListTile.adaptive(
                              title: const Text('Multiple delivery'),
                              contentPadding: EdgeInsets.zero,
                              value: _multipleDelivery,
                              onChanged: (value) =>
                                  setState(() => _multipleDelivery = value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _bankController,
                        decoration: const InputDecoration(labelText: 'Bank'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _bankAccountController,
                        decoration: const InputDecoration(
                          labelText: 'Bank Account',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _acreageController,
                              decoration: const InputDecoration(
                                labelText: 'Acreage',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _noOfTreesController,
                              decoration: const InputDecoration(
                                labelText: 'No of Trees',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _isSaving ? null : _save,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save Farmer'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
