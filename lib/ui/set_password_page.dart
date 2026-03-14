import 'package:flutter/material.dart';

class SetPasswordPage extends StatefulWidget {
  const SetPasswordPage({super.key, required this.username});

  final String username;

  @override
  State<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends State<SetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _pass1 = TextEditingController();
  final _pass2 = TextEditingController();

  bool _hide1 = true;
  bool _hide2 = true;

  @override
  void dispose() {
    _pass1.dispose();
    _pass2.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_pass1.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set password'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create a password for "${widget.username}".',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _pass1,
                      obscureText: _hide1,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        suffixIcon: IconButton(
                          tooltip: _hide1 ? 'Show' : 'Hide',
                          icon: Icon(
                            _hide1
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _hide1 = !_hide1;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        final v = (value ?? '');
                        if (v.isEmpty) return 'Enter a password';
                        if (v.length < 4) return 'Password too short';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pass2,
                      obscureText: _hide2,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Confirm password',
                        suffixIcon: IconButton(
                          tooltip: _hide2 ? 'Show' : 'Hide',
                          icon: Icon(
                            _hide2
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _hide2 = !_hide2;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        final v = value ?? '';
                        if (v.isEmpty) return 'Confirm password';
                        if (v != _pass1.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _submit,
                      child: const Text('Save password'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
