import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/api_config.dart';
import '../theme.dart';

/// Subscription management page reached via `bigdogg.nl/#/subscription`.
///
/// Routing logic, in order:
///   1. No `?token=` → bounce to /pricing (organic visitors / signed-out
///      users have nothing to manage).
///   2. POST /api/v1/subscription/portal with the token.
///      • 200 + url → redirect this window to Stripe's hosted billing
///        portal. Monthly/yearly subscribers manage cards, cancel, etc.
///      • 400 `no_stripe_customer` → user is PAYG (no Stripe customer
///        record). Show a status page with an "Upgrade" CTA → /pricing.
///      • Anything else → error state with a manual retry.
class SubscriptionPortalScreen extends StatefulWidget {
  const SubscriptionPortalScreen({super.key});

  @override
  State<SubscriptionPortalScreen> createState() =>
      _SubscriptionPortalScreenState();
}

class _SubscriptionPortalScreenState extends State<SubscriptionPortalScreen> {
  String? _token;
  String? _email;
  bool _isNl = true;

  // 'loading' | 'payg' | 'error' | 'no_subscription'
  String _state = 'loading';
  String? _errorMessage;

  String t(String nl, String en) => _isNl ? nl : en;

  @override
  void initState() {
    super.initState();
    final state = GoRouterState.of(context);
    _token = state.uri.queryParameters['token'];
    _email = state.uri.queryParameters['email'];
    final lang = state.uri.queryParameters['lang'];
    if (lang == 'en') _isNl = false;

    // Run the portal handoff once after first build so context.go works
    // if we end up bouncing to /pricing.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPortal());
  }

  Future<void> _openPortal() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      // Nobody to manage — send organic visitors to the chooser.
      if (!mounted) return;
      context.go(_pricingUrl());
      return;
    }

    try {
      final resp = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/subscription/portal'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final url = (data['url'] ?? '').toString();
        if (url.isEmpty) {
          setState(() {
            _state = 'error';
            _errorMessage = t(
                'Geen portal link ontvangen.', 'No portal URL received.');
          });
          return;
        }
        await _navigateExternal(url);
        return;
      }

      // 400 with reason=no_stripe_customer → PAYG user. Anything else
      // is treated as a generic error.
      String? reason;
      try {
        final body = jsonDecode(resp.body);
        if (body is Map && body['detail'] is Map) {
          reason = (body['detail']['reason'] ?? '').toString();
        }
      } catch (_) {/* fall through to error */}

      if (reason == 'no_stripe_customer') {
        setState(() => _state = 'payg');
        return;
      }
      if (resp.statusCode == 404) {
        setState(() => _state = 'no_subscription');
        return;
      }
      setState(() {
        _state = 'error';
        _errorMessage = t(
            'Kon abonnement niet ophalen.', 'Could not load subscription.');
      });
    } catch (_) {
      setState(() {
        _state = 'error';
        _errorMessage = t(
            'Verbindingsfout. Controleer je internet.',
            'Connection error. Check your internet.');
      });
    }
  }

  String _pricingUrl() {
    final params = <String, String>{};
    if ((_token ?? '').isNotEmpty) params['token'] = _token!;
    if ((_email ?? '').isNotEmpty) params['email'] = _email!;
    if (!_isNl) params['lang'] = 'en';
    if (params.isEmpty) return '/pricing';
    final qs = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '/pricing?$qs';
  }

  Future<void> _navigateExternal(String url) async {
    final uri = Uri.parse(url);
    if (kIsWeb) {
      await launchUrl(uri, webOnlyWindowName: '_self');
    } else {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _content(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    if (_state == 'loading') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            t('Abonnementsbeheer wordt geopend…',
                'Opening subscription manager…'),
            style: const TextStyle(
                color: BigDoggTheme.lightTextSecondary, fontSize: 14),
          ),
        ],
      );
    }
    if (_state == 'payg') return _paygCard();
    if (_state == 'no_subscription') return _noSubCard();
    return _errorCard();
  }

  Widget _paygCard() {
    return _card(
      icon: Icons.bolt_rounded,
      iconBg: BigDoggTheme.gold500,
      title: t('Je gebruikt BigDogg per gebruik',
          'You\'re on pay-as-you-go'),
      body: t(
        'Geen vast abonnement nodig — je betaalt alleen voor de rapporten die je downloadt: €5 per jaarrapport, €1 per BTW-aangifte.',
        'No fixed subscription — you only pay for the reports you download: €5 per annual report, €1 per VAT report.',
      ),
      primaryLabel:
          t('Upgrade naar onbeperkt', 'Upgrade to unlimited'),
      onPrimary: () => context.go(_pricingUrl()),
      secondaryLabel: t('Sluiten', 'Close'),
      onSecondary: () => context.go('/'),
    );
  }

  Widget _noSubCard() {
    return _card(
      icon: Icons.subscriptions_rounded,
      iconBg: BigDoggTheme.teal800,
      title: t('Nog geen abonnement', 'No subscription yet'),
      body: t(
        'We konden geen actief abonnement vinden voor dit account. Kies een plan om door te gaan.',
        'We couldn\'t find an active subscription for this account. Pick a plan to get started.',
      ),
      primaryLabel: t('Bekijk de plannen', 'View plans'),
      onPrimary: () => context.go(_pricingUrl()),
    );
  }

  Widget _errorCard() {
    return _card(
      icon: Icons.error_outline_rounded,
      iconBg: BigDoggTheme.error,
      title: t('Er ging iets mis', 'Something went wrong'),
      body: _errorMessage ??
          t('Probeer het over een paar seconden opnieuw.',
              'Please try again in a few seconds.'),
      primaryLabel: t('Opnieuw proberen', 'Try again'),
      onPrimary: () {
        setState(() => _state = 'loading');
        _openPortal();
      },
      secondaryLabel: t('Bekijk de plannen', 'View plans'),
      onSecondary: () => context.go(_pricingUrl()),
    );
  }

  Widget _card({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String body,
    required String primaryLabel,
    required VoidCallback onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: BigDoggTheme.teal800,
              fontFamily: 'PlusJakartaSans',
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              color: BigDoggTheme.lightTextSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPrimary,
              style: ElevatedButton.styleFrom(
                backgroundColor: BigDoggTheme.teal800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              child: Text(primaryLabel),
            ),
          ),
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onSecondary,
              child: Text(
                secondaryLabel,
                style: const TextStyle(
                    color: BigDoggTheme.lightTextSecondary, fontSize: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
