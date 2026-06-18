import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../services/support_service.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  bool _isNl = true;

  // Anchor for the hero's "Bekijk hoe het werkt" / "See how it works" link.
  final GlobalKey _featuresKey = GlobalKey();

  String t(String nl, String en) => _isNl ? nl : en;

  // ─── Hero / CTA background gradient ─────────────────────────────
  // Decided: keep the hand-picked mint→cream tints (#F0FDFA → #FFFBEB) to match
  // the live bigdogg.nl look. These intentionally sit outside theme.dart.
  // Flip to `true` only if we later want the on-token teal100 → lightBg ramp.
  static const bool _useOnTokenHeroGradient = false;

  LinearGradient get _heroGradient => _useOnTokenHeroGradient
      ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BigDoggTheme.teal100, BigDoggTheme.lightBg],
        )
      : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0FDFA), Color(0xFFFFFBEB)],
        );

  void _scrollToFeatures() {
    final ctx = _featuresKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      alignment: 0.05,
    );
  }

  // ─── Shared primary CTA ─────────────────────────────────────────
  // One accent action repeated down the page. Teal-filled / white text:
  // strong, accessible contrast and on-brand. Gold stays the highlight accent.
  Widget _primaryCta(String label,
      {bool large = false, bool fullWidth = false}) {
    final btn = ElevatedButton(
      onPressed: () => context.go('/register'),
      style: ElevatedButton.styleFrom(
        backgroundColor: BigDoggTheme.teal800,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
            horizontal: large ? 32 : 24, vertical: large ? 18 : 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(large ? 12 : 10)),
        textStyle: TextStyle(
            fontSize: large ? 17 : 15, fontWeight: FontWeight.w700),
        elevation: large ? 4 : 2,
      ),
      child: Text(label),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;

    return Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildNav(isWide),
            _buildHero(isWide),
            _buildTrustStrip(isWide),
            _buildValueBand(isWide),
            _buildFeatures(isWide),
            _buildSwitching(isWide),
            _buildSupportCallout(isWide),
            if (kIsWeb) _buildPricing(isWide),
            _buildFinalCta(isWide),
            _buildAppStoreSection(isWide),
            _buildFooter(isWide),
          ],
        ),
      ),
    );
  }

  // ─── Nav ────────────────────────────────────────────────────────
  Widget _buildNav(bool isWide) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: isWide ? 64 : 16, vertical: 12),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        border:
            Border(bottom: BorderSide(color: BigDoggTheme.lightBorder)),
      ),
      child: Row(
        children: [
          Image.asset('assets/images/logo.png',
              width: isWide ? 72 : 64, height: isWide ? 72 : 64),
          const Spacer(),
          _langToggle(),
          const SizedBox(width: 8),
          if (isWide) ...[
            if (kIsWeb)
              TextButton(
                onPressed: () => context.go('/pricing'),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Text(t('Prijzen', 'Pricing'),
                    style: const TextStyle(
                        color: BigDoggTheme.teal800,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
            TextButton(
              onPressed: () => context.go('/login'),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: Text(t('Inloggen', 'Sign in'),
                  style: const TextStyle(
                      color: BigDoggTheme.teal800,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
            const SizedBox(width: 4),
          ] else ...[
            IconButton(
              onPressed: () => context.go('/login'),
              icon: const Icon(Icons.login_rounded,
                  color: BigDoggTheme.teal800, size: 20),
              tooltip: t('Inloggen', 'Sign in'),
              padding: const EdgeInsets.all(6),
              constraints:
                  const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            const SizedBox(width: 4),
          ],
          ElevatedButton(
            onPressed: () => context.go('/register'),
            style: ElevatedButton.styleFrom(
              backgroundColor: BigDoggTheme.teal800,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 20 : 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              textStyle: TextStyle(fontSize: isWide ? 13 : 12.5),
              elevation: 0,
            ),
            child: Text(t('Start gratis', 'Start free')),
          ),
        ],
      ),
    );
  }

  Widget _langToggle() {
    return GestureDetector(
      onTap: () => setState(() => _isNl = !_isNl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    );
  }

  // ─── Hero ───────────────────────────────────────────────────────
  Widget _buildHero(bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 64 : 20,
        vertical: isWide ? 96 : 56,
      ),
      decoration: BoxDecoration(gradient: _heroGradient),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 3, child: _buildHeroText(isWide)),
                const SizedBox(width: 64),
                Expanded(flex: 2, child: _buildHeroCard()),
              ],
            )
          : Column(
              children: [
                _buildHeroText(isWide),
                const SizedBox(height: 40),
                _buildHeroCard(),
              ],
            ),
    );
  }

  Widget _buildHeroText(bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: BigDoggTheme.gold500.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: BigDoggTheme.gold500.withOpacity(0.4)),
          ),
          child: Text(
            t('30 dagen gratis · Geen creditcard',
                '30 days free · No credit card'),
            style: const TextStyle(
                color: BigDoggTheme.gold600,
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          t(
            'Minder tijd kwijt aan je boekhouding.\nMeer aan ondernemen.',
            'Less time on your books.\nMore on your business.',
          ),
          style: TextStyle(
            fontSize: isWide ? 44 : 30,
            fontWeight: FontWeight.w800,
            color: BigDoggTheme.teal800,
            height: 1.18,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          t(
            kIsWeb
                ? 'Facturen, BTW en uren — AI-gestuurd en op één plek. Veel simpeler dan de boekhoudprogramma\'s die je nu gebruikt. Vanaf €9,99 per maand.'
                : 'Facturen, BTW en uren — AI-gestuurd en op één plek. Veel simpeler dan de boekhoudprogramma\'s die je nu gebruikt.',
            kIsWeb
                ? 'Invoices, VAT and hours — AI-driven, all in one place. Far simpler than the accounting tools you use now. From €9.99 a month.'
                : 'Invoices, VAT and hours — AI-driven, all in one place. Far simpler than the accounting tools you use now.',
          ),
          style: TextStyle(
            fontSize: isWide ? 17 : 15,
            color: BigDoggTheme.lightTextSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        if (isWide)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _primaryCta(
                  t('Start 30 dagen gratis', 'Start 30 days free'),
                  large: true),
              OutlinedButton(
                onPressed: _scrollToFeatures,
                style: OutlinedButton.styleFrom(
                  foregroundColor: BigDoggTheme.teal800,
                  side: const BorderSide(
                      color: BigDoggTheme.teal800, width: 1.5),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                child:
                    Text(t('Bekijk hoe het werkt', 'See how it works')),
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _primaryCta(
                  t('Start 30 dagen gratis', 'Start 30 days free'),
                  large: true, fullWidth: true),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _scrollToFeatures,
                style: OutlinedButton.styleFrom(
                  foregroundColor: BigDoggTheme.teal800,
                  side: const BorderSide(
                      color: BigDoggTheme.teal800, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                child:
                    Text(t('Bekijk hoe het werkt', 'See how it works')),
              ),
            ],
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _trustBadge(Icons.lock_outline,
                t('Geen creditcard', 'No credit card')),
            _trustBadge(Icons.cancel_outlined,
                t('Altijd opzegbaar', 'Cancel anytime')),
            _trustBadge(Icons.flag_outlined,
                t('Gemaakt in NL 🇳🇱', 'Made in NL 🇳🇱')),
          ],
        ),
      ],
    );
  }

  Widget _trustBadge(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: BigDoggTheme.lightTextHint),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: BigDoggTheme.lightTextHint, fontSize: 12)),
      ],
    );
  }

  Widget _winDot() => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: BigDoggTheme.lightTextHint.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
      );

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BigDoggTheme.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          // App-window chrome so the card reads as a product screenshot,
          // not a business card. No duplicate logo here — the nav has it.
          Row(
            children: [
              _winDot(),
              const SizedBox(width: 6),
              _winDot(),
              const SizedBox(width: 6),
              _winDot(),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: BigDoggTheme.gold500.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.auto_awesome,
                        size: 12, color: BigDoggTheme.gold600),
                    SizedBox(width: 4),
                    Text('AI-factuur',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: BigDoggTheme.gold600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('FACTUUR',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: BigDoggTheme.teal800,
                            fontSize: 11,
                            letterSpacing: 1.2)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: BigDoggTheme.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(t('Betaald', 'Paid'),
                          style: const TextStyle(
                              color: BigDoggTheme.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('ToraTora B.V.',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: BigDoggTheme.lightTextPrimary,
                        fontSize: 13)),
                const Text('2026-000042',
                    style: TextStyle(
                        color: BigDoggTheme.lightTextSecondary,
                        fontSize: 11)),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                _invoiceLineItem(
                    t('Coaching — 5 dagen', 'Coaching — 5 days'),
                    '€ 3.025,00'),
                _invoiceLineItem('21% BTW', '€ 635,25'),
                const Divider(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(t('Totaal', 'Total'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: BigDoggTheme.teal800,
                              fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    const Text('€ 3.660,25',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: BigDoggTheme.teal800,
                            fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BigDoggTheme.teal800.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: BigDoggTheme.teal800.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.smart_toy_outlined,
                    color: BigDoggTheme.teal800, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t(
                      '"5 dagen coaching voor ToraTora" →',
                      '"5 days coaching for ToraTora" →',
                    ),
                    style: const TextStyle(
                        fontSize: 12,
                        color: BigDoggTheme.teal800,
                        fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t('AI maakt je factuur in een paar seconden.',
                'AI writes your invoice in seconds.'),
            style: const TextStyle(
                fontSize: 11, color: BigDoggTheme.lightTextHint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _invoiceLineItem(String label, String amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11, color: BigDoggTheme.lightTextSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Text(amount,
              style: const TextStyle(
                  fontSize: 11, color: BigDoggTheme.lightTextSecondary)),
        ],
      ),
    );
  }

  // ─── Honest trust strip ─────────────────────────────────────────
  Widget _buildTrustStrip(bool isWide) {
    final items = [
      t('Net gelanceerd', 'Just launched'),
      if (kIsWeb) '${t('vanaf', 'from')} €9,99 / ${t('maand', 'month')}',
      t('30 dagen gratis', '30 days free'),
      t('Gemaakt in Nederland', 'Built in the Netherlands'),
      t('Data in de EU · AVG', 'Data in the EU · GDPR'),
    ];
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: isWide ? 64 : 20, vertical: 22),
      color: BigDoggTheme.teal800,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: isWide ? 28 : 14,
        runSpacing: 8,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Text(
              items[i],
              style: TextStyle(
                color: items[i].contains('€')
                    ? BigDoggTheme.gold400
                    : Colors.white70,
                fontSize: isWide ? 14 : 12.5,
                fontWeight: items[i].contains('€')
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
            if (i < items.length - 1)
              Text('·',
                  style: TextStyle(
                      color: Colors.white30,
                      fontSize: isWide ? 14 : 12.5)),
          ],
        ],
      ),
    );
  }

  // ─── Value band: the 3 highlighted differentiators ──────────────
  Widget _buildValueBand(bool isWide) {
    final cards = [
      {
        'icon': Icons.smart_toy_outlined,
        'title': t('Factuur uit één zin', 'Invoice from one sentence'),
        'body': t(
          'Typ kort wat je deed. BigDogg maakt de factuur compleet — met de juiste BTW, klantgegevens en je eigen logo.',
          'Type a short note about what you did. BigDogg writes the full invoice — with the right VAT, client details and your own logo.',
        ),
      },
      {
        'icon': Icons.insights_outlined,
        'title':
            t('Jaarrapport mét belastingtips', 'Annual report with tax tips'),
        'body': t(
          'Aan het eind van het jaar een compleet rapport met suggesties voor aftrekposten op basis van jouw eigen cijfers.',
          'At year-end, a complete report with deduction suggestions based on your own numbers.',
        ),
      },
      {
        'icon': Icons.bolt_outlined,
        'title': t('Overstappen in 5 minuten', 'Switch in 5 minutes'),
        'body': t(
          'Sleep je oude facturen erin. AI leest ze automatisch in en bouwt meteen je overzicht op.',
          'Drop in your old invoices. AI reads them automatically and builds your overview right away.',
        ),
      },
    ];

    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: isWide ? 64 : 20, vertical: 64),
      child: Column(
        children: [
          Text(
            t('Het grootste verschil? AI doet het zware werk.',
                'The big difference? AI does the heavy lifting.'),
            style: TextStyle(
                fontSize: isWide ? 30 : 24,
                fontWeight: FontWeight.w800,
                color: BigDoggTheme.teal800,
                letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            t('Drie dingen die je bij geen ander pakket zo vindt.',
                'Three things you won\'t find quite like this anywhere else.'),
            style: const TextStyle(
                fontSize: 15, color: BigDoggTheme.lightTextSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: cards
                      .map((c) => Expanded(child: _highlightCard(c)))
                      .toList(),
                )
              : Column(
                  children: cards
                      .map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _highlightCard(c),
                          ))
                      .toList(),
                ),
        ],
      ),
    );
  }

  Widget _highlightCard(Map c) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BigDoggTheme.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BigDoggTheme.gold500.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(c['icon'] as IconData,
                color: BigDoggTheme.gold600, size: 24),
          ),
          const SizedBox(height: 16),
          Text(c['title'] as String,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: BigDoggTheme.teal800,
                  letterSpacing: -0.3,
                  height: 1.3)),
          const SizedBox(height: 8),
          Text(c['body'] as String,
              style: const TextStyle(
                  color: BigDoggTheme.lightTextSecondary,
                  fontSize: 14,
                  height: 1.55)),
        ],
      ),
    );
  }

  // ─── Features, grouped by benefit & ranked ──────────────────────
  Widget _buildFeatures(bool isWide) {
    final groups = [
      {
        'icon': Icons.receipt_long_outlined,
        'title': t('Facturen & BTW op de automatische piloot',
            'Invoices & VAT on autopilot'),
        'payoff': t('Van klus naar betaalde factuur in seconden.',
            'From job done to invoice paid in seconds.'),
        'items': [
          t('AI-facturen uit één zin', 'AI invoices from one sentence'),
          t('BTW-aangifte per kwartaal in één klik',
              'Quarterly VAT report in one click'),
          t('iDEAL- en creditcard-betaallink op de factuur (via Stripe)',
              'iDEAL & card payment link on the invoice (via Stripe)'),
          t('Offertes maken en omzetten naar facturen',
              'Create quotes and turn them into invoices'),
        ],
      },
      {
        'icon': Icons.query_stats_outlined,
        'title': t('Grip op je cijfers', 'A grip on your numbers'),
        'payoff':
            t('Altijd weten waar je staat.', 'Always know where you stand.'),
        'items': [
          t('Jaarrapport met tips voor aftrekposten',
              'Annual report with deduction tips'),
          t('Urencriterium-tracker (1.225 uur)',
              'Hours-criterion tracker (1,225 hours)'),
          t('Investeringen en afschrijvingen automatisch berekend',
              'Investments and depreciation calculated automatically'),
        ],
      },
      {
        'icon': Icons.account_balance_outlined,
        'title': t('Je bank en bonnen, automatisch verwerkt',
            'Your bank and receipts, handled automatically'),
        'payoff': t('Geen overtypen meer.', 'No more retyping.'),
        'items': [
          t('Bankkoppeling via TrueLayer — transacties komen vanzelf binnen',
              'Bank connection via TrueLayer — transactions come in automatically'),
          t('Bonnen scannen: AI leest bedrag, BTW en categorie',
              'Scan receipts: AI reads the amount, VAT and category'),
        ],
      },
      {
        'icon': Icons.support_agent_outlined,
        'title':
            t('Hulp van een mens — geen ticketsysteem', 'Help from a human — no ticket queue'),
        'payoff': t('Vastgelopen? Dan bel ik je gewoon.',
            'Stuck? I\'ll just call you.'),
        'items': [
          t('Persoonlijke support + videogesprek met de oprichter',
              'Personal support + video call with the founder'),
          t('Accountant-portaal: geef je boekhouder veilig toegang',
              'Accountant portal: give your bookkeeper secure access'),
          t('Klanten vullen hun eigen gegevens in (self-onboarding)',
              'Clients fill in their own details (self-onboarding)'),
        ],
      },
    ];

    return Container(
      key: _featuresKey,
      padding:
          EdgeInsets.symmetric(horizontal: isWide ? 64 : 20, vertical: 64),
      color: BigDoggTheme.lightSurface,
      child: Column(
        children: [
          Text(
            t('Alles wat je nodig hebt — en niets wat je niet gebruikt.',
                'Everything you need — and nothing you don\'t.'),
            style: TextStyle(
                fontSize: isWide ? 30 : 24,
                fontWeight: FontWeight.w800,
                color: BigDoggTheme.teal800,
                letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            t('Gegroepeerd op wat het je oplevert. Het belangrijkste eerst.',
                'Grouped by what it does for you. The most important first.'),
            style: const TextStyle(
                fontSize: 15, color: BigDoggTheme.lightTextSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          if (isWide)
            Column(
              children: [
                // IntrinsicHeight bounds the row's height so the two cards can
                // stretch to equal height. Without it, a stretch-Row inside a
                // scroll view gets unbounded height and throws (blanking the
                // rest of the page).
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _benefitGroupCard(groups[0])),
                      Expanded(child: _benefitGroupCard(groups[1])),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _benefitGroupCard(groups[2])),
                      Expanded(child: _benefitGroupCard(groups[3])),
                    ],
                  ),
                ),
              ],
            )
          else
            Column(
              children: groups
                  .map((g) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _benefitGroupCard(g),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _benefitGroupCard(Map g) {
    final items = (g['items'] as List).cast<String>();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BigDoggTheme.teal800.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(g['icon'] as IconData,
                    color: BigDoggTheme.teal800, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(g['title'] as String,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: BigDoggTheme.teal800,
                        letterSpacing: -0.3,
                        height: 1.25)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(g['payoff'] as String,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: BigDoggTheme.gold600,
                  height: 1.4)),
          const SizedBox(height: 16),
          ...items.asMap().entries.map((e) => Padding(
                padding: EdgeInsets.only(
                    bottom: e.key == items.length - 1 ? 0 : 10),
                child: _featureLine(e.value),
              )),
        ],
      ),
    );
  }

  Widget _featureLine(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.check_circle_outline,
              size: 16, color: BigDoggTheme.success),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 13.5,
                  color: BigDoggTheme.lightTextSecondary,
                  height: 1.45)),
        ),
      ],
    );
  }

  // ─── Switching section (slim, honest, no per-brand grid) ────────
  Widget _switchReason(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle,
            size: 20, color: BigDoggTheme.success),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 14.5,
                  color: BigDoggTheme.lightTextPrimary,
                  height: 1.5)),
        ),
      ],
    );
  }

  // Prominent "switch in 5 minutes" banner — the main objection-killer for
  // people leaving another tool. Emphasised: bigger, explains the automatic
  // analysis + safe storage, and that there's no manual work to get wrong.
  Widget _buildImportHighlight(bool isWide) {
    final steps = [
      t('Sleep je oude facturen en bonnen erin',
          'Drop in your old invoices and receipts'),
      t('AI leest en categoriseert alles automatisch',
          'AI reads and categorises everything automatically'),
      t('Je overzicht én jaarrapport staan er meteen',
          'Your overview and annual report are ready instantly'),
    ];

    final iconBox = Container(
      padding: EdgeInsets.all(isWide ? 16 : 12),
      decoration: BoxDecoration(
        color: BigDoggTheme.gold500,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.bolt_rounded,
          color: Colors.white, size: isWide ? 30 : 24),
    );

    final textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('Stap over in 5 minuten — zonder iets fout te doen.',
              'Switch in 5 minutes — without getting anything wrong.'),
          style: TextStyle(
            color: Colors.white,
            fontSize: isWide ? 26 : 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          t(
            'Sleep je oude facturen en bonnen erin — uit je vorige boekhoudpakket, van je boekhouder of gewoon als PDF. BigDogg analyseert alles automatisch, herkent bedragen, BTW en datums en zet ze meteen op de juiste plek. Geen handmatig overtypen, niets om te vergeten.',
            'Drag your old invoices and receipts in — from your previous accounting tool, your bookkeeper or just as PDFs. BigDogg analyses everything automatically, recognises amounts, VAT and dates, and files them in the right place. No manual retyping, nothing to forget.',
          ),
          style: const TextStyle(
              color: Colors.white70, fontSize: 14.5, height: 1.55),
        ),
        const SizedBox(height: 18),
        ...steps.asMap().entries.map((e) => Padding(
              padding: EdgeInsets.only(
                  bottom: e.key == steps.length - 1 ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: BigDoggTheme.gold500,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text('${e.key + 1}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(e.value,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.4)),
                  ),
                ],
              ),
            )),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.lock_outline,
                size: 15, color: BigDoggTheme.gold400),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t(
                    'Alles wordt automatisch geanalyseerd en veilig opgeslagen in de EU (AVG).',
                    'Everything is analysed automatically and stored securely in the EU (GDPR).'),
                style: const TextStyle(
                    color: BigDoggTheme.gold400,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: isWide ? 980 : 680),
        padding: EdgeInsets.all(isWide ? 36 : 24),
        decoration: BoxDecoration(
          color: BigDoggTheme.teal800,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: BigDoggTheme.teal800.withOpacity(0.25),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  iconBox,
                  const SizedBox(width: 24),
                  Expanded(child: textBlock),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  iconBox,
                  const SizedBox(height: 16),
                  textBlock,
                ],
              ),
      ),
    );
  }

  Widget _buildSwitching(bool isWide) {
    final reasons = [
      t('AI-facturen uit één zin — geen ander pakket doet dit zo.',
          'AI invoices from one sentence — no other tool does this.'),
      t('AI-jaarrapport met tips voor aftrekposten op basis van jouw cijfers.',
          'AI annual report with deduction tips based on your numbers.'),
      if (kIsWeb)
        t('Vanaf €9,99 per maand — alles inbegrepen, geen extra pakketten.',
            'From €9.99 a month — everything included, no add-ons.')
      else
        t('Alles inbegrepen — geen losse pakketten of add-ons.',
            'Everything included — no separate plans or add-ons.'),
      t('Menselijke support: e-mail én een videogesprek als het nodig is.',
          'Human support: email and a video call if you need it.'),
    ];

    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: isWide ? 64 : 20, vertical: 64),
      child: Column(
        children: [
          Text(
            t('Overstappen van je huidige pakket of boekhouder? Zo gebeurd.',
                'Switching from your current tool or bookkeeper? Done in minutes.'),
            style: TextStyle(
                fontSize: isWide ? 30 : 24,
                fontWeight: FontWeight.w800,
                color: BigDoggTheme.teal800,
                letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            t(
              'Wij zeggen niet dat anderen slecht zijn. Dit is gewoon wat BigDogg anders doet.',
              'We\'re not saying others are bad. This is simply what BigDogg does differently.',
            ),
            style: const TextStyle(
                fontSize: 15, color: BigDoggTheme.lightTextSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          Center(
            child: Container(
              constraints:
                  BoxConstraints(maxWidth: isWide ? 980 : 680),
              padding: EdgeInsets.all(isWide ? 32 : 22),
              decoration: BoxDecoration(
                color: BigDoggTheme.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BigDoggTheme.lightBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _switchReason(reasons[0]),
                              const SizedBox(height: 16),
                              _switchReason(reasons[1]),
                            ],
                          ),
                        ),
                        const SizedBox(width: 40),
                        Expanded(
                          child: Column(
                            children: [
                              _switchReason(reasons[2]),
                              const SizedBox(height: 16),
                              _switchReason(reasons[3]),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < reasons.length; i++) ...[
                          if (i > 0) const SizedBox(height: 16),
                          _switchReason(reasons[i]),
                        ],
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),
          _buildImportHighlight(isWide),
        ],
      ),
    );
  }

  // ─── Support callout ─────────────────────────────────────────────
  Widget _buildSupportCallout(bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 64 : 20, vertical: isWide ? 32 : 24),
      color: BigDoggTheme.lightBg,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 760),
          padding: EdgeInsets.all(isWide ? 36 : 24),
          decoration: BoxDecoration(
            color: BigDoggTheme.teal800,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: BigDoggTheme.teal800.withOpacity(0.25),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _supportAvatar(big: true),
                    const SizedBox(width: 28),
                    Expanded(child: _supportTextBlock()),
                    const SizedBox(width: 24),
                    _supportButton(),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _supportAvatar(big: false),
                    const SizedBox(height: 16),
                    _supportTextBlock(),
                    const SizedBox(height: 20),
                    SizedBox(
                        width: double.infinity, child: _supportButton()),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _supportAvatar({required bool big}) {
    final size = big ? 80.0 : 64.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: BigDoggTheme.gold500,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: BigDoggTheme.gold500.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(Icons.person_rounded,
          color: Colors.white, size: size * 0.55),
    );
  }

  Widget _supportTextBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('Vastgelopen? Dan bel ik je gewoon op.',
              'Stuck? I\'ll just call you.'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          t(
            'BigDogg is gebouwd met AI, maar de mensen erachter zijn gewoon menselijk. Kom je er niet uit via e-mail? Dan spring ik — de oprichter — zelf op een videogesprek met je om het op te lossen. Geen chatbot, geen ticketsysteem, geen wachtrij. Gewoon een gesprek.',
            'BigDogg is built with AI, but the people behind it are entirely human. If email doesn\'t solve it, I — the founder — will personally jump on a video call with you to sort it out. No chatbot, no ticket queue, no waiting. Just a conversation.',
          ),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          t('E-mail support + persoonlijk videogesprek indien nodig',
              'Email support + personal video call if needed'),
          style: const TextStyle(
            color: BigDoggTheme.gold400,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _supportButton() {
    return ElevatedButton(
      onPressed: () => _showSupportDialog(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: BigDoggTheme.gold500,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        textStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
      child: Text(t('Stel je vraag', 'Ask a question')),
    );
  }

  void _showSupportDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => _SupportDialog(isNl: _isNl),
    );
  }

  // ─── Pricing (web only) ─────────────────────────────────────────
  Widget _buildPricing(bool isWide) {
    final list = [
      t('✓ Onbeperkt facturen & offertes', '✓ Unlimited invoices & quotes'),
      t('✓ AI-factuur uit één zin', '✓ AI invoice from one sentence'),
      t('✓ BTW-aangifte per kwartaal', '✓ Quarterly VAT report'),
      t('✓ Jaarrapport met aftrekposten-tips',
          '✓ Annual report with deduction tips'),
      t('✓ Bankkoppeling, bonnen scannen & uren',
          '✓ Bank connection, receipt scanning & hours'),
      t('✓ iDEAL-betaallinks via Stripe', '✓ iDEAL payment links via Stripe'),
      t('✓ Menselijke support + videogesprek',
          '✓ Human support + video call'),
    ];

    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: isWide ? 64 : 20, vertical: 64),
      color: BigDoggTheme.lightSurface,
      child: Column(
        children: [
          Text(
            t('Eén plan. Alles inbegrepen.',
                'One plan. Everything included.'),
            style: TextStyle(
                fontSize: isWide ? 30 : 24,
                fontWeight: FontWeight.w800,
                color: BigDoggTheme.teal800,
                letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            t('Eén vaste prijs. Geen verrassingen.',
                'One flat price. No surprises.'),
            style: const TextStyle(
                fontSize: 15, color: BigDoggTheme.lightTextSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: BigDoggTheme.teal800,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: BigDoggTheme.teal800.withOpacity(0.35),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(t('vanaf', 'from'),
                      style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3)),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('€9,99',
                        style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                          t('/ maand bij jaarlijks',
                              '/ month billed yearly'),
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 14)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  t('Of €11,99 maandelijks', 'Or €11.99 monthly'),
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: BigDoggTheme.gold500.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    t('30 dagen gratis · Geen creditcard nodig',
                        '30 days free · No credit card needed'),
                    style: const TextStyle(
                        color: BigDoggTheme.gold400,
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.white24),
                const SizedBox(height: 16),
                ...list.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(item,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14)),
                    )),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      const Text('🇳🇱', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t(
                            'Data in Frankfurt (EU) · voldoet aan de AVG',
                            'Data in Frankfurt (EU) · GDPR compliant',
                          ),
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go('/register'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BigDoggTheme.gold500,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                      elevation: 0,
                    ),
                    child:
                        Text(t('Start gratis →', 'Start free →')),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    t(
                        'Geen creditcard nodig · Altijd opzegbaar · iDEAL via Stripe',
                        'No credit card · Cancel anytime · iDEAL via Stripe'),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Referral — small, calm mention. Factual, no hype.
          Text(
            t('Iemand uitnodigen? Jullie krijgen allebei korting.',
                'Invite someone? You both get a discount.'),
            style: const TextStyle(
                fontSize: 13, color: BigDoggTheme.lightTextHint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── Final CTA ──────────────────────────────────────────────────
  Widget _buildFinalCta(bool isWide) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: isWide ? 64 : 20, vertical: 64),
      decoration: BoxDecoration(gradient: _heroGradient),
      child: Column(
        children: [
          Text(
            t('Klaar om tijd terug te winnen?', 'Ready to win back your time?'),
            style: TextStyle(
                fontSize: isWide ? 32 : 26,
                fontWeight: FontWeight.w800,
                color: BigDoggTheme.teal800,
                letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            t(
              'Probeer BigDogg 30 dagen gratis. Bevalt het niet, dan zeg je gewoon op.',
              'Try BigDogg free for 30 days. Don\'t like it? Just cancel.',
            ),
            style: const TextStyle(
                fontSize: 16,
                color: BigDoggTheme.lightTextSecondary,
                height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _primaryCta(
              t('Start gratis — geen creditcard nodig',
                  'Start free — no credit card needed'),
              large: true),
          const SizedBox(height: 16),
          Text(
            kIsWeb
                ? t(
                    '30 dagen gratis. Daarna vanaf €9,99 per maand (jaarlijks). Altijd opzegbaar.',
                    '30 days free. Then from €9.99 per month (billed yearly). Cancel anytime.')
                : t('30 dagen gratis proberen. Altijd opzegbaar.',
                    '30 days free trial. Cancel anytime.'),
            style: const TextStyle(
                color: BigDoggTheme.lightTextHint, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── App store badges ────────────────────────────────────────────
  // iOS app isn't live yet — flip to true once it ships.
  static const bool iosAppLive = false;
  static const String _playUrl =
      'https://play.google.com/store/apps/details?id=nl.bigdogg.app';
  static const String _appStoreUrl =
      'https://apps.apple.com/nl/app/bigdogg/id000000000';

  Future<void> _openStoreUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {/* best effort */}
  }

  Widget _buildAppStoreSection(bool isWide) {
    final play = _storeBadge(
      icon: Icons.shop_outlined,
      topLine: t('Beschikbaar op', 'Get it on'),
      bottomLine: 'Google Play',
      onTap: () => _openStoreUrl(_playUrl),
    );
    final appStore = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _storeBadge(
          icon: Icons.apple,
          topLine: t('Download in de', 'Download on the'),
          bottomLine: 'App Store',
          onTap: iosAppLive ? () => _openStoreUrl(_appStoreUrl) : null,
        ),
        if (!iosAppLive) ...[
          const SizedBox(height: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: BigDoggTheme.lightBorder,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              t('Binnenkort', 'Coming Soon'),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: BigDoggTheme.lightTextSecondary,
              ),
            ),
          ),
        ],
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 64 : 24, vertical: isWide ? 56 : 40),
      color: BigDoggTheme.lightBg,
      child: Column(
        children: [
          Text(
            t('Ook beschikbaar als app', 'Also available as an app'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isWide ? 28 : 22,
              fontWeight: FontWeight.bold,
              color: BigDoggTheme.teal800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            t('Onderweg je administratie bijwerken — op iedere telefoon.',
                'Update your books on the go — on any phone.'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14, color: BigDoggTheme.lightTextSecondary),
          ),
          const SizedBox(height: 28),
          if (isWide)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                play,
                const SizedBox(width: 16),
                appStore,
              ],
            )
          else
            Column(
              children: [
                play,
                const SizedBox(height: 16),
                appStore,
              ],
            ),
        ],
      ),
    );
  }

  /// Official-badge-proportioned button (~3:1). Dark pill, store icon on
  /// the left, two stacked text lines on the right.
  Widget _storeBadge({
    required IconData icon,
    required String topLine,
    required String bottomLine,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.55,
      child: Material(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 180,
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topLine,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          height: 1.1),
                    ),
                    Text(
                      bottomLine,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          height: 1.2),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Footer ──────────────────────────────────────────────────────
  Widget _buildFooter(bool isWide) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: isWide ? 64 : 20, vertical: 28),
      color: BigDoggTheme.teal800,
      child: isWide
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Image.asset('assets/images/logo.png',
                        width: 28, height: 28),
                    const SizedBox(width: 8),
                    const Text('BigDogg',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                Text(
                  t('© 2026 BigDogg · Voor Nederlandse ZZP\'ers',
                      '© 2026 BigDogg · For Dutch freelancers'),
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _isNl = !_isNl),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: BigDoggTheme.gold500.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color:
                                  BigDoggTheme.gold500.withOpacity(0.4)),
                        ),
                        child: Text(
                          _isNl ? 'EN' : 'NL',
                          style: const TextStyle(
                              color: BigDoggTheme.gold400,
                              fontWeight: FontWeight.w700,
                              fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => _showTerms(context),
                      child: Text(
                          t('Algemene Voorwaarden', 'Terms & Conditions'),
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(t('Inloggen', 'Sign in'),
                          style:
                              const TextStyle(color: Colors.white60)),
                    ),
                  ],
                ),
              ],
            )
          : Column(
              children: [
                Row(
                  children: [
                    Image.asset('assets/images/logo.png',
                        width: 28, height: 28),
                    const SizedBox(width: 8),
                    const Text('BigDogg',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _isNl = !_isNl),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: BigDoggTheme.gold500.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color:
                                  BigDoggTheme.gold500.withOpacity(0.4)),
                        ),
                        child: Text(
                          _isNl ? 'EN' : 'NL',
                          style: const TextStyle(
                              color: BigDoggTheme.gold400,
                              fontWeight: FontWeight.w700,
                              fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(t('Inloggen', 'Sign in'),
                          style:
                              const TextStyle(color: Colors.white60)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _showTerms(context),
                  child: Text(
                      t('Algemene Voorwaarden', 'Terms & Conditions'),
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 12)),
                ),
                const SizedBox(height: 4),
                Text(
                  t('© 2026 BigDogg · Voor Nederlandse ZZP\'ers',
                      '© 2026 BigDogg · For Dutch freelancers'),
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }

  // ─── Terms dialog ────────────────────────────────────────────────
  void _showTerms(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 600),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: BigDoggTheme.teal800,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t('Algemene Voorwaarden', 'Terms & Conditions'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _termsText(),
                    style: const TextStyle(
                        fontSize: 13,
                        color: BigDoggTheme.lightTextPrimary,
                        height: 1.7),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(color: BigDoggTheme.lightBorder)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(t('Sluiten', 'Close')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _termsText() {
    if (_isNl) {
      return '''Algemene Voorwaarden — BigDogg
Versie 1.0 | Ingangsdatum: 1 januari 2026

1. OVER BIGDOGG
BigDogg is een online boekhoud- en facturatiedienst voor zelfstandigen en ZZP'ers in Nederland, aangeboden door BigDogg (hierna: "BigDogg", "wij", "ons"). Door gebruik te maken van onze diensten ga je akkoord met deze voorwaarden.

2. DIENSTVERLENING
BigDogg biedt tools voor facturatie, uitgavenbeheer, BTW-overzichten en financiële rapportages. Wij streven naar correctheid en beschikbaarheid van onze diensten, maar bieden geen garanties met betrekking tot volledigheid of geschiktheid voor specifieke fiscale of juridische doeleinden.

3. ABONNEMENT EN BETALING
Het abonnement bedraagt €11,99 per maand of €119,88 per jaar (€9,99 effectief per maand). Na een gratis proefperiode van 30 dagen wordt er overgegaan op een betaald abonnement, tenzij je vóór het einde van de proefperiode opzegt. Opzegging kan op elk moment via de instellingen in de app. Je behoudt toegang tot het einde van de lopende betaalperiode.

4. VERANTWOORDELIJKHEID VOOR ADMINISTRATIE
BigDogg ondersteunt jou bij je administratie, maar de volledige verantwoordelijkheid voor de juistheid, volledigheid en tijdige indiening van je belastingaangiftes, facturen en overige administratieve verplichtingen ligt bij jou als gebruiker. Wij raden je nadrukkelijk aan om regelmatig lokale back-ups te maken van al je facturen, rapporten en financiële documenten door deze te downloaden en op te slaan op een eigen, veilige locatie. BigDogg is niet aansprakelijk voor verlies van gegevens als gevolg van technische storingen, beëindiging van het account of andere omstandigheden buiten onze directe controle.

5. GEGEVENSVERWERKING EN PRIVACY
Wij verwerken persoonsgegevens in overeenstemming met de Algemene Verordening Gegevensbescherming (AVG). Je gegevens worden uitsluitend gebruikt voor het leveren van de dienst en worden niet verkocht aan derden. Bij beëindiging van je account worden je gegevens verwijderd conform ons bewaarbeleid.

6. AANSPRAKELIJKHEIDSBEPERKING
BigDogg is niet aansprakelijk voor indirecte schade, gederfde inkomsten, gemiste belastingvoordelen of schade voortvloeiend uit onjuist gebruik van het platform. De totale aansprakelijkheid van BigDogg is beperkt tot het bedrag dat je in de afgelopen drie maanden aan ons hebt betaald.

7. INTELLECTUEEL EIGENDOM
Alle inhoud, functionaliteiten en technologie van BigDogg zijn eigendom van BigDogg en mogen niet worden gekopieerd, verspreid of gebruikt zonder schriftelijke toestemming.

8. WIJZIGINGEN
Wij behouden het recht voor deze voorwaarden te wijzigen. Wezenlijke wijzigingen worden ten minste 30 dagen van tevoren per e-mail aangekondigd. Voortgezet gebruik van de dienst na de ingangsdatum van de wijziging geldt als aanvaarding.

9. TOEPASSELIJK RECHT
Op deze voorwaarden is Nederlands recht van toepassing. Geschillen worden voorgelegd aan de bevoegde rechter in Nederland.

10. CONTACT
Voor vragen over deze voorwaarden: info@bigdogg.nl''';
    } else {
      return '''Terms & Conditions — BigDogg
Version 1.0 | Effective date: 1 January 2026

1. ABOUT BIGDOGG
BigDogg is an online accounting and invoicing service for freelancers in the Netherlands, provided by BigDogg (hereinafter: "BigDogg", "we", "us"). By using our services, you agree to these terms.

2. SERVICES
BigDogg provides tools for invoicing, expense management, VAT overviews and financial reporting. We strive for accuracy and availability of our services, but make no guarantees regarding completeness or suitability for specific tax or legal purposes.

3. SUBSCRIPTION AND PAYMENT
The subscription fee is €11.99 per month or €119.88 per year (effectively €9.99 / month). After a 30-day free trial, a paid subscription begins unless cancelled before the end of the trial period. You may cancel at any time via the settings in the app. You retain access until the end of the current billing period.

4. RESPONSIBILITY FOR YOUR ADMINISTRATION
BigDogg supports you in managing your administration, but full responsibility for the accuracy, completeness and timely submission of your tax returns, invoices and other administrative obligations rests with you as the user. We strongly encourage you to regularly create local backups of all your invoices, reports and financial documents by downloading and saving them to a secure location of your own. BigDogg is not liable for data loss resulting from technical failures, account termination or other circumstances beyond our direct control.

5. DATA PROCESSING AND PRIVACY
We process personal data in accordance with the General Data Protection Regulation (GDPR). Your data is used solely to provide the service and is not sold to third parties. Upon account termination, your data will be deleted in accordance with our retention policy.

6. LIMITATION OF LIABILITY
BigDogg is not liable for indirect damages, lost revenue, missed tax benefits or damage resulting from improper use of the platform. BigDogg's total liability is limited to the amount you have paid us in the preceding three months.

7. INTELLECTUAL PROPERTY
All content, features and technology of BigDogg are owned by BigDogg and may not be copied, distributed or used without written permission.

8. CHANGES
We reserve the right to amend these terms. Material changes will be announced by email at least 30 days in advance. Continued use of the service after the effective date of the change constitutes acceptance.

9. GOVERNING LAW
These terms are governed by Dutch law. Disputes will be submitted to the competent court in the Netherlands.

10. CONTACT
For questions about these terms: info@bigdogg.nl''';
    }
  }
}

// ─── Support dialog ─────────────────────────────────────────────
class _SupportDialog extends StatefulWidget {
  final bool isNl;
  const _SupportDialog({required this.isNl});

  @override
  State<_SupportDialog> createState() => _SupportDialogState();
}

class _SupportDialogState extends State<_SupportDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _message = TextEditingController();
  String _preferred = 'email'; // 'email' | 'video'
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  String t(String nl, String en) => widget.isNl ? nl : en;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final msg = _message.text.trim();
    if (name.isEmpty ||
        email.isEmpty ||
        msg.isEmpty ||
        !email.contains('@')) {
      setState(() => _error =
          t('Vul alle velden in.', 'Please fill in all fields.'));
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final ok = await SupportService.submit(
      name: name,
      email: email,
      message: msg,
      preferredContact: _preferred,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (ok) {
        _submitted = true;
      } else {
        _error = t(
          'Versturen mislukt. Mail ons op info@bigdogg.nl',
          'Couldn\'t send. Email us at info@bigdogg.nl',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: BigDoggTheme.lightSurface,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: SingleChildScrollView(
          child: _submitted ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: BigDoggTheme.success.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.check_rounded,
              color: BigDoggTheme.success, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          t('Bedankt!', 'Thanks!'),
          style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: BigDoggTheme.teal800,
              letterSpacing: -0.4),
        ),
        const SizedBox(height: 8),
        Text(
          t('Ik neem binnen 24 uur contact met je op.',
              'I\'ll be in touch within 24 hours.'),
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 14,
              color: BigDoggTheme.lightTextSecondary,
              height: 1.5),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: BigDoggTheme.teal800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(t('Sluiten', 'Close')),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                t('Stel je vraag', 'Ask a question'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: BigDoggTheme.teal800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close,
                  color: BigDoggTheme.lightTextSecondary),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          t('Ik kom binnen 24 uur bij je terug.',
              'I\'ll get back to you within 24 hours.'),
          style: const TextStyle(
              fontSize: 13, color: BigDoggTheme.lightTextSecondary),
        ),
        const SizedBox(height: 18),
        _label(t('Naam', 'Name')),
        const SizedBox(height: 6),
        TextField(controller: _name, decoration: _decoration()),
        const SizedBox(height: 14),
        _label(t('E-mailadres', 'Email address')),
        const SizedBox(height: 6),
        TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: _decoration()),
        const SizedBox(height: 14),
        _label(t('Je vraag', 'Your question')),
        const SizedBox(height: 6),
        TextField(
            controller: _message, maxLines: 4, decoration: _decoration()),
        const SizedBox(height: 18),
        _label(t('Hoe wil je antwoord?', 'How would you like a reply?')),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _prefChip('email', Icons.email_outlined,
                    t('E-mail', 'Email'))),
            const SizedBox(width: 8),
            Expanded(
                child: _prefChip('video', Icons.videocam_outlined,
                    t('Videogesprek', 'Video call'))),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: BigDoggTheme.error.withOpacity(0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded,
                    color: BigDoggTheme.error, size: 16),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            color: BigDoggTheme.error, fontSize: 12))),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: BigDoggTheme.teal800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700),
              elevation: 0,
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : Text(t('Versturen', 'Send')),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: BigDoggTheme.teal800,
            letterSpacing: 0.1),
      );

  InputDecoration _decoration() => InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: BigDoggTheme.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: BigDoggTheme.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: BigDoggTheme.teal800, width: 1.5),
        ),
      );

  Widget _prefChip(String value, IconData icon, String label) {
    final selected = _preferred == value;
    return GestureDetector(
      onTap: () => setState(() => _preferred = value),
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? BigDoggTheme.teal800
              : BigDoggTheme.lightSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? BigDoggTheme.teal800
                : BigDoggTheme.lightBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: selected
                    ? Colors.white
                    : BigDoggTheme.lightTextSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : BigDoggTheme.lightTextPrimary,
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
