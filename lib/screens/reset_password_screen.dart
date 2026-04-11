import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isNl = true;
  bool _success = false;
  bool _ready = false;
  String? _error;

  String t(String nl, String en) => _isNl ? nl : en;

  @override
  void initState() {
    super.initState();
    _listenForRecovery();
  }

  void _listenForRecovery() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        setState(() => _ready = true);
      }
    });

    // Check if already in recovery session
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      setState(() => _ready = true);
    }
  }

  Future<void> _updatePassword() async {
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = t('Wachtwoorden komen niet overeen', 'Passwords do not match'));
      return;
    }
    if (_passwordController.text.length < 6) {
      setState(() => _error = t(
          'Wachtwoord moet minimaal 6 tekens zijn',
          'Password must be at least 6 characters'));
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      setState(() { _loading = false; _success = true; });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) context.go('/login');
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
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
                          style: const TextStyle(
                              color: BigDoggTheme.gold600,
                              fontWeight: FontWeight.w700,
                              fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Image.asset('assets/images/logo.png', width: 100, height: 100),
                const SizedBox(height: 24),
                Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: BigDoggTheme.lightBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 32,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: !_ready
                      ? Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              t('Link wordt verwerkt...', 'Processing link...'),
                              style: const TextStyle(color: BigDoggTheme.lightTextSecondary),
                            ),
                          ],
                        )
                      : _success
                          ? Column(
                              children: [
                                const Icon(Icons.check_circle,
                                    color: BigDoggTheme.success, size: 48),
                                const SizedBox(height: 16),
                                Text(
                                  t('Wachtwoord gewijzigd!', 'Password updated!'),
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: BigDoggTheme.teal800),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  t('Je wordt doorgestuurd naar inloggen...',
                                      'Redirecting to login...'),
                                  style: const TextStyle(
                                      color: BigDoggTheme.lightTextSecondary),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t('Nieuw wachtwoord', 'New password'),
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: BigDoggTheme.teal800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  t(
                                      'Kies een nieuw wachtwoord voor je account',
                                      'Choose a new password for your account'),
                                  style: const TextStyle(
                                      color: BigDoggTheme.lightTextSecondary,
                                      fontSize: 14),
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
                                    child: Text(_error!,
                                        style: const TextStyle(
                                            color: BigDoggTheme.error,
                                            fontSize: 13)),
                                  ),
                                TextField(
                                  controller: _passwordController,
                                  decoration: InputDecoration(
                                    labelText: t('Nieuw wachtwoord', 'New password'),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: BigDoggTheme.lightTextSecondary,
                                      ),
                                      onPressed: () => setState(
                                          () => _obscurePassword = !_obscurePassword),
                                    ),
                                  ),
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.next,
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _confirmController,
                                  decoration: InputDecoration(
                                    labelText: t('Bevestig wachtwoord', 'Confirm password'),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirm
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: BigDoggTheme.lightTextSecondary,
                                      ),
                                      onPressed: () => setState(
                                          () => _obscureConfirm = !_obscureConfirm),
                                    ),
                                  ),
                                  obscureText: _obscureConfirm,
                                  onSubmitted: (_) => _updatePassword(),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _updatePassword,
                                    child: _loading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white))
                                        : Text(t('Wachtwoord opslaan', 'Save password')),
                                  ),
                                ),
                              ],
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}