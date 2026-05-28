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
/// Routing logic:
///   1. No `?token=` → bounce to /pricing (organic visitors have
///      nothing to manage).
///   2. POST /api/v1/subscription/portal with the token.
///      • 200 + url → redirect this window to Stripe's hosted billing
///        portal. Monthly/yearly subscribers manage cards, cancel, etc.
///      • 200 + url:null + status:'legacy_active' → user is active but
///        was activated outside of a normal Stripe checkout (admin
///        flip, pre-Stripe signup, etc.). Show "Subscription active —
///        contact support to manage billing" status.
///      • 404 → no subscription row. Bounce to /pricing.
///      • Anything else → error state with retry.
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

  // 'loading' | 'legacy_active' | 'error' | 'no_subscription'
  String _state = 'loading';
  String? _planLabel;
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

    WidgetsBinding.instance.addPostFrameCallback((_) => _openPortal());
  }

  Future<void> _openPortal() async {
    final token = _token;
    if (token == null || token.isEmpty) {
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
      if (resp.statusCode == 404) {
        setState(() => _state = 'no_subscription');
        return;
      }
      if (resp.statusCode != 200) {
        setState(() {
          _state = 'error';
          _errorMessage = t(
              'Kon abonnement niet ophalen.', 'Could not load subscription.');
        });
        return;
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final url = (data['url'] ?? '').toString();
      if (url.isNotEmpty) {
        // Active monthly/yearly subscriber → hand off to Stripe portal.
        await _navigateExternal(url);
        return;
      }

      // url=null branch — legacy-active or other no-Stripe-customer
      // state. Show the user a friendly "already active" page rather
      // than the upgrade flow they don't need.
      final planRaw = (data['plan'] ?? '').toString();
      _planLabel = _humanPlan(planRaw);
      setState(() => _state = 'legacy_active');
    } catch (_) {
      setState(() {
        _state = 'error';
        _errorMessage = t(
            'Verbindingsfout. Controleer je internet.',
            'Connection error. Check your internet.');
      });
    }
  }

  String? _humanPlan(String plan) {
    switch (plan) {
      case 'monthly':
        return t('Maandelijks abonnement', 'Monthly subscription');
      case 'yearly':
        return t('Jaarlijks abonnement', 'Yearly subscription');
      default:
        return null;
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
    if (_state == 'legacy_active') return _legacyActiveCard();
    if (_state == 'no_subscription') return _noSubCard();
    return _errorCard();
  }

  Widget _legacyActiveCard() {
    final planLine = _planLabel == null
        ? null
        : t('Je huidige plan: $_planLabel',
            'Your current plan: $_planLabel');
    return _card(
      icon: Icons.check_circle_rounded,
      iconBg: BigDoggTheme.success,
      title: t('Je abonnement is actief', 'Your subscription is active'),
      body: planLine != null
          ? t(
              '$planLine.\n\nNeem contact op met info@bigdogg.nl als je je betaalgegevens wilt wijzigen of wilt opzeggen.',
              '$planLine.\n\nContact info@bigdogg.nl if you want to change payment details or cancel.',
            )
          : t(
              'Neem contact op met info@bigdogg.nl als je je betaalgegevens wilt wijzigen of wilt opzeggen.',
              'Contact info@bigdogg.nl to change payment details or cancel.',
            ),
      primaryLabel: t('Sluiten', 'Close'),
      onPrimary: () => context.go('/'),
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
