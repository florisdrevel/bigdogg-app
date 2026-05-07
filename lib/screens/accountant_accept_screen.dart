import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/accountants_service.dart';
import '../theme.dart';

/// Landing for `/accountant/accept/:token` — fired when the accountant
/// taps "Accepteer uitnodiging" in their email.
///
/// If logged in: redeem the token, then go to the clients picker.
/// If not logged in: stash the token in prefs and bounce to /login —
/// after login the dashboard will pick up the pending token.
class AccountantAcceptScreen extends StatefulWidget {
  final String token;
  const AccountantAcceptScreen({super.key, required this.token});

  @override
  State<AccountantAcceptScreen> createState() =>
      _AccountantAcceptScreenState();
}

class _AccountantAcceptScreenState extends State<AccountantAcceptScreen> {
  bool _processing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final prefs = await SharedPreferences.getInstance();
    final hasToken = (prefs.getString('access_token') ?? '').isNotEmpty;
    if (!hasToken) {
      await prefs.setString('pending_accountant_invite', widget.token);
      if (!mounted) return;
      context.go('/login');
      return;
    }
    final result = await AccountantsService.acceptInvite(widget.token);
    if (!mounted) return;
    setState(() => _processing = false);
    if (result['ok'] == true) {
      await prefs.remove('pending_accountant_invite');
      if (!mounted) return;
      context.go('/accountant');
    } else {
      setState(() => _error = result['error']?.toString() ?? 'accept_failed');
    }
  }

  String _humanizeError(String code) {
    switch (code) {
      case 'invite_not_found':
        return 'Deze uitnodiging bestaat niet meer.';
      case 'invite_already_used':
        return 'Deze uitnodiging is al gebruikt.';
      case 'invite_expired':
        return 'Deze uitnodiging is verlopen — vraag een nieuwe aan.';
      case 'email_mismatch':
        return 'Het e-mailadres van je BigDogg-account komt niet overeen met de uitnodiging.';
      default:
        return 'Er ging iets mis: $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _processing
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Uitnodiging accepteren…'),
                  ],
                )
              : (_error == null
                  ? const SizedBox.shrink()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: BigDoggTheme.error),
                        const SizedBox(height: 12),
                        Text(_humanizeError(_error!),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 15)),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => context.go('/dashboard'),
                          child: const Text('Naar BigDogg'),
                        ),
                      ],
                    )),
        ),
      ),
    );
  }
}
