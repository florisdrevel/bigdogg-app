import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  bool _isNl = true;

  String t(String nl, String en) => _isNl ? nl : en;

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
            _buildSocialProof(isWide),
            _buildFeatures(isWide),
            _buildComparison(isWide),
            _buildPricing(isWide),
            _buildFinalCta(isWide),
            _buildFooter(isWide),
          ],
        ),
      ),
    );
  }

  Widget _buildNav(bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 64 : 16, vertical: 12),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        border: Border(
            bottom: BorderSide(color: BigDoggTheme.lightBorder)),
      ),
      child: Row(
        children: [
          Image.asset('assets/images/logo.png', width: 36, height: 36),
          const SizedBox(width: 8),
          const Text('BigDogg',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: BigDoggTheme.teal800)),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _isNl = !_isNl),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: BigDoggTheme.gold500.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: BigDoggTheme.gold500.withOpacity(0.4)),
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
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => context.go('/login'),
            style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8)),
            child: Text(t('Inloggen', 'Sign in'),
                style: const TextStyle(
                    color: BigDoggTheme.teal800,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: () => context.go('/register'),
            style: ElevatedButton.styleFrom(
              backgroundColor: BigDoggTheme.teal800,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 20 : 12, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 13),
            ),
            child: Text(t('Gratis proberen', 'Try for free')),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 64 : 20,
        vertical: isWide ? 96 : 48,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0FDFA), Color(0xFFFFFBEB)],
        ),
      ),
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
            border: Border.all(
                color: BigDoggTheme.gold500.withOpacity(0.4)),
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
            'Stop met te veel betalen\nvoor je administratie.',
            'Stop overpaying\nfor your administration.',
          ),
          style: TextStyle(
            fontSize: isWide ? 46 : 34,
            fontWeight: FontWeight.w800,
            color: BigDoggTheme.teal800,
            height: 1.1,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          t(
            'De complete boekhoudtool voor Nederlandse ZZP\'ers. Slim, snel en slechts €7,99/maand.',
            'The all-in-one accounting powerhouse for Dutch freelancers. Simple, smart, and only €7.99/month.',
          ),
          style: const TextStyle(
            fontSize: 17,
            color: BigDoggTheme.lightTextSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 36),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton(
              onPressed: () => context.go('/register'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BigDoggTheme.teal800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
                elevation: 3,
              ),
              child: Text(
                  t('Start gratis proefperiode →',
                      'Start free trial →')),
            ),
            TextButton(
              onPressed: () => context.go('/login'),
              child: Text(
                t('Al een account? Inloggen',
                    'Already have an account? Sign in'),
                style: const TextStyle(
                    color: BigDoggTheme.teal700,
                    fontWeight: FontWeight.w500,
                    fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _trustBadge(Icons.lock_outline,
                t('Geen creditcard', 'No credit card')),
            const SizedBox(width: 16),
            _trustBadge(Icons.cancel_outlined,
                t('Altijd opzegbaar', 'Cancel anytime')),
            const SizedBox(width: 16),
            _trustBadge(Icons.flag_outlined, 'Made in NL 🇳🇱'),
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
          // Mock invoice
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
                        color:
                            BigDoggTheme.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                          t('Betaald', 'Paid'),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t('Totaal', 'Total'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: BigDoggTheme.teal800,
                            fontSize: 13)),
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
          // AI prompt preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BigDoggTheme.teal800.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: BigDoggTheme.teal800.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome,
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
            t('AI maakte dit in 3 seconden.',
                'AI created this in 3 seconds.'),
            style: const TextStyle(
                fontSize: 11,
                color: BigDoggTheme.lightTextHint),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: BigDoggTheme.lightTextSecondary)),
          Text(amount,
              style: const TextStyle(
                  fontSize: 11,
                  color: BigDoggTheme.lightTextSecondary)),
        ],
      ),
    );
  }

  Widget _buildSocialProof(bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 64 : 20, vertical: 28),
      color: BigDoggTheme.teal800,
      child: Column(
        children: [
          Text(
            t('Vertrouwd door ZZP\'ers in heel Nederland',
                'Trusted by freelancers across the Netherlands'),
            style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: isWide ? 48 : 24,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              _statItem('€ 0', t('Verborgen kosten', 'Hidden fees')),
              _statItem('30',
                  t('Dagen gratis proberen', 'Days free trial')),
              _statItem('< 3s',
                  t('Factuur aanmaken', 'To create invoice')),
              _statItem('€7,99',
                  t('Per maand, alles in', 'Per month, all in')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: BigDoggTheme.gold400,
                fontSize: 28,
                fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(
                color: Colors.white60, fontSize: 12)),
      ],
    );
  }

  Widget _buildFeatures(bool isWide) {
    final features = [
      {
        'icon': Icons.upload_file_outlined,
        'title':
            t('Switch in 60 seconden', 'Switch in 60 seconds'),
        'desc': t(
          'Sleep je factuurhistorie van de afgelopen 10 jaar erin. BigDogg genereert direct historische jaarrapporten.',
          'Drag in your invoice history from the last 10 years. BigDogg instantly generates historical annual reports.',
        ),
        'highlight': true,
      },
      {
        'icon': Icons.auto_awesome,
        'title': t('Prompt-to-factuur', 'Prompt-to-invoice'),
        'desc': t(
          'Stop met typen, begin met factureren. Maak professionele facturen in seconden met eenvoudige tekst.',
          'Stop typing, start billing. Create professional, tax-compliant invoices in seconds using simple prompts.',
        ),
        'highlight': false,
      },
      {
        'icon': Icons.psychology_outlined,
        'title': t('Persoonlijke belastingstrateeg',
            'Personal tax strategist'),
        'desc': t(
          'Onze AI vindt aftrekposten. De meeste gebruikers besparen 3-4x hun abonnementskosten aan belastingoptimalisaties.',
          'Our AI finds deductions. Most users save 3-4x their subscription cost in tax optimizations alone.',
        ),
        'highlight': false,
      },
      {
        'icon': Icons.people_outline,
        'title': t('Klant-onboarding', 'Client self-onboarding'),
        'desc': t(
          'Stuur een link, laat je klanten hun gegevens invullen. Geen gedoe meer met IBAN- of KvK-nummers.',
          'Send a link, let your clients fill in their details. No more chasing IBANs or KvK numbers.',
        ),
        'highlight': false,
      },
      {
        'icon': Icons.bar_chart_outlined,
        'title': t('Premium analytics', 'Premium analytics'),
        'desc': t(
          'BTW-rapporten, jaaroverzichten, omzet per klant. Alles wat je accountant nodig heeft.',
          'VAT reports, annual overviews, revenue per client. Everything your accountant needs.',
        ),
        'highlight': false,
      },
      {
        'icon': Icons.language_outlined,
        'title': t('Volledig tweetalig', 'Fully bilingual'),
        'desc': t(
          'Schakel direct tussen Nederlands en Engels. Ideaal voor expats en internationale klanten.',
          'Toggle between Dutch and English instantly. Perfect for expats and international clients.',
        ),
        'highlight': false,
      },
    ];

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 64 : 20, vertical: 64),
      color: BigDoggTheme.lightSurface,
      child: Column(
        children: [
          Text(
            t('Alles wat je nodig hebt als ZZP\'er',
                'Everything you need as a freelancer'),
            style: TextStyle(
                fontSize: isWide ? 30 : 24,
                fontWeight: FontWeight.w800,
                color: BigDoggTheme.teal800,
                letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            t('Zonder overbodige complexiteit — gewoon wat werkt.',
                'Without unnecessary complexity — just what works.'),
            style: const TextStyle(
                fontSize: 15,
                color: BigDoggTheme.lightTextSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          isWide
              ? _featureGrid(features)
              : Column(
                  children: features
                      .map((f) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: 12),
                            child: _featureCard(f),
                          ))
                      .toList(),
                ),
        ],
      ),
    );
  }

  Widget _featureGrid(List features) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: features
              .take(3)
              .map((f) =>
                  Expanded(child: _featureCard(f as Map)))
              .toList(),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: features
              .skip(3)
              .map((f) =>
                  Expanded(child: _featureCard(f as Map)))
              .toList(),
        ),
      ],
    );
  }

  Widget _featureCard(Map f) {
    final isHighlight = f['highlight'] == true;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHighlight
            ? BigDoggTheme.teal800
            : BigDoggTheme.lightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isHighlight
                ? BigDoggTheme.teal800
                : BigDoggTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isHighlight
                  ? Colors.white.withOpacity(0.15)
                  : BigDoggTheme.teal800.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(f['icon'] as IconData,
                color: isHighlight
                    ? Colors.white
                    : BigDoggTheme.teal800,
                size: 22),
          ),
          const SizedBox(height: 14),
          Text(f['title'] as String,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: isHighlight
                      ? Colors.white
                      : BigDoggTheme.teal800)),
          const SizedBox(height: 6),
          Text(f['desc'] as String,
              style: TextStyle(
                  color: isHighlight
                      ? Colors.white70
                      : BigDoggTheme.lightTextSecondary,
                  fontSize: 13,
                  height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildComparison(bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 64 : 20, vertical: 64),
      child: Column(
        children: [
          Text(
            t('Waarom €7,99 en niet €29,99?',
                'Why €7.99 and not €29.99?'),
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
              'BigDogg biedt premium functies voor een eerlijke prijs.',
              'BigDogg delivers premium features at a fair price.',
            ),
            style: const TextStyle(
                fontSize: 15,
                color: BigDoggTheme.lightTextSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Container(
            constraints: const BoxConstraints(maxWidth: 700),
            decoration: BoxDecoration(
              color: BigDoggTheme.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BigDoggTheme.lightBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: BigDoggTheme.teal800,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 3,
                          child: Text(
                              t('Functie', 'Feature'),
                              style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                  fontWeight:
                                      FontWeight.w600))),
                      Expanded(
                          child: Text('Moneybird',
                              style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('Exact',
                              style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12),
                              textAlign: TextAlign.center)),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: BigDoggTheme.gold500,
                            borderRadius:
                                BorderRadius.circular(6),
                          ),
                          child: Text('BigDogg',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight:
                                      FontWeight.w700),
                              textAlign: TextAlign.center),
                        ),
                      ),
                    ],
                  ),
                ),
                // Rows
                ..._comparisonRows(isWide),
                // Price row
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: BigDoggTheme.gold500.withOpacity(0.06),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(15)),
                    border: Border(
                        top: BorderSide(
                            color: BigDoggTheme.lightBorder)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 3,
                          child: Text(
                              t('Prijs per maand',
                                  'Price per month'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: BigDoggTheme
                                      .teal800))),
                      Expanded(
                          child: Text('€29+',
                              style: const TextStyle(
                                  color:
                                      BigDoggTheme.error,
                                  fontWeight:
                                      FontWeight.w700),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('€39+',
                              style: const TextStyle(
                                  color:
                                      BigDoggTheme.error,
                                  fontWeight:
                                      FontWeight.w700),
                              textAlign: TextAlign.center)),
                      Expanded(
                        child: Text('€7,99',
                            style: const TextStyle(
                                color: BigDoggTheme.success,
                                fontWeight: FontWeight.w800,
                                fontSize: 16),
                            textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _comparisonRows(bool isWide) {
    final rows = [
      [t('AI factuur assistent', 'AI invoice assistant'), '✗', '✗', '✓'],
      [t('Historische import', 'Historical import'), '✗', '✗', '✓'],
      [t('BTW rapport PDF', 'VAT report PDF'), '✓', '✓', '✓'],
      [t('Klant onboarding', 'Client onboarding'), '✗', '✗', '✓'],
      [t('Tweetalig', 'Bilingual'), '✗', '✗', '✓'],
      [t('Belastingtips AI', 'AI tax tips'), '✗', '✗', '✓'],
    ];

    return rows.asMap().entries.map((entry) {
      final i = entry.key;
      final row = entry.value;
      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: i.isEven
              ? BigDoggTheme.lightBg.withOpacity(0.5)
              : BigDoggTheme.lightSurface,
          border: Border(
              top: BorderSide(color: BigDoggTheme.lightBorder)),
        ),
        child: Row(
          children: [
            Expanded(
                flex: 3,
                child: Text(row[0],
                    style: const TextStyle(
                        fontSize: 13,
                        color:
                            BigDoggTheme.lightTextPrimary))),
            Expanded(
                child: Text(row[1],
                    style: TextStyle(
                        color: row[1] == '✓'
                            ? BigDoggTheme.success
                            : BigDoggTheme.error,
                        fontWeight: FontWeight.w700,
                        fontSize: 16),
                    textAlign: TextAlign.center)),
            Expanded(
                child: Text(row[2],
                    style: TextStyle(
                        color: row[2] == '✓'
                            ? BigDoggTheme.success
                            : BigDoggTheme.error,
                        fontWeight: FontWeight.w700,
                        fontSize: 16),
                    textAlign: TextAlign.center)),
            Expanded(
                child: Text(row[3],
                    style: TextStyle(
                        color: row[3] == '✓'
                            ? BigDoggTheme.success
                            : BigDoggTheme.error,
                        fontWeight: FontWeight.w700,
                        fontSize: 16),
                    textAlign: TextAlign.center)),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildPricing(bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 64 : 20, vertical: 64),
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
            t('Geen verborgen kosten. Geen verrassingen.',
                'No hidden fees. No surprises.'),
            style: const TextStyle(
                fontSize: 15,
                color: BigDoggTheme.lightTextSecondary),
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('€7,99',
                        style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(t('/ maand', '/ month'),
                          style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 16)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: BigDoggTheme.gold500.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    t('30 dagen gratis · Geen creditcard vereist',
                        '30-day free trial · No credit card'),
                    style: const TextStyle(
                        color: BigDoggTheme.gold400,
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.white24),
                const SizedBox(height: 16),
                ...[
                  t('✓ Onbeperkt factureren',
                      '✓ Unlimited invoicing'),
                  t('✓ AI factuur assistent',
                      '✓ AI invoice assistant'),
                  t('✓ Historische import (10 jaar)',
                      '✓ Historical import (10 years)'),
                  t('✓ PDF generatie & e-mail',
                      '✓ PDF generation & email'),
                  t('✓ Klantenbeheer & onboarding',
                      '✓ Client management & onboarding'),
                  t('✓ Uitgaven & bonnen bijhouden',
                      '✓ Expense & receipt tracking'),
                  t('✓ Kwartaal BTW rapport',
                      '✓ Quarterly VAT report'),
                  t('✓ Jaarrapport met belastingtips',
                      '✓ Annual report with tax tips'),
                  t('✓ iDEAL betaling via Stripe',
                      '✓ iDEAL payment via Stripe'),
                ].map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(item,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14)),
                    )),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go('/register'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BigDoggTheme.gold500,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(10)),
                      textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                      elevation: 0,
                    ),
                    child: Text(t('Start gratis proefperiode →',
                        'Start free trial →')),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    t(
                        'Geen creditcard · Altijd opzegbaar · iDEAL via Stripe',
                        'No credit card · Cancel anytime · iDEAL via Stripe'),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalCta(bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 64 : 20, vertical: 64),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0FDFA), Color(0xFFFFFBEB)],
        ),
      ),
      child: Column(
        children: [
          Text(
            t(
              'Klaar om te stoppen met te veel betalen?',
              'Ready to stop overpaying?',
            ),
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
              'Sluit je aan bij honderden Nederlandse ZZP\'ers die al slimmer werken.',
              'Join hundreds of Dutch freelancers already working smarter.',
            ),
            style: const TextStyle(
                fontSize: 16,
                color: BigDoggTheme.lightTextSecondary,
                height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.go('/register'),
            style: ElevatedButton.styleFrom(
              backgroundColor: BigDoggTheme.teal800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 36, vertical: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700),
              elevation: 4,
            ),
            child: Text(t(
                'Start gratis — geen creditcard nodig',
                'Start free — no credit card needed')),
          ),
          const SizedBox(height: 16),
          Text(
            t('30 dagen gratis. Daarna €7,99/maand. Altijd opzegbaar.',
                '30 days free. Then €7.99/month. Cancel anytime.'),
            style: const TextStyle(
                color: BigDoggTheme.lightTextHint, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 64 : 20, vertical: 28),
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
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(t('Inloggen', 'Sign in'),
                      style:
                          const TextStyle(color: Colors.white60)),
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
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(t('Inloggen', 'Sign in'),
                          style: const TextStyle(
                              color: Colors.white60)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
}