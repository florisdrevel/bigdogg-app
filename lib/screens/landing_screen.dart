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
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildNav(bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 64 : 24, vertical: 16),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        border: Border(bottom: BorderSide(color: BigDoggTheme.lightBorder)),
      ),
      child: Row(
        children: [
          Image.asset('assets/images/logo.png', width: 44, height: 44),
          const SizedBox(width: 10),
          const Text('BigDogg',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: BigDoggTheme.teal800)),
          const Spacer(),
          // Language toggle
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
                style: const TextStyle(color: BigDoggTheme.gold600, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => context.go('/login'),
            child: Text(t('Inloggen', 'Sign in'),
                style: const TextStyle(color: BigDoggTheme.teal800, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => context.go('/register'),
            style: ElevatedButton.styleFrom(
              backgroundColor: BigDoggTheme.teal800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(t('Aanmelden', 'Sign up')),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 64 : 24, vertical: isWide ? 80 : 48),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 3, child: _buildHeroText()),
                const SizedBox(width: 48),
                Expanded(flex: 2, child: _buildHeroImage()),
              ],
            )
          : Column(
              children: [
                _buildHeroImage(),
                const SizedBox(height: 32),
                _buildHeroText(),
              ],
            ),
    );
  }

  Widget _buildHeroText() {
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
            t('14 dagen gratis proberen', '14-day free trial'),
            style: const TextStyle(color: BigDoggTheme.gold600, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          t('Factureren zonder\nhoofdpijn', 'Invoicing without\nthe headache'),
          style: const TextStyle(
            fontSize: 42,
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
            fontSize: 17,
            color: BigDoggTheme.lightTextSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            ElevatedButton(
              onPressed: () => context.go('/register'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BigDoggTheme.teal800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              child: Text(t('Start gratis proefperiode', 'Start free trial')),
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: () => context.go('/login'),
              child: Text(
                t('Al een account? Inloggen →', 'Already have an account? Sign in →'),
                style: const TextStyle(color: BigDoggTheme.teal700, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          t('Geen creditcard vereist · Opzegbaar per maand', 'No credit card required · Cancel anytime'),
          style: const TextStyle(color: BigDoggTheme.lightTextHint, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildHeroImage() {
    return Container(
      padding: const EdgeInsets.all(24),
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
          Image.asset('assets/images/logo.png', width: 160, height: 160),
          const SizedBox(height: 16),
          _miniInvoicePreview(),
        ],
      ),
    );
  }

  Widget _miniInvoicePreview() {
    return Container(
      padding: const EdgeInsets.all(16),
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
              const Text('2026-000001', style: TextStyle(fontWeight: FontWeight.w700, color: BigDoggTheme.teal800, fontSize: 13)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: BigDoggTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Betaald', style: TextStyle(color: BigDoggTheme.success, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('ToraTora B.V.', style: TextStyle(color: BigDoggTheme.lightTextSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          const Divider(),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Totaal incl BTW', style: TextStyle(fontWeight: FontWeight.w600, color: BigDoggTheme.teal800, fontSize: 13)),
              Text('€ 1.125,30', style: TextStyle(fontWeight: FontWeight.w700, color: BigDoggTheme.teal800, fontSize: 13)),
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
        'icon': Icons.people_outline,
        'title': t('Klantbeheer', 'Client Management'),
        'desc': t(
          'Nodig klanten uit via een link. Ze vullen zelf hun gegevens in.',
          'Invite clients via a link. They fill in their own details.',
        ),
      },
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 64 : 24, vertical: 64),
      color: BigDoggTheme.lightSurface,
      child: Column(
        children: [
          Text(
            t('Alles wat je nodig hebt als ZZP\'er', 'Everything you need as a freelancer'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: BigDoggTheme.teal800, letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            t('Zonder overbodige complexiteit', 'Without unnecessary complexity'),
            style: const TextStyle(fontSize: 16, color: BigDoggTheme.lightTextSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: features.map((f) => Expanded(child: _featureCard(f))).toList(),
                )
              : Column(
                  children: features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _featureCard(f),
                  )).toList(),
                ),
        ],
      ),
    );
  }

  Widget _featureCard(Map f) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(24),
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
          const SizedBox(height: 16),
          Text(f['title'] as String,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: BigDoggTheme.teal800)),
          const SizedBox(height: 8),
          Text(f['desc'] as String,
              style: const TextStyle(color: BigDoggTheme.lightTextSecondary, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildPricing(bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 64 : 24, vertical: 64),
      child: Column(
        children: [
          Text(
            t('Eén plan. Alles inbegrepen.', 'One plan. Everything included.'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: BigDoggTheme.teal800, letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            t('Geen verborgen kosten', 'No hidden fees'),
            style: const TextStyle(fontSize: 16, color: BigDoggTheme.lightTextSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(32),
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
                    const Text('€12', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(t('/ maand', '/ month'),
                          style: const TextStyle(color: Colors.white60, fontSize: 16)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  t('14 dagen gratis proberen', '14 days free trial'),
                  style: TextStyle(color: BigDoggTheme.gold400, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.white24),
                const SizedBox(height: 16),
                ...[ 
                  t('Onbeperkt facturen', 'Unlimited invoices'),
                  t('AI factuur assistent', 'AI invoice assistant'),
                  t('PDF generatie & e-mail', 'PDF generation & email'),
                  t('Klantenbeheer', 'Client management'),
                  t('Uitgaven bijhouden', 'Expense tracking'),
                  t('Kwartaal BTW overzicht', 'Quarterly VAT overview'),
                  t('Betalen via Stripe (iDEAL)', 'Pay via Stripe (iDEAL)'),
                ].map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.check, color: BigDoggTheme.gold400, size: 18),
                      const SizedBox(width: 10),
                      Text(item, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                )),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go('/register'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BigDoggTheme.gold500,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    child: Text(t('Start gratis proefperiode', 'Start free trial')),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    t('Geen creditcard vereist · Altijd opzegbaar', 'No credit card required · Cancel anytime'),
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

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      color: BigDoggTheme.teal800,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.asset('assets/images/logo.png', width: 32, height: 32),
              const SizedBox(width: 8),
              const Text('BigDogg', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
          Text(
            t('© 2026 BigDogg · Voor Nederlandse ZZP\'ers', '© 2026 BigDogg · For Dutch freelancers'),
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          TextButton(
            onPressed: () => context.go('/login'),
            child: Text(t('Inloggen', 'Sign in'), style: const TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }
}