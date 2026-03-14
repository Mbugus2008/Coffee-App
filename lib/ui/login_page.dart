import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/user_repository.dart';
import '../services/session_store.dart';
import 'brand_logo.dart';
import 'set_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadLastUsername();
  }

  Future<void> _loadLastUsername() async {
    final lastUsername = await SessionStore.instance.getLastUsername();
    if (!mounted || lastUsername == null || lastUsername.isEmpty) {
      return;
    }
    _usernameController.text = lastUsername;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isSubmitting = true;
    });

    final repo = context.read<UserRepository>();
    final username = _usernameController.text.trim();
    final enteredPassword = _passwordController.text;

    final localUser = await repo.getLocalUserByUsername(username);
    if (!context.mounted) return;

    if (localUser == null) {
      setState(() {
        _isSubmitting = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Invalid username or password.')),
      );
      return;
    }

    final storedPassword = localUser.password.trim();
    if (storedPassword.isEmpty) {
      setState(() {
        _isSubmitting = false;
      });

      final newPassword = await navigator.push<String>(
        MaterialPageRoute(builder: (_) => SetPasswordPage(username: username)),
      );

      if (!context.mounted) return;
      final chosen = (newPassword ?? '');
      if (chosen.isEmpty) {
        return;
      }

      setState(() {
        _isSubmitting = true;
      });

      await repo.setPasswordLocal(username: username, password: chosen);
      _passwordController.text = chosen;

      if (!context.mounted) return;
      setState(() {
        _isSubmitting = false;
      });

      await SessionStore.instance.startSession(
        username: localUser.username,
        rememberMe: _rememberMe,
      );
      navigator.pushNamedAndRemoveUntil('/dashboard', (route) => false);
      return;
    }

    if (enteredPassword.isEmpty) {
      setState(() {
        _isSubmitting = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter your password.')),
      );
      return;
    }

    if (enteredPassword != storedPassword) {
      setState(() {
        _isSubmitting = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Invalid username or password.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    await SessionStore.instance.startSession(
      username: localUser.username,
      rememberMe: _rememberMe,
    );
    navigator.pushNamedAndRemoveUntil('/dashboard', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headlineStyle = GoogleFonts.playfairDisplay(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF3B2416),
    );
    final bodyStyle = GoogleFonts.manrope(
      fontSize: 15,
      color: const Color(0xFF5C4A3A),
    );

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                tooltip: 'Back to home',
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/dashboard', (route) => false);
                },
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF6E7DA),
                  Color(0xFFF1D1B5),
                  Color(0xFFE6B998),
                ],
              ),
            ),
          ),
          Positioned(
            top: -60,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8B5E3C).withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            bottom: -70,
            left: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3B2416).withValues(alpha: 0.12),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 550),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, (1 - value) * 24),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(child: const CoffeeBeanLogo(size: 72)),
                            const SizedBox(height: 16),
                            Text('Welcome back', style: headlineStyle),
                            const SizedBox(height: 8),
                            Text(
                              'Brewed for focus. Sign in to continue.',
                              style: bodyStyle,
                            ),
                            const SizedBox(height: 28),
                            TextFormField(
                              controller: _usernameController,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Username',
                                labelStyle: bodyStyle,
                                prefixIcon: const Icon(Icons.person_outline),
                                filled: true,
                                fillColor: const Color(0xFFF7EFE8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter your username';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                labelStyle: bodyStyle,
                                prefixIcon: const Icon(Icons.lock_outline),
                                filled: true,
                                fillColor: const Color(0xFFF7EFE8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                final v = value ?? '';
                                if (v.isEmpty) {
                                  // Allow empty so first-time users (or users
                                  // synced from BC without a password) can
                                  // trigger the password setup flow.
                                  return null;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            CheckboxListTile(
                              value: _rememberMe,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Remember me for today'),
                              subtitle: Text(
                                'Skips login until you logout or the day changes.',
                                style: bodyStyle.copyWith(fontSize: 13),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (value) {
                                setState(() {
                                  _rememberMe = value ?? false;
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B2416),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  textStyle: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: _isSubmitting ? null : _submit,
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Sign in'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.center,
                              child: Text(
                                'Offline-first. Syncs when you reconnect.',
                                style: bodyStyle.copyWith(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
