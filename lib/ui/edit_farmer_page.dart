import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/farmer_model.dart';
import '../data/farmer_repository.dart';
import 'brand_logo.dart';

class EditFarmerPage extends StatefulWidget {
  const EditFarmerPage({super.key, required this.farmer});

  final Farmer farmer;

  @override
  State<EditFarmerPage> createState() => _EditFarmerPageState();
}

class _EditFarmerPageState extends State<EditFarmerPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _noController;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _idNoController;
  late final TextEditingController _bankController;
  late final TextEditingController _bankAccountController;
  late final TextEditingController _acreageController;
  late final TextEditingController _noOfTreesController;
  String? _selectedFactory;
  bool _multipleDelivery = false;
  bool? _gender;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _noController = TextEditingController(text: widget.farmer.no);
    _nameController = TextEditingController(text: widget.farmer.name);
    _phoneController = TextEditingController(text: widget.farmer.phone);
    _emailController = TextEditingController(text: widget.farmer.email);
    _idNoController = TextEditingController(text: widget.farmer.idNo);
    _selectedFactory = widget.farmer.factory.trim().isEmpty
        ? null
        : widget.farmer.factory.trim();
    _bankController = TextEditingController(text: widget.farmer.bank);
    _bankAccountController = TextEditingController(
      text: widget.farmer.bankAccount,
    );
    _acreageController = TextEditingController(
      text: widget.farmer.acreage?.toString() ?? '',
    );
    _noOfTreesController = TextEditingController(
      text: widget.farmer.noOfTrees?.toString() ?? '',
    );
    _multipleDelivery = widget.farmer.multipleDelivery ?? false;
    _gender = widget.farmer.gender;
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final updated = widget.farmer.copyWith(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      idNo: _idNoController.text.trim(),
      factory: _selectedFactory?.trim() ?? '',
      gender: _gender,
      bank: _bankController.text.trim(),
      bankAccount: _bankAccountController.text.trim(),
      multipleDelivery: _multipleDelivery,
      acreage: _toDouble(_acreageController),
      noOfTrees: _toInt(_noOfTreesController),
    );

    final result = await context.read<FarmerRepository>().updateFarmer(updated);

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.syncedToBc
              ? 'Changes saved locally and synced to BC.'
              : 'Changes saved locally. Marked for BC sync when connection is available.',
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
        title: BrandedAppBarTitle(widget.farmer.no),
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
            colors: [Color(0xFFF5F3FF), Color(0xFFFFFFFF)],
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
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Farmer No',
                        ),
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
                            : const Text('Save Changes'),
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
