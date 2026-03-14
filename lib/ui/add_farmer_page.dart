import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/farmer_model.dart';
import '../data/farmer_repository.dart';
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
  final _factoryController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _noController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _idNoController.dispose();
    _factoryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

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
      updated: null,
      accountCategory: null,
      factory: _factoryController.text.trim(),
      comments: '',
      gender: null,
      bank: '',
      bankAccount: '',
      acreage: null,
      noOfTrees: null,
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

    await context.read<FarmerRepository>().addFarmer(farmer);

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandedAppBarTitle('Add Farmer'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back to home',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/dashboard', (route) => false);
          },
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _noController,
                decoration: const InputDecoration(labelText: 'Farmer No'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter farmer number';
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
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter phone';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter email';
                  }
                  if (!value.contains('@')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _idNoController,
                decoration: const InputDecoration(labelText: 'ID No'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter ID No';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _factoryController,
                decoration: const InputDecoration(labelText: 'Factory'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter factory';
                  }
                  return null;
                },
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
                    : const Text('Save Farmer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
