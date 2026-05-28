import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isNl = true;
  String? _error;

  String t(String nl, String en) => _isNl ? nl : en;

  // Password strength checks
  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _hasUppercase => _passwordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasNumber => _passwordController.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecial => _passwordController.text.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
  bool get _passwordValid => _hasMinLength && _hasUppercase && _hasNumber;

  int get _strengthScore {
    int score = 0;
    if (_hasMinLength) score++;
    if (_hasUppercase) score++;
    if (_hasNumber) score++;
    if (_hasSpecial) score++;
    return score;
  }

  Color get _strengthColor {
    switch (_strengthScore) {
      case 1: return BigDoggTheme.error;
      case 2: return BigDoggTheme.warning;
      case 3: return Colors.orange;
      case 4: return BigDoggTheme.success;
      default: return BigDoggTheme.lightBorder;
    }
  }

  String get _strengthLabel {
    switch (_strengthScore) {
      case 1: return t('Zwak', 'Weak');
      case 2: return t('Matig', 'Fair');
      case 3: return t('Goed', 'Good');
      case 4: return t('Sterk', 'Strong');
      default: return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
    _consumePendingEmail();
  }

  /// The native app opens `/pricing?email=…` in the in-app web view; the
  /// route handler stashes that address. Read it once and clear so a
  /// later visit doesn't surprise-fill someone else's email.
  Future<void> _consumePendingEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = (prefs.getString('pending_signup_email') ?? '').trim();
    if (email.isEmpty) return;
    await prefs.remove('pending_signup_email');
    if (!mounted) return;
    setState(() {
      _emailController.text = email;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = t('Vul je naam in', 'Please enter your name'));
      return;
    }
    if (!_passwordValid) {
      setState(() => _error = t(
        'Wachtwoord moet minimaal 8 tekens, een hoofdletter en een cijfer bevatten',
        'Password must be at least 8 characters with one uppercase letter and one number',
      ));
      return;
    }
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
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
              padding: EdgeInsets.only(bottom: bottomInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - bottomInset,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
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
                                focusNode: _nameFocus,
                                decoration: InputDecoration(labelText: t('Volledige naam', 'Full name')),
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) => FocusScope.of(context).requestFocus(_emailFocus),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _emailController,
                                focusNode: _emailFocus,
                                decoration: const InputDecoration(labelText: 'Email'),
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _passwordController,
                                focusNode: _passwordFocus,
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
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) => FocusScope.of(context).requestFocus(_confirmFocus),
                              ),

                              // Password strength indicator
                              if (_passwordController.text.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    ...List.generate(4, (i) => Expanded(
                                      child: Container(
                                        margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: i < _strengthScore
                                              ? _strengthColor
                                              : BigDoggTheme.lightBorder,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    )),
                                    const SizedBox(width: 8),
                                    Text(
                                      _strengthLabel,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: _strengthColor,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Requirements checklist
                                _requirementRow(_hasMinLength, t('Minimaal 8 tekens', 'At least 8 characters')),
                                _requirementRow(_hasUppercase, t('Een hoofdletter', 'One uppercase letter')),
                                _requirementRow(_hasNumber, t('Een cijfer', 'One number')),
                                _requirementRow(_hasSpecial, t('Speciaal teken (optioneel)', 'Special character (optional)')),
                              ],

                              const SizedBox(height: 14),
                              TextField(
                                controller: _confirmController,
                                focusNode: _confirmFocus,
                                decoration: InputDecoration(
                                  labelText: t('Wachtwoord bevestigen', 'Confirm password'),
                                  suffixIcon: ExcludeFocus(
                                    child: IconButton(
                                      icon: Icon(
                                        _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                        color: BigDoggTheme.lightTextSecondary,
                                      ),
                                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                    ),
                                  ),
                                ),
                                obscureText: _obscureConfirm,
                                textInputAction: TextInputAction.done,
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

  Widget _requirementRow(bool met, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: met ? BigDoggTheme.success : BigDoggTheme.lightTextHint,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: met ? BigDoggTheme.success : BigDoggTheme.lightTextHint,
            ),
          ),
        ],
      ),
    );
  }
}