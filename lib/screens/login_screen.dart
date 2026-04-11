import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _obscurePassword = true;
  bool _isNl = true;
  String? _error;
  String? _resetMessage;

  String t(String nl, String en) => _isNl ? nl : en;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; _resetMessage = null; });
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

  Future<void> _forgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() => _error = t('Vul eerst je e-mailadres in', 'Please enter your email address first'));
      return;
    }
    setState(() { _loading = true; _error = null; _resetMessage = null; });
    final result = await AuthService.resetPassword(_emailController.text.trim());
    setState(() {
      _loading = false;
      if (result['success']) {
        _resetMessage = t(
          'Reset link verstuurd naar ${_emailController.text.trim()}',
          'Reset link sent to ${_emailController.text.trim()}',
        );
      } else {
        _error = result['message'];
      }
    });
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
                          child: AutofillGroup(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  t('Welkom', 'Welcome'),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? BigDoggTheme.darkTextPrimary : BigDoggTheme.lightTextPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  t('Inloggen op je account', 'Sign in to your account'),
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
                                if (_resetMessage != null)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: BigDoggTheme.successBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(_resetMessage!, style: const TextStyle(color: BigDoggTheme.success, fontSize: 13)),
                                  ),
                                TextField(
                                  controller: _emailController,
                                  autofillHints: const [AutofillHints.email],
                                  decoration: InputDecoration(labelText: t('E-mailadres', 'Email address')),
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _passwordController,
                                  autofillHints: const [AutofillHints.password],
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
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) {
                                    TextInput.finishAutofillContext();
                                    _login();
                                  },
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _forgotPassword,
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 32),
                                    ),
                                    child: Text(
                                      t('Wachtwoord vergeten?', 'Forgot password?'),
                                      style: const TextStyle(color: BigDoggTheme.teal700, fontSize: 13),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : () {
                                      TextInput.finishAutofillContext();
                                      _login();
                                    },
                                    child: _loading
                                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : Text(t('Inloggen', 'Sign in')),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: TextButton(
                                    onPressed: () => context.go('/register'),
                                    child: Text(t('Nog geen account? Aanmelden', "Don't have an account? Sign up")),
                                  ),
                                ),
                              ],
                            ),
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