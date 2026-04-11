import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isNl = true;
  String? _error;

  String t(String nl, String en) => _isNl ? nl : en;

  Future<void> _register() async {
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = t('Wachtwoorden komen niet overeen', 'Passwords do not match'));
      return;
    }
    setState(() { _loading = true; _error = null; });
    final result = await AuthService.register(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _nameController.text.trim(),
    );
    setState(() => _loading = false);
    if (result['success']) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(t('Bevestig je e-mail', 'Confirm your email')),
            content: Text(t(
              'We hebben een bevestigingsmail gestuurd naar ${_emailController.text.trim()}. Klik op de link om je account te activeren.',
              'We sent a confirmation email to ${_emailController.text.trim()}. Click the link to activate your account.',
            )),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/login');
                },
                child: Text(t('Naar inloggen', 'Go to login')),
              ),
            ],
          ),
        );
      }
    } else {
      setState(() => _error = result['message']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            left: 0, top: 0, bottom: 0, width: 5,
            child: Container(color: BigDoggTheme.gold500),
          ),
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    // Language toggle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _isNl = !_isNl),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: BigDoggTheme.gold500.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: BigDoggTheme.gold500.withOpacity(0.4)),
                              ),
                              child: Text(
                                _isNl ? 'EN' : 'NL',
                                style: const TextStyle(color: BigDoggTheme.gold600, fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Image.asset('assets/images/logo.png', width: 160, height: 160),
                    const SizedBox(height: 12),
                    Container(
                      width: 420,
                      constraints: const BoxConstraints(maxWidth: 420),
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: isDark ? BigDoggTheme.darkSurface : BigDoggTheme.lightSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? BigDoggTheme.darkBorder : BigDoggTheme.lightBorder,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                            blurRadius: 32,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t('Account aanmaken', 'Create your account'),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: isDark ? BigDoggTheme.darkTextPrimary : BigDoggTheme.lightTextPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t('30 dagen gratis proberen', 'Start your 30-day free trial'),
                              style: TextStyle(
                                color: isDark ? BigDoggTheme.darkTextSecondary : BigDoggTheme.lightTextSecondary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (_error != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: BigDoggTheme.errorBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(_error!, style: const TextStyle(color: BigDoggTheme.error, fontSize: 13)),
                              ),
                            TextField(
                              controller: _nameController,
                              decoration: InputDecoration(labelText: t('Volledige naam', 'Full name')),
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _emailController,
                              decoration: const InputDecoration(labelText: 'Email'),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: t('Wachtwoord', 'Password'),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: BigDoggTheme.lightTextSecondary,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _confirmController,
                              decoration: InputDecoration(
                                labelText: t('Wachtwoord bevestigen', 'Confirm password'),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: BigDoggTheme.lightTextSecondary,
                                  ),
                                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                ),
                              ),
                              obscureText: _obscureConfirm,
                              onSubmitted: (_) => _register(),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _register,
                                child: _loading
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Text(t('Account aanmaken', 'Create account')),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton(
                                onPressed: () => context.go('/login'),
                                child: Text(t('Al een account? Inloggen', 'Already have an account? Sign in')),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}