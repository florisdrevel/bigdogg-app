import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/push_service.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _isNl = true;
  bool _rememberMe = true;
  String? _error;
  String? _resetMessage;

  String t(String nl, String en) => _isNl ? nl : en;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; _resetMessage = null; });
    final result = await AuthService.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      rememberMe: _rememberMe,
    );
    setState(() { _loading = false; });
    if (result['success']) {
      // Register this device's FCM token now that we have an
      // access_token saved. Best-effort, never blocks the navigation.
      // ignore: unawaited_futures
      PushService.registerWithBackend();
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned(
            left: 0, top: 0, bottom: 0, width: 5,
            child: Container(color: BigDoggTheme.gold500),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, viewport) {
                // Shrink the logo on shorter viewports so the whole login
                // card stays in view without scrolling. 140px on most
                // phones, 200px on a desktop browser.
                final tallEnough = viewport.maxHeight > 760;
                final mediumEnough = viewport.maxHeight > 600;
                final logoSize = tallEnough ? 200.0 : (mediumEnough ? 140.0 : 96.0);

                return SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: viewport.maxHeight - bottomInset,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
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
                            const SizedBox(height: 8),
                            Image.asset('assets/images/logo.png', width: logoSize, height: logoSize),
                            const SizedBox(height: 8),
                            Container(
                              width: 420,
                              constraints: const BoxConstraints(maxWidth: 420),
                              margin: const EdgeInsets.symmetric(horizontal: 8),
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
                                padding: const EdgeInsets.all(24),
                                child: AutofillGroup(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        t('Welkom', 'Welcome'),
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? BigDoggTheme.darkTextPrimary : BigDoggTheme.lightTextPrimary,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        t('Inloggen op je account', 'Sign in to your account'),
                                        style: TextStyle(
                                          color: isDark ? BigDoggTheme.darkTextSecondary : BigDoggTheme.lightTextSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
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
                                  focusNode: _emailFocus,
                                  autofillHints: const [AutofillHints.email],
                                  decoration: InputDecoration(labelText: t('E-mailadres', 'Email address')),
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  onSubmitted: (_) {
                                    FocusScope.of(context).requestFocus(_passwordFocus);
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _passwordController,
                                  focusNode: _passwordFocus,
                                  autofillHints: const [AutofillHints.password],
                                  decoration: InputDecoration(
                                    labelText: t('Wachtwoord', 'Password'),
                                    suffixIcon: ExcludeFocus(
                                      child: IconButton(
                                        icon: Icon(
                                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                          color: BigDoggTheme.lightTextSecondary,
                                        ),
                                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                      ),
                                    ),
                                  ),
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) {
                                    TextInput.finishAutofillContext();
                                    _login();
                                  },
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _forgotPassword,
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 28),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      t('Wachtwoord vergeten?', 'Forgot password?'),
                                      style: const TextStyle(color: BigDoggTheme.teal700, fontSize: 13),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: Checkbox(
                                            value: _rememberMe,
                                            onChanged: (v) => setState(() => _rememberMe = v ?? true),
                                            visualDensity: VisualDensity.compact,
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          t('Ingelogd blijven', 'Keep me logged in'),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: BigDoggTheme.lightTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}