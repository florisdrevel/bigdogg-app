import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    final result = await AuthService.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
    setState(() { _loading = false; });
    if (result['success']) {
      if (mounted) context.go('/dashboard');
    } else {
      setState(() { _error = result['message']; });
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
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      Image.asset('assets/images/logo.png', width: 280, height: 280),
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
                                'Welcome back',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? BigDoggTheme.darkTextPrimary : BigDoggTheme.lightTextPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Sign in to your account',
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
                                controller: _emailController,
                                decoration: const InputDecoration(labelText: 'Email address'),
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _passwordController,
                                decoration: const InputDecoration(labelText: 'Password'),
                                obscureText: true,
                                onSubmitted: (_) => _login(),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _login,
                                  child: _loading
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Text('Sign in'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Center(
                                child: TextButton(
                                  onPressed: () => context.go('/register'),
                                  child: const Text("Don't have an account? Sign up"),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
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