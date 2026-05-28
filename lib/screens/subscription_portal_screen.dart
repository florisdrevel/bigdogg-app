import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/api_config.dart';
import '../theme.dart';

/// `bigdogg.nl/#/subscription` — subscription hub + cancellation wizard.
///
/// The page is a small state machine. The hub shows current plan + three
/// actions; the cancellation flow is five steps with a tailored save
/// offer in step 3. All state lives in this widget — no separate routes.
class SubscriptionPortalScreen extends StatefulWidget {
  const SubscriptionPortalScreen({super.key});

  @override
  State<SubscriptionPortalScreen> createState() =>
      _SubscriptionPortalScreenState();
}

enum _ViewState {
  loading,
  hubLegacyActive, // active, no Stripe customer
  hubActive,       // active monthly/yearly with Stripe customer
  noSubscription,
  error,
  cancelIntro,
  cancelReason,
  cancelOffer,
  cancelConfirm,
  cancelDone,
  offerAccepted,
}

class _SubscriptionPortalScreenState extends State<SubscriptionPortalScreen> {
  String? _token;
  String? _email;
  bool _isNl = true;

  _ViewState _view = _ViewState.loading;
  String? _errorMessage;
  String? _plan;             // 'monthly' | 'yearly' | null
  String? _status;           // 'active' | 'legacy_active' | ...
  String? _portalUrl;        // Stripe Billing Portal URL once loaded
  bool _isLegacyActive = false;

  // Usage stats for the "don't go yet" step.
  Map<String, dynamic>? _usage;

  // Cancel flow state.
  String? _cancelReason;
  final _commentCtrl = TextEditingController();
  bool _confirmCheckbox = false;
  bool _busy = false;
  DateTime? _accessUntil;
  int? _offerMonths;

  String t(String nl, String en) => _isNl ? nl : en;

  @override
  void initState() {
    super.initState();
    final state = GoRouterState.of(context);
    _token = state.uri.queryParameters['token'];
    _email = state.uri.queryParameters['email'];
    final lang = state.uri.queryParameters['lang'];
    if (lang == 'en') _isNl = false;

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHub());
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  // ─── Loading the hub ──────────────────────────────────────────

  Future<void> _loadHub() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      context.go(_pricingUrl());
      return;
    }
    try {
      final resp = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/subscription/portal'),
        headers: _authHeaders(),
      );
      if (resp.statusCode == 404) {
        setState(() => _view = _ViewState.noSubscription);
        return;
      }
      if (resp.statusCode != 200) {
        setState(() {
          _view = _ViewState.error;
          _errorMessage = t('Kon abonnement niet ophalen.',
              'Could not load subscription.');
        });
        return;
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      _portalUrl = (data['url'] ?? '').toString();
      _plan = data['plan']?.toString();
      _status = data['status']?.toString();
      _isLegacyActive = (_portalUrl == null || _portalUrl!.isEmpty);
      setState(() => _view = _isLegacyActive
          ? _ViewState.hubLegacyActive
          : _ViewState.hubActive);
    } catch (_) {
      setState(() {
        _view = _ViewState.error;
        _errorMessage = t('Verbindingsfout. Controleer je internet.',
            'Connection error. Check your internet.');
      });
    }
  }

  Future<void> _loadUsageThenIntro() async {
    setState(() => _busy = true);
    try {
      final resp = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/subscription/usage-summary'),
        headers: _authHeaders(),
      );
      if (resp.statusCode == 200) {
        _usage = jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {/* stats are nice-to-have */}
    if (!mounted) return;
    setState(() {
      _busy = false;
      _view = _ViewState.cancelIntro;
    });
  }

  // ─── Mutations ────────────────────────────────────────────────

  Future<void> _doCancel({required bool acceptOffer}) async {
    final reason = _cancelReason;
    if (reason == null) return;
    setState(() => _busy = true);
    try {
      final resp = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/subscription/cancel'),
        headers: _authHeaders(),
        body: jsonEncode({
          'reason': reason,
          'comment': _commentCtrl.text.trim().isEmpty
              ? null
              : _commentCtrl.text.trim(),
          'accept_offer': acceptOffer,
        }),
      );
      if (resp.statusCode != 200) {
        setState(() {
          _busy = false;
          _errorMessage = t('Opzeggen mislukt. Probeer opnieuw.',
              'Cancellation failed. Please try again.');
        });
        return;
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final outcome = (data['outcome'] ?? '').toString();
      if (!mounted) return;
      if (outcome == 'offer_accepted') {
        _offerMonths = (data['months_free'] as num?)?.toInt();
        setState(() {
          _busy = false;
          _view = _ViewState.offerAccepted;
        });
      } else {
        final iso = (data['access_until'] ?? '').toString();
        _accessUntil = DateTime.tryParse(iso);
        setState(() {
          _busy = false;
          _view = _ViewState.cancelDone;
        });
      }
    } catch (_) {
      setState(() {
        _busy = false;
        _errorMessage = t('Verbindingsfout. Probeer opnieuw.',
            'Connection error. Try again.');
      });
    }
  }

  Future<void> _reactivate() async {
    setState(() => _busy = true);
    try {
      final resp = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/subscription/reactivate'),
        headers: _authHeaders(),
      );
      if (resp.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: BigDoggTheme.success,
          content: Text(t('Abonnement heractiveerd',
              'Subscription reactivated')),
        ));
        await _loadHub();
        return;
      }
    } catch (_) {/* fall through */}
    if (!mounted) return;
    setState(() {
      _busy = false;
      _errorMessage =
          t('Heractiveren mislukt. Probeer opnieuw.', 'Reactivation failed.');
    });
  }

  Future<void> _openStripePortal() async {
    if (_portalUrl == null || _portalUrl!.isEmpty) return;
    await _navigateExternal(_portalUrl!);
  }

  // ─── Render ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: _content(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    switch (_view) {
      case _ViewState.loading:
        return _loading();
      case _ViewState.hubActive:
      case _ViewState.hubLegacyActive:
        return _hub();
      case _ViewState.noSubscription:
        return _noSubCard();
      case _ViewState.error:
        return _errorCard();
      case _ViewState.cancelIntro:
        return _cancelIntro();
      case _ViewState.cancelReason:
        return _cancelReasonStep();
      case _ViewState.cancelOffer:
        return _cancelOfferStep();
      case _ViewState.cancelConfirm:
        return _cancelConfirmStep();
      case _ViewState.cancelDone:
        return _cancelDoneStep();
      case _ViewState.offerAccepted:
        return _offerAcceptedStep();
    }
  }

  // Hub ----------------------------------------------------------

  Widget _hub() {
    final planLabel = _humanPlan(_plan) ??
        t('Actief abonnement', 'Active subscription');
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
                color: BigDoggTheme.success, shape: BoxShape.circle),
            child:
                const Icon(Icons.check_rounded, color: Colors.white, size: 38),
          ),
          const SizedBox(height: 18),
          Text(
            t('Je abonnement is actief', 'Your subscription is active'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: BigDoggTheme.teal800,
              fontFamily: 'PlusJakartaSans',
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            planLabel,
            style: const TextStyle(
                fontSize: 14, color: BigDoggTheme.lightTextSecondary),
          ),
          const SizedBox(height: 24),
          if (!_isLegacyActive) ...[
            _hubButton(
              icon: Icons.credit_card_rounded,
              label: t('Betaalmethode bijwerken',
                  'Update payment method'),
              subtitle: t('Wijzig je kaart of bekijk facturen',
                  'Change card or view invoices'),
              onTap: _openStripePortal,
            ),
            const SizedBox(height: 10),
            _hubButton(
              icon: Icons.compare_arrows_rounded,
              label: t('Plan wijzigen', 'Change plan'),
              subtitle: t(
                  'Wissel tussen maandelijks en jaarlijks',
                  'Switch between monthly and yearly'),
              onTap: () => context.go(_pricingUrl()),
            ),
            const SizedBox(height: 10),
            _hubButton(
              icon: Icons.cancel_outlined,
              label: t('Abonnement opzeggen', 'Cancel subscription'),
              subtitle: t(
                  'We zien je niet graag gaan',
                  'We\'d hate to see you go'),
              destructive: true,
              onTap: _busy ? null : _loadUsageThenIntro,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BigDoggTheme.gold500.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: BigDoggTheme.gold500.withOpacity(0.4)),
              ),
              child: Text(
                t(
                  'Je account is actief zonder Stripe-koppeling. Neem contact op met info@bigdogg.nl om je betaalgegevens te wijzigen.',
                  'Your account is active without a Stripe link. Contact info@bigdogg.nl to change billing details.',
                ),
                style: const TextStyle(
                    fontSize: 13,
                    color: BigDoggTheme.lightTextSecondary,
                    height: 1.5),
              ),
            ),
            const SizedBox(height: 10),
            _hubButton(
              icon: Icons.cancel_outlined,
              label: t('Abonnement opzeggen', 'Cancel subscription'),
              destructive: true,
              onTap: _busy ? null : _loadUsageThenIntro,
            ),
          ],
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => context.go('/'),
            child: Text(t('Sluiten', 'Close'),
                style: const TextStyle(
                    color: BigDoggTheme.lightTextSecondary, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _hubButton({
    required IconData icon,
    required String label,
    String? subtitle,
    bool destructive = false,
    VoidCallback? onTap,
  }) {
    final fg = destructive ? BigDoggTheme.error : BigDoggTheme.teal800;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BigDoggTheme.lightBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BigDoggTheme.lightBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: fg.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: fg, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: fg)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12,
                            color: BigDoggTheme.lightTextSecondary)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: BigDoggTheme.lightTextHint, size: 22),
          ],
        ),
      ),
    );
  }

  // Step 1: "Don't go yet" ---------------------------------------

  Widget _cancelIntro() {
    final invCount = (_usage?['invoices_count'] as num?)?.toInt() ?? 0;
    final revenue =
        (_usage?['revenue_tracked'] as num?)?.toDouble() ?? 0;
    final expCount = (_usage?['expenses_count'] as num?)?.toInt() ?? 0;
    final memberSinceIso = (_usage?['member_since'] ?? '').toString();
    String? memberSinceLabel;
    try {
      if (memberSinceIso.isNotEmpty) {
        final dt = DateTime.parse(memberSinceIso).toLocal();
        memberSinceLabel = '${dt.day}-${dt.month}-${dt.year}';
      }
    } catch (_) {}

    return _stepCard(
      stepIndex: 1,
      title: t('We zien je niet graag gaan',
          'We\'d hate to see you go'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (invCount > 0 || expCount > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BigDoggTheme.lightBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BigDoggTheme.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('Wat je samen met BigDogg hebt opgebouwd:',
                        'What you\'ve built with BigDogg:'),
                    style: const TextStyle(
                        fontSize: 13,
                        color: BigDoggTheme.lightTextSecondary,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  _statRow(
                      icon: Icons.receipt_long_rounded,
                      value: '$invCount',
                      label: t('facturen verstuurd',
                          'invoices sent')),
                  if (revenue > 0)
                    _statRow(
                        icon: Icons.euro_rounded,
                        value: '€${revenue.toStringAsFixed(2)}',
                        label: t('omzet bijgehouden',
                            'revenue tracked')),
                  _statRow(
                      icon: Icons.receipt_rounded,
                      value: '$expCount',
                      label: t('kosten geregistreerd',
                          'expenses recorded')),
                  if (memberSinceLabel != null)
                    _statRow(
                        icon: Icons.calendar_today_rounded,
                        value: memberSinceLabel,
                        label: t('lid sinds', 'member since')),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            t(
              'Je houdt deze gegevens altijd. Maar je verliest toegang om nieuwe facturen te maken en BTW-aangiftes te downloaden.',
              'You\'ll always keep this data. But you lose access to creating new invoices and downloading VAT reports.',
            ),
            style: const TextStyle(
                fontSize: 14,
                color: BigDoggTheme.lightTextSecondary,
                height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () =>
                setState(() => _view = _ViewState.cancelReason),
            style: _destructiveButtonStyle(),
            child: Text(t('Doorgaan met opzeggen',
                'Continue cancelling')),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => setState(() => _view = _hubReturnState()),
            style: _primaryButtonStyle(),
            child: Text(
                t('Toch behouden', 'Keep my subscription')),
          ),
        ],
      ),
    );
  }

  Widget _statRow(
      {required IconData icon,
      required String value,
      required String label}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: BigDoggTheme.teal800),
          const SizedBox(width: 10),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: BigDoggTheme.teal800)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: BigDoggTheme.lightTextSecondary)),
          ),
        ],
      ),
    );
  }

  // Step 2: Reason survey ---------------------------------------

  Widget _cancelReasonStep() {
    final reasons = <_Reason>[
      _Reason('too_expensive',
          t('Te duur', 'Too expensive')),
      _Reason('not_using',
          t('Ik gebruik het niet vaak genoeg', 'I\'m not using it enough')),
      _Reason('missing_feature',
          t('Mist een functie die ik nodig heb',
              'Missing a feature I need')),
      _Reason('found_alternative',
          t('Ik heb een alternatief gevonden',
              'I found an alternative')),
      _Reason('stopped_freelancing',
          t('Ik ben gestopt met ondernemen',
              'I stopped freelancing')),
      _Reason('other', t('Andere reden', 'Other reason')),
    ];

    return _stepCard(
      stepIndex: 2,
      title: t('Wat is de reden?', 'What\'s the reason?'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t(
              'Eerlijke feedback helpt ons BigDogg te verbeteren.',
              'Honest feedback helps us improve BigDogg.',
            ),
            style: const TextStyle(
                fontSize: 13.5,
                color: BigDoggTheme.lightTextSecondary,
                height: 1.5),
          ),
          const SizedBox(height: 16),
          ...reasons.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _cancelReason = r.value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _cancelReason == r.value
                          ? BigDoggTheme.teal800.withOpacity(0.07)
                          : BigDoggTheme.lightBg,
                      border: Border.all(
                        color: _cancelReason == r.value
                            ? BigDoggTheme.teal800
                            : BigDoggTheme.lightBorder,
                        width: _cancelReason == r.value ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _cancelReason == r.value
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: _cancelReason == r.value
                              ? BigDoggTheme.teal800
                              : BigDoggTheme.lightTextHint,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(r.label,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: BigDoggTheme.lightTextPrimary)),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
          const SizedBox(height: 14),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: t('Optioneel — vertel meer (max. 500 tekens)',
                  'Optional — tell us more (max 500 chars)'),
              filled: true,
            ),
            maxLength: 500,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _cancelReason == null
                ? null
                : () {
                    // Reasons that get the save offer.
                    const offerable = {
                      'too_expensive',
                      'not_using',
                      'found_alternative',
                      'other',
                    };
                    final next = offerable.contains(_cancelReason)
                        ? _ViewState.cancelOffer
                        : _ViewState.cancelConfirm;
                    setState(() => _view = next);
                  },
            style: _destructiveButtonStyle(),
            child: Text(t('Volgende', 'Next')),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _view = _ViewState.cancelIntro),
            child: Text(t('Terug', 'Back')),
          ),
        ],
      ),
    );
  }

  // Step 3: Save offer -------------------------------------------

  Widget _cancelOfferStep() {
    final offerAvailable = _usage?['offer_available'] != false;
    final months =
        (_usage?['offer_months'] as num?)?.toInt() ?? 3;

    if (!offerAvailable) {
      // User already accepted an offer in the cooldown window — skip
      // straight to confirmation. We render a tiny notice and a button
      // since auto-skipping inside build is awkward.
      return _stepCard(
        stepIndex: 3,
        title: t('Je hebt al recent een aanbieding gehad',
            'You\'ve already used a recent offer'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t(
                'Je kunt maximaal één aanbieding per jaar gebruiken. Doorgaan met opzeggen?',
                'Only one retention offer per year. Continue cancelling?',
              ),
              style: const TextStyle(
                  fontSize: 14,
                  color: BigDoggTheme.lightTextSecondary,
                  height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () =>
                  setState(() => _view = _ViewState.cancelConfirm),
              style: _destructiveButtonStyle(),
              child: Text(t('Verder met opzeggen', 'Continue to cancel')),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => setState(() => _view = _hubReturnState()),
              style: _primaryButtonStyle(),
              child: Text(t('Toch behouden', 'Keep my subscription')),
            ),
          ],
        ),
      );
    }

    // Special handling for missing-feature: we already skipped offer in
    // _cancelReasonStep, but defence-in-depth in case someone arrives
    // here from a deep link.
    if (_cancelReason == 'missing_feature') {
      return _stepCard(
        stepIndex: 3,
        title: t('Bedankt voor de feedback',
            'Thanks for the feedback'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t(
                'We bouwen continu door aan BigDogg. Als de functie er komt, sturen we je een mail.',
                'We\'re always building. We\'ll email you if the feature ships.',
              ),
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () =>
                  setState(() => _view = _ViewState.cancelConfirm),
              style: _destructiveButtonStyle(),
              child: Text(t('Volgende', 'Next')),
            ),
          ],
        ),
      );
    }

    final offerHeadline = _plan == 'yearly'
        ? t('Krijg $months maanden extra toegang',
            'Get $months extra months of access')
        : t('Krijg $months maanden gratis BigDogg',
            'Get $months months of BigDogg free');
    final offerBody = _plan == 'yearly'
        ? t(
            'We verlengen je huidige jaarabonnement met $months maanden. Geen kosten — gewoon meer tijd om te beslissen.',
            'We\'ll extend your current yearly subscription by $months months. No charge — just more time to decide.',
          )
        : t(
            'We schrijven $months maanden van je rekening — komende facturen zijn gratis. Daarna ga je weer normaal betalen, of je zegt later alsnog op.',
            'We waive $months months of billing — your next $months invoices are free. After that you go back to paying normally, or cancel later.',
          );

    return _stepCard(
      stepIndex: 3,
      title: t('Wacht — een aanbod', 'Wait — an offer'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  BigDoggTheme.gold500.withOpacity(0.18),
                  BigDoggTheme.gold500.withOpacity(0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: BigDoggTheme.gold500.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: BigDoggTheme.gold500,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('AANBOD',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(offerHeadline,
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: BigDoggTheme.teal800,
                        letterSpacing: -0.3,
                        fontFamily: 'PlusJakartaSans')),
                const SizedBox(height: 8),
                Text(offerBody,
                    style: const TextStyle(
                        fontSize: 14,
                        color: BigDoggTheme.lightTextSecondary,
                        height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed:
                _busy ? null : () => _doCancel(acceptOffer: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: BigDoggTheme.gold500,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(t('Accepteer $months maanden gratis',
                    'Accept $months months free')),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() => _view = _ViewState.cancelConfirm),
            child: Text(t('Nee bedankt, doorgaan met opzeggen',
                'No thanks, continue cancelling')),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(_errorMessage!,
                style: const TextStyle(color: BigDoggTheme.error)),
          ],
        ],
      ),
    );
  }

  // Step 4: Final confirm ---------------------------------------

  Widget _cancelConfirmStep() {
    return _stepCard(
      stepIndex: 4,
      title: t('Laatste stap — weet je het zeker?',
          'Last step — are you sure?'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BigDoggTheme.error.withOpacity(0.05),
              border: Border.all(color: BigDoggTheme.error.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('Bij opzeggen:', 'When you cancel:'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: BigDoggTheme.error,
                      fontSize: 14),
                ),
                const SizedBox(height: 8),
                _bullet(t(
                    'Je behoudt toegang tot het einde van je huidige periode.',
                    'You keep access until the end of your current period.')),
                _bullet(t(
                    'Daarna kun je je gegevens alleen nog inzien (read-only).',
                    'After that, your data becomes read-only.')),
                _bullet(t(
                    'Geen nieuwe facturen, geen BTW-aangiftes, geen jaarrapporten.',
                    'No new invoices, no VAT reports, no annual reports.')),
                _bullet(t(
                    'Je kunt op elk moment opnieuw activeren op bigdogg.nl.',
                    'You can reactivate at any time on bigdogg.nl.')),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CheckboxListTile(
            value: _confirmCheckbox,
            onChanged: (v) =>
                setState(() => _confirmCheckbox = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: BigDoggTheme.error,
            title: Text(
              t('Ik begrijp wat ik verlies',
                  'I understand what I\'m losing'),
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: BigDoggTheme.lightTextPrimary),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: (!_confirmCheckbox || _busy)
                ? null
                : () => _doCancel(acceptOffer: false),
            style: _destructiveButtonStyle(),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(t('Definitief opzeggen', 'Definitely cancel')),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => setState(() => _view = _hubReturnState()),
            style: _primaryButtonStyle(),
            child: Text(t('Toch behouden', 'Keep my subscription')),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(_errorMessage!,
                style: const TextStyle(color: BigDoggTheme.error)),
          ],
        ],
      ),
    );
  }

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('· ',
                style: TextStyle(
                    color: BigDoggTheme.lightTextSecondary, fontSize: 14)),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13.5,
                      color: BigDoggTheme.lightTextSecondary,
                      height: 1.45)),
            ),
          ],
        ),
      );

  // Step 5: Cancellation confirmed ------------------------------

  Widget _cancelDoneStep() {
    final until = _accessUntil;
    String? untilLabel;
    if (until != null) {
      final local = until.toLocal();
      untilLabel = '${local.day}-${local.month}-${local.year}';
    }
    return _stepCard(
      stepIndex: 5,
      title: t('Opzegging bevestigd',
          'Cancellation confirmed'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: BigDoggTheme.lightTextHint.withOpacity(0.2),
                shape: BoxShape.circle),
            child: const Icon(Icons.event_busy_rounded,
                color: BigDoggTheme.lightTextSecondary, size: 36),
          ),
          const SizedBox(height: 16),
          if (untilLabel != null)
            Text(
              t('Je toegang loopt af op $untilLabel.',
                  'Your access ends on $untilLabel.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: BigDoggTheme.teal800),
            )
          else
            Text(
              t('Je abonnement is opgezegd.',
                  'Your subscription has been cancelled.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: BigDoggTheme.teal800),
            ),
          const SizedBox(height: 10),
          Text(
            t(
              'Tot die tijd werkt alles gewoon. Daarna kun je je gegevens nog steeds bekijken — alleen niet meer bewerken.',
              'Until then everything keeps working. After that you can still view your data — just not edit it.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13.5,
                color: BigDoggTheme.lightTextSecondary,
                height: 1.5),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _busy ? null : _reactivate,
            style: _primaryButtonStyle(),
            child: Text(t('Toch behouden — heractiveer',
                'Changed my mind — reactivate')),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go('/'),
            child: Text(t('Sluiten', 'Close')),
          ),
        ],
      ),
    );
  }

  // Branch: offer accepted ---------------------------------------

  Widget _offerAcceptedStep() {
    final months = _offerMonths ?? 3;
    return _stepCard(
      stepIndex: 5,
      title: t('Welkom terug 🎉', 'Welcome back 🎉'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
                color: BigDoggTheme.success, shape: BoxShape.circle),
            child: const Icon(Icons.celebration_rounded,
                color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            _plan == 'yearly'
                ? t('$months maanden extra toegevoegd',
                    '$months months added')
                : t('$months maanden gratis geactiveerd',
                    '$months months free activated'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: BigDoggTheme.teal800),
          ),
          const SizedBox(height: 10),
          Text(
            _plan == 'yearly'
                ? t(
                    'Je jaarabonnement is verlengd. Geniet ervan!',
                    'Your yearly subscription has been extended. Enjoy!',
                  )
                : t(
                    'De komende $months facturen zijn gratis. Daarna gaat je abonnement normaal verder.',
                    'Your next $months invoices are free. Then your subscription continues as normal.',
                  ),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14,
                color: BigDoggTheme.lightTextSecondary,
                height: 1.5),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.go('/'),
            style: _primaryButtonStyle(),
            child: Text(t('Sluiten', 'Close')),
          ),
        ],
      ),
    );
  }

  // Shared chrome ------------------------------------------------

  Widget _stepCard({
    required int stepIndex,
    required String title,
    required Widget child,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t('Stap $stepIndex van 5', 'Step $stepIndex of 5'),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: BigDoggTheme.lightTextHint,
                letterSpacing: 1.2),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: BigDoggTheme.teal800,
                fontFamily: 'PlusJakartaSans',
                letterSpacing: -0.4),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: child,
    );
  }

  Widget _loading() {
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

  Widget _noSubCard() {
    return _card(
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
                color: BigDoggTheme.teal800, shape: BoxShape.circle),
            child: const Icon(Icons.subscriptions_rounded,
                color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          Text(t('Nog geen abonnement', 'No subscription yet'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: BigDoggTheme.teal800)),
          const SizedBox(height: 8),
          Text(
            t('Kies een plan om door te gaan.', 'Pick a plan to get started.'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14, color: BigDoggTheme.lightTextSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.go(_pricingUrl()),
            style: _primaryButtonStyle(),
            child: Text(t('Bekijk de plannen', 'View plans')),
          ),
        ],
      ),
    );
  }

  Widget _errorCard() {
    return _card(
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
                color: BigDoggTheme.error, shape: BoxShape.circle),
            child: const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          Text(t('Er ging iets mis', 'Something went wrong'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: BigDoggTheme.teal800)),
          const SizedBox(height: 8),
          Text(
            _errorMessage ??
                t('Probeer het over een paar seconden opnieuw.',
                    'Please try again in a few seconds.'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14, color: BigDoggTheme.lightTextSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() => _view = _ViewState.loading);
              _loadHub();
            },
            style: _primaryButtonStyle(),
            child: Text(t('Opnieuw proberen', 'Try again')),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────

  Map<String, String> _authHeaders() => {
        'Authorization': 'Bearer ${_token ?? ''}',
        'Content-Type': 'application/json',
      };

  ButtonStyle _primaryButtonStyle() => ElevatedButton.styleFrom(
        backgroundColor: BigDoggTheme.teal800,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle:
            const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      );

  ButtonStyle _destructiveButtonStyle() => ElevatedButton.styleFrom(
        backgroundColor: BigDoggTheme.error,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle:
            const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      );

  _ViewState _hubReturnState() =>
      _isLegacyActive ? _ViewState.hubLegacyActive : _ViewState.hubActive;

  String? _humanPlan(String? plan) {
    switch (plan) {
      case 'monthly':
        return t('Maandelijks abonnement (€11,99/maand)',
            'Monthly subscription (€11.99/month)');
      case 'yearly':
        return t('Jaarlijks abonnement (€119,88/jaar)',
            'Yearly subscription (€119.88/year)');
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
}

class _Reason {
  final String value;
  final String label;
  const _Reason(this.value, this.label);
}
