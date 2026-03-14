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
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _idNoController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.farmer.phone);
    _emailController = TextEditingController(text: widget.farmer.email);
    _idNoController = TextEditingController(text: widget.farmer.idNo);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _idNoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final updated = widget.farmer.copyWith(
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      idNo: _idNoController.text.trim(),
    );

    await context.read<FarmerRepository>().updateFarmer(updated);

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
        title: const BrandedAppBarTitle('Update Farmer'),
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(widget.farmer.name),
                subtitle: Text(widget.farmer.no),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
