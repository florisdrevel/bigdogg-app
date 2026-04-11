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
            _buildFeatures(isWide),
            _buildPricing(isWide),
            _buildFooter(isWide),
          ],
        ),
      ),
    );
  }

  Widget _buildNav(bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 64 : 16, vertical: 12),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        border: Border(bottom: BorderSide(color: BigDoggTheme.lightBorder)),
      ),
      child: Row(
        children: [
          Image.asset('assets/images/logo.png', width: 36, height: 36),
          const SizedBox(width: 8),
          const Text('BigDogg',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: BigDoggTheme.teal800)),
          const Spacer(),
          GestureDetector(
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
                style: const TextStyle(color: BigDoggTheme.gold600, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => context.go('/login'),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: Text(t('Inloggen', 'Sign in'),
                style: const TextStyle(color: BigDoggTheme.teal800, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: () => context.go('/register'),
            style: ElevatedButton.styleFrom(
              backgroundColor: BigDoggTheme.teal800,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: isWide ? 20 : 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 13),
            ),
            child: Text(t('Aanmelden', 'Sign up')),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 64 : 20,
        vertical: isWide ? 80 : 40,
      ),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 3, child: _buildHeroText(isWide)),
                const SizedBox(width: 48),
                Expanded(flex: 2, child: _buildHeroImage()),
              ],
            )
          : Column(
              children: [
                _buildHeroText(isWide),
                const SizedBox(height: 32),
                _buildHeroImage(),
              ],
            ),
    );
  }

  Widget _buildHeroText(bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: BigDoggTheme.gold500.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BigDoggTheme.gold500.withOpacity(0.4)),
          ),
          child: Text(
            t('30 dagen gratis proberen', '30-day free trial'),
            style: const TextStyle(color: BigDoggTheme.gold600, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          t('Factureren zonder\nhoofdpijn', 'Invoicing without\nthe headache'),
          style: TextStyle(
            fontSize: isWide ? 42 : 32,
            fontWeight: FontWeight.w800,
            color: BigDoggTheme.teal800,
            height: 1.15,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          t(
            'BigDogg is de slimste facturatietool voor Nederlandse ZZP\'ers. Maak facturen in seconden met AI, beheer klanten en houd je BTW bij — alles op één plek.',
            'BigDogg is the smartest invoicing tool for Dutch freelancers. Create invoices in seconds with AI, manage clients and track VAT — all in one place.',
          ),
          style: const TextStyle(
            fontSize: 16,
            color: BigDoggTheme.lightTextSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton(
              onPressed: () => context.go('/register'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BigDoggTheme.teal800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              child: Text(t('Start gratis proefperiode', 'Start free trial')),
            ),
            TextButton(
              onPressed: () => context.go('/login'),
              child: Text(
                t('Al een account? Inloggen →', 'Already have an account? Sign in →'),
                style: const TextStyle(color: BigDoggTheme.teal700, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          t('Geen creditcard vereist · Opzegbaar per maand', 'No credit card required · Cancel anytime'),
          style: const TextStyle(color: BigDoggTheme.lightTextHint, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildHeroImage() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BigDoggTheme.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Image.asset('assets/images/logo.png', width: 120, height: 120),
          const SizedBox(height: 16),
          _miniInvoicePreview(),
        ],
      ),
    );
  }

  Widget _miniInvoicePreview() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('2026-000001',
                  style: TextStyle(fontWeight: FontWeight.w700, color: BigDoggTheme.teal800, fontSize: 12)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: BigDoggTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(t('Betaald', 'Paid'),
                    style: const TextStyle(color: BigDoggTheme.success, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('ToraTora B.V.',
              style: TextStyle(color: BigDoggTheme.lightTextSecondary, fontSize: 11)),
          const SizedBox(height: 6),
          const Divider(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t('Totaal incl BTW', 'Total incl VAT'),
                  style: const TextStyle(fontWeight: FontWeight.w600, color: BigDoggTheme.teal800, fontSize: 12)),
              const Text('€ 1.125,30',
                  style: TextStyle(fontWeight: FontWeight.w700, color: BigDoggTheme.teal800, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatures(bool isWide) {
    final features = [
      {
        'icon': Icons.auto_awesome,
        'title': t('AI Facturatie', 'AI Invoicing'),
        'desc': t(
          'Beschrijf je werk in gewone taal. BigDogg maakt automatisch een professionele factuur.',
          'Describe your work in plain language. BigDogg automatically creates a professional invoice.',
        ),
      },
      {
        'icon': Icons.picture_as_pdf_outlined,
        'title': t('PDF & E-mail', 'PDF & Email'),
        'desc': t(
          'Genereer een professionele PDF en verstuur deze direct naar je klant per e-mail.',
          'Generate a professional PDF and send it directly to your client by email.',
        ),
      },
      {
        'icon': Icons.bar_chart_outlined,
        'title': t('BTW Overzicht', 'VAT Overview'),
        'desc': t(
          'Altijd inzicht in je kwartaal BTW. Geen verrassingen bij de Belastingdienst.',
          'Always insight into your quarterly VAT. No surprises at the tax authority.',
        ),
      },
      {
        'icon': Icons.receipt_long_outlined,
        'title': t('Jaarrapport & Belasting', 'Annual Report & Tax'),
        'desc': t(
          'Uitgebreid jaarrapport met analytics en persoonlijke belastingtips speciaal voor Nederlandse ZZP\'ers.',
          'Comprehensive annual report with analytics and personalised tax tips for Dutch freelancers.',
        ),
      },
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 64 : 20, vertical: 56),
      color: BigDoggTheme.lightSurface,
      child: Column(
        children: [
          Text(
            t('Alles wat je nodig hebt als ZZP\'er', 'Everything you need as a freelancer'),
            style: TextStyle(
                fontSize: isWide ? 28 : 22,
                fontWeight: FontWeight.w700,
                color: BigDoggTheme.teal800,
                letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            t('Zonder overbodige complexiteit', 'Without unnecessary complexity'),
            style: const TextStyle(fontSize: 15, color: BigDoggTheme.lightTextSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: features.map((f) => Expanded(child: _featureCard(f))).toList(),
                )
              : Column(
                  children: features
                      .map((f) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _featureCard(f),
                          ))
                      .toList(),
                ),
        ],
      ),
    );
  }

  Widget _featureCard(Map f) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: BigDoggTheme.teal800.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(f['icon'] as IconData, color: BigDoggTheme.teal800, size: 22),
          ),
          const SizedBox(height: 14),
          Text(f['title'] as String,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: BigDoggTheme.teal800)),
          const SizedBox(height: 6),
          Text(f['desc'] as String,
              style: const TextStyle(color: BigDoggTheme.lightTextSecondary, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildPricing(bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 64 : 20, vertical: 56),
      child: Column(
        children: [
          Text(
            t('Eén plan. Alles inbegrepen.', 'One plan. Everything included.'),
            style: TextStyle(
                fontSize: isWide ? 28 : 22,
                fontWeight: FontWeight.w700,
                color: BigDoggTheme.teal800,
                letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            t('Geen verborgen kosten', 'No hidden fees'),
            style: const TextStyle(fontSize: 15, color: BigDoggTheme.lightTextSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: BigDoggTheme.teal800,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: BigDoggTheme.teal800.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
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
                        style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(t('/ maand', '/ month'),
                          style: const TextStyle(color: Colors.white60, fontSize: 15)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  t('30 dagen gratis proberen · Geen creditcard vereist',
                      '30-day free trial · No credit card required'),
                  style: TextStyle(color: BigDoggTheme.gold400, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white24),
                const SizedBox(height: 14),
                ...[
                  t('Onbeperkt factureren', 'Unlimited invoicing'),
                  t('AI factuur assistent', 'AI invoice assistant'),
                  t('PDF generatie & e-mail', 'PDF generation & email'),
                  t('Klantenbeheer', 'Client management'),
                  t('Uitgaven bijhouden', 'Expense tracking'),
                  t('Kwartaal BTW overzicht', 'Quarterly VAT overview'),
                  t('Jaarrapport met belastingtips', 'Annual report with tax tips'),
                  t('Betalen via Stripe (iDEAL)', 'Pay via Stripe (iDEAL)'),
                ].map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(
                        children: [
                          const Icon(Icons.check, color: BigDoggTheme.gold400, size: 16),
                          const SizedBox(width: 10),
                          Expanded(child: Text(item, style: const TextStyle(color: Colors.white, fontSize: 13))),
                        ],
                      ),
                    )),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go('/register'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BigDoggTheme.gold500,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    child: Text(t('Start gratis proefperiode', 'Start free trial')),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    t('Geen creditcard vereist · Altijd opzegbaar',
                        'No credit card required · Cancel anytime'),
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
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

  Widget _buildFooter(bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 64 : 20, vertical: 28),
      color: BigDoggTheme.teal800,
      child: isWide
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Image.asset('assets/images/logo.png', width: 28, height: 28),
                    const SizedBox(width: 8),
                    const Text('BigDogg',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
                Text(
                  t('© 2026 BigDogg · Voor Nederlandse ZZP\'ers',
                      '© 2026 BigDogg · For Dutch freelancers'),
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(t('Inloggen', 'Sign in'),
                      style: const TextStyle(color: Colors.white60)),
                ),
              ],
            )
          : Column(
              children: [
                Row(
                  children: [
                    Image.asset('assets/images/logo.png', width: 28, height: 28),
                    const SizedBox(width: 8),
                    const Text('BigDogg',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(t('Inloggen', 'Sign in'),
                          style: const TextStyle(color: Colors.white60)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  t('© 2026 BigDogg · Voor Nederlandse ZZP\'ers',
                      '© 2026 BigDogg · For Dutch freelancers'),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }
}