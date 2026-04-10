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
  String? _error;

  Future<void> _register() async {
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'Passwords do not match');
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
      if (mounted) context.go('/dashboard');
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo.png', width: 180, height: 180),
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
                          'Create your account',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: isDark ? BigDoggTheme.darkTextPrimary : BigDoggTheme.lightTextPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Start your 14-day free trial',
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
                          decoration: const InputDecoration(labelText: 'Full name'),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(labelText: 'Email address'),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passwordController,
                          decoration: const InputDecoration(labelText: 'Password'),
                          obscureText: true,
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _confirmController,
                          decoration: const InputDecoration(labelText: 'Confirm password'),
                          obscureText: true,
                          onSubmitted: (_) => _register(),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _register,
                            child: _loading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Create account'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: () => context.go('/login'),
                            child: const Text('Already have an account? Sign in'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}