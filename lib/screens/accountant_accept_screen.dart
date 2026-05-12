import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/accountants_service.dart';
import '../theme.dart';

/// Landing for `/accountant/accept/:token` — fired when the accountant
/// taps "Uitnodiging accepteren" in their email.
///
/// Two paths:
///   1. Already logged in to BigDogg → call /accept-invite immediately
///      and route into `/accountant`.
///   2. Not logged in → render a friendly branded landing showing the
///      inviter's name + explanation of BigDogg, with two big CTAs
///      (Log in / Maak gratis account). Token is stashed in prefs;
///      LoginScreen and RegisterScreen redeem it after auth.
class AccountantAcceptScreen extends StatefulWidget {
  final String token;
  const AccountantAcceptScreen({super.key, required this.token});

  @override
  State<AccountantAcceptScreen> createState() =>
      _AccountantAcceptScreenState();
}

class _AccountantAcceptScreenState extends State<AccountantAcceptScreen> {
  bool _processing = true;
  bool _loggedIn = false;
  String? _error;
  Map<String, dynamic>? _inviteInfo;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_accountant_invite', widget.token);
    final hasToken = (prefs.getString('access_token') ?? '').isNotEmpty;

    if (hasToken) {
      final result = await AccountantsService.acceptInvite(widget.token);
      if (!mounted) return;
      if (result['ok'] == true) {
        await prefs.remove('pending_accountant_invite');
        if (!mounted) return;
        context.go('/accountant');
        return;
      }
      // 401 = stale / expired access_token → treat as not-logged-in
      // and let the user re-authenticate via the landing card.
      if (result['status'] == 401) {
        await prefs.remove('access_token');
      } else {
        _loggedIn = true;
        setState(() {
          _processing = false;
          _error = result['error']?.toString() ?? 'accept_failed';
        });
        return;
      }
    }

    // Not logged in — look up the invite so we can show the inviter's name.
    final info = await AccountantsService.publicInviteInfo(widget.token);
    if (!mounted) return;
    setState(() {
      _processing = false;
      _inviteInfo = info;
      if (info['valid'] != true) {
        _error = info['reason']?.toString() ?? 'lookup_failed';
      }
    });
  }

  String _humanizeError(String code) {
    switch (code) {
      case 'invite_not_found':
      case 'not_found':
        return 'Deze uitnodiging bestaat niet meer.';
      case 'invite_already_used':
      case 'already_used':
        return 'Deze uitnodiging is al gebruikt.';
      case 'invite_expired':
      case 'expired':
        return 'Deze uitnodiging is verlopen — vraag een nieuwe aan.';
      case 'email_mismatch':
        return 'Het e-mailadres van je BigDogg-account komt niet overeen met de uitnodiging. Log in met het juiste account.';
      default:
        return 'Er ging iets mis: $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _buildBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_processing) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Uitnodiging controleren…'),
        ],
      );
    }

    // Logged-in path that failed (email mismatch / expired / etc.)
    if (_loggedIn && _error != null) {
      return _errorCard();
    }

    // Logged-out path — invite invalid
    if (_inviteInfo != null && _inviteInfo!['valid'] != true) {
      return _errorCard();
    }

    // Logged-out path — show landing
    return _landingCard();
  }

  Widget _errorCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 56, color: BigDoggTheme.error),
          const SizedBox(height: 16),
          Text(
            _humanizeError(_error ?? 'unknown'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: BigDoggTheme.teal800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => context.go(_loggedIn ? '/dashboard' : '/login'),
              child: Text(_loggedIn ? 'Naar BigDogg' : 'Naar inloggen'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _landingCard() {
    final info = _inviteInfo ?? {};
    final inviter = (info['inviter_name'] ?? '').toString().trim();
    final inviteEmail = (info['invite_email'] ?? '').toString().trim();
    final inviterDisplay =
        inviter.isEmpty ? 'Een BigDogg-gebruiker' : inviter;

    return Container(
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BigDoggTheme.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Branded header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
            decoration: const BoxDecoration(
              color: BigDoggTheme.teal800,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                Image.asset('assets/images/logo.png', width: 64, height: 64),
                const SizedBox(height: 12),
                const Text(
                  'BigDogg.',
                  style: TextStyle(
                    color: BigDoggTheme.gold500,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'ACCOUNTANTSUITNODIGING',
                  style: TextStyle(
                    color: Color(0xFFF5F3EF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 16,
                      color: BigDoggTheme.lightTextPrimary,
                      height: 1.55,
                    ),
                    children: [
                      TextSpan(
                        text: inviterDisplay,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(
                          text:
                              ' nodigt je uit als accountant op BigDogg.'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'BigDogg is een Nederlandse boekhoud-app voor ZZP\'ers — '
                  'facturen, kosten, BTW en jaaroverzichten op één plek. '
                  'Met deze uitnodiging krijg je alleen-lezen toegang tot '
                  'de administratie van je klant.',
                  style: TextStyle(
                    fontSize: 14,
                    color: BigDoggTheme.lightTextSecondary,
                    height: 1.55,
                  ),
                ),
                if (inviteEmail.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: BigDoggTheme.lightBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: BigDoggTheme.lightBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 16, color: BigDoggTheme.teal700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Log in of registreer met: $inviteEmail',
                            style: const TextStyle(
                              fontSize: 12,
                              color: BigDoggTheme.lightTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BigDoggTheme.teal800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon:
                        const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text(
                      'Gratis account aanmaken',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => context.go('/register'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BigDoggTheme.teal800,
                      side: const BorderSide(color: BigDoggTheme.teal700),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.login, size: 18),
                    label: const Text(
                      'Inloggen op bestaand account',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => context.go('/login'),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'De uitnodiging wordt automatisch geaccepteerd zodra je bent ingelogd.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: BigDoggTheme.lightTextSecondary.withOpacity(0.85),
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
