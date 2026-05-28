import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/api_config.dart';
import '../theme.dart';

/// Web pricing chooser. Opened by the native app's paywall modal in an
/// in-app web view at `https://www.bigdogg.nl/#/pricing?email=…&token=…`.
///
/// The `token` query parameter carries the user's Supabase access token
/// so the backend can identify them without a separate web login. We
/// keep it in memory only (no localStorage / no Shared­Preferences) —
/// after the user picks a plan and we POST to /checkout, we either
/// redirect to Stripe or show a PAYG success state and let the user
/// dismiss the webview.
class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  String? _token;
  String? _email;
  String? _busyPlan;
  String? _error;
  bool _paygActivated = false;
  bool _isNl = true;

  String t(String nl, String en) => _isNl ? nl : en;

  @override
  void initState() {
    super.initState();
    // Pull token + email out of the URL right away. Both are optional —
    // organic visitors without a token still see the cards but get
    // bounced to /register instead of straight checkout.
    final state = GoRouterState.of(context);
    _token = state.uri.queryParameters['token'];
    _email = state.uri.queryParameters['email'];
    final lang = state.uri.queryParameters['lang'];
    if (lang == 'en') _isNl = false;
  }

  Future<void> _onPlanTapped(String plan) async {
    // Without a token we can't call /checkout — route the user through
    // signup, preserving their plan choice so the register screen can
    // chain back here.
    if (_token == null || _token!.isEmpty) {
      context.go('/register?plan=$plan'
          '${(_email ?? '').isNotEmpty ? '&email=${Uri.encodeQueryComponent(_email!)}' : ''}');
      return;
    }

    setState(() {
      _busyPlan = plan;
      _error = null;
    });
    try {
      final resp = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/subscription/checkout'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'plan': plan,
          if ((_email ?? '').isNotEmpty) 'email': _email,
        }),
      );
      final data = jsonDecode(resp.body);
      if (resp.statusCode != 200) {
        setState(() {
          _busyPlan = null;
          _error = (data is Map ? data['detail']?.toString() : null) ??
              t('Er ging iets mis. Probeer het opnieuw.',
                  'Something went wrong. Please try again.');
        });
        return;
      }
      if (plan == 'payg') {
        setState(() {
          _busyPlan = null;
          _paygActivated = true;
        });
        return;
      }
      // Monthly / yearly: redirect the current window to Stripe Checkout.
      final url = data['checkout_url']?.toString();
      if (url == null || url.isEmpty) {
        setState(() {
          _busyPlan = null;
          _error = t('Geen checkout link ontvangen.',
              'No checkout link received.');
        });
        return;
      }
      await _navigateExternal(url);
    } catch (e) {
      setState(() {
        _busyPlan = null;
        _error = t('Verbindingsfout. Controleer je internet.',
            'Connection error. Check your internet.');
      });
    }
  }

  Future<void> _navigateExternal(String url) async {
    final uri = Uri.parse(url);
    if (kIsWeb) {
      // Replace the current window so the user lands on Stripe inside
      // the same webview — keeps the in-app browser experience clean.
      await launchUrl(uri, webOnlyWindowName: '_self');
    } else {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;

    return Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
              horizontal: isWide ? 48 : 20, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(),
                  const SizedBox(height: 32),
                  if (_paygActivated)
                    _paygSuccess()
                  else
                    _cards(isWide),
                  if (_error != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: BigDoggTheme.errorBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: BigDoggTheme.error.withOpacity(0.4)),
                      ),
                      child: Text(_error!,
                          style: const TextStyle(
                              color: BigDoggTheme.error,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                  const SizedBox(height: 40),
                  Center(
                    child: Text(
                      t(
                          'Betalingen verlopen veilig via Stripe · iDEAL & creditcard',
                          'Payments securely via Stripe · iDEAL & credit card'),
                      style: const TextStyle(
                          color: BigDoggTheme.lightTextHint, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset('assets/images/logo.png', width: 56, height: 56),
        const SizedBox(height: 12),
        Text(
          t('Kies je BigDogg plan', 'Choose your BigDogg plan'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: BigDoggTheme.teal800,
            letterSpacing: -0.6,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
        const SizedBox(height: 10),
        Text(
          t(
            'Drie manieren om met BigDogg te werken — kies wat past bij hoe vaak je administratie doet.',
            'Three ways to use BigDogg — pick what fits how you work.',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 15,
              color: BigDoggTheme.lightTextSecondary,
              height: 1.5),
        ),
      ],
    );
  }

  Widget _cards(bool isWide) {
    final monthly = _planCard(
      plan: 'monthly',
      title: t('Maandelijks', 'Monthly'),
      priceLine: '€9,99',
      priceSub: t('/ maand', '/ month'),
      tagline: t('Flexibel — zeg op wanneer je wilt',
          'Flexible — cancel any time'),
      bullets: [
        t('✓ Onbeperkt facturen', '✓ Unlimited invoices'),
        t('✓ AI factuur assistent', '✓ AI invoice assistant'),
        t('✓ Onbeperkt jaarrapporten', '✓ Unlimited annual reports'),
        t('✓ Onbeperkt BTW-aangiftes', '✓ Unlimited VAT reports'),
        t('✓ Importeren oude facturen', '✓ Import old invoices'),
      ],
      ctaLabel: t('Start maandelijks', 'Start monthly'),
      highlight: false,
    );
    final yearly = _planCard(
      plan: 'yearly',
      title: t('Jaarlijks', 'Yearly'),
      priceLine: '€99,99',
      priceSub: t('/ jaar', '/ year'),
      tagline: t('Beste deal · 2 maanden gratis',
          'Best value · 2 months free'),
      bullets: [
        t('✓ Alles van Maandelijks', '✓ Everything in Monthly'),
        t('✓ 2 maanden korting per jaar',
            '✓ 2 months free vs monthly'),
        t('✓ Eén keer per jaar afrekenen',
            '✓ One payment a year'),
        t('✓ Onbeperkt jaarrapporten', '✓ Unlimited annual reports'),
        t('✓ Onbeperkt BTW-aangiftes', '✓ Unlimited VAT reports'),
      ],
      ctaLabel: t('Start jaarlijks', 'Start yearly'),
      highlight: true,
    );
    final payg = _planCard(
      plan: 'payg',
      title: t('Per gebruik', 'Pay-as-you-go'),
      priceLine: t('Gratis', 'Free'),
      priceSub: t('signup', 'signup'),
      tagline: t('Betaal alleen voor wat je downloadt',
          'Pay only for what you download'),
      bullets: [
        t('✓ Gratis account & basisgebruik',
            '✓ Free account & basic usage'),
        t('✓ Facturen en kosten bijhouden',
            '✓ Track invoices and expenses'),
        t('· €5 per jaarrapport',
            '· €5 per annual report'),
        t('· €1 per BTW-aangifte',
            '· €1 per VAT report'),
        t('✓ Upgrade later als je wilt',
            '✓ Upgrade any time'),
      ],
      ctaLabel: t('Gratis starten', 'Start free'),
      highlight: false,
    );

    if (isWide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: monthly),
            const SizedBox(width: 16),
            Expanded(child: yearly),
            const SizedBox(width: 16),
            Expanded(child: payg),
          ],
        ),
      );
    }
    return Column(
      children: [
        monthly,
        const SizedBox(height: 16),
        yearly,
        const SizedBox(height: 16),
        payg,
      ],
    );
  }

  Widget _planCard({
    required String plan,
    required String title,
    required String priceLine,
    required String priceSub,
    required String tagline,
    required List<String> bullets,
    required String ctaLabel,
    required bool highlight,
  }) {
    final busy = _busyPlan == plan;
    final disabled = _busyPlan != null && !busy;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: highlight ? BigDoggTheme.teal800 : BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight
              ? BigDoggTheme.teal800
              : BigDoggTheme.lightBorder,
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: BigDoggTheme.teal800.withOpacity(0.25),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (highlight) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: BigDoggTheme.gold500,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                t('AANBEVOLEN', 'RECOMMENDED'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: highlight ? Colors.white : BigDoggTheme.teal800,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                priceLine,
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  color: highlight ? Colors.white : BigDoggTheme.teal800,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  priceSub,
                  style: TextStyle(
                    fontSize: 14,
                    color: highlight
                        ? Colors.white70
                        : BigDoggTheme.lightTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tagline,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: highlight
                  ? BigDoggTheme.gold400
                  : BigDoggTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 18),
          ...bullets.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  b,
                  style: TextStyle(
                    fontSize: 14,
                    color: highlight ? Colors.white : BigDoggTheme.lightTextPrimary,
                    height: 1.4,
                  ),
                ),
              )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: disabled ? null : () => _onPlanTapped(plan),
              style: ElevatedButton.styleFrom(
                backgroundColor: highlight
                    ? BigDoggTheme.gold500
                    : BigDoggTheme.teal800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(ctaLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paygSuccess() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: BigDoggTheme.successBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BigDoggTheme.success.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: BigDoggTheme.success,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                color: Colors.white, size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            t('Je account is geactiveerd!', 'Your account is activated!'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: BigDoggTheme.teal800,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t(
              'Sluit dit venster en open de BigDogg app. Je kunt direct beginnen — '
              'jaarrapporten kosten €5 per stuk, BTW-aangiftes €1.',
              'Close this window and open the BigDogg app. You can start right '
              'away — annual reports are €5 each, VAT reports €1.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14,
                color: BigDoggTheme.lightTextSecondary,
                height: 1.5),
          ),
        ],
      ),
    );
  }
}
