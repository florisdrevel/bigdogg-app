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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BigDoggTheme.teal800)),
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
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => context.go('/login'),
            child: Text(t('Inloggen', 'Sign in'),
                style: const TextStyle(color: BigDoggTheme.teal800, fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => context.go('/register'),
            style: ElevatedButton.styleFrom(
              backgroundColor: BigDoggTheme.teal800,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 12, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(t('Gratis Starten', 'Start Free')),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 64 : 20,
        vertical: isWide ? 100 : 40,
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
                const SizedBox(height: 48),
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
            t('Slimmer boekhouden voor €7,99', 'Smarter accounting for €7.99'),
            style: const TextStyle(color: BigDoggTheme.gold600, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          t('Grip op je cijfers.\nBespaar op je belasting.', 'Master your finances.\nSave on your taxes.'),
          style: TextStyle(
            fontSize: isWide ? 52 : 36,
            fontWeight: FontWeight.w900,
            color: BigDoggTheme.teal800,
            height: 1.1,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          t(
            'Dé alles-in-één tool voor de Nederlandse ZZP\'er. Van prompt-naar-factuur tot historisch jaarrapport. Verdien je abonnement 4x terug met onze slimme belastingtips.',
            'The all-in-one tool for Dutch freelancers. From prompt-to-invoice to historical annual reports. Earn your subscription back 4x over with our smart tax tips.',
          ),
          style: const TextStyle(
            fontSize: 18,
            color: BigDoggTheme.lightTextSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            ElevatedButton(
              onPressed: () => context.go('/register'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BigDoggTheme.teal800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text(t('Start 30 dagen gratis', 'Start 30-day free trial'), 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            OutlinedButton(
              onPressed: () => context.go('/login'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                side: const BorderSide(color: BigDoggTheme.lightBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                t('Al een account? Log in', 'Already a member? Sign in'),
                style: const TextStyle(color: BigDoggTheme.teal700, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.verified_user_outlined, size: 16, color: BigDoggTheme.lightTextHint),
            const SizedBox(width: 8),
            Text(
              t('Geen creditcard vereist · Altijd opzegbaar', 'No credit card required · Cancel anytime'),
              style: const TextStyle(color: BigDoggTheme.lightTextHint, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroImage() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BigDoggTheme.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        children: [
          Image.asset('assets/images/logo.png', width: 100, height: 100),
          const SizedBox(height: 24),
          _miniInvoicePreview(),
          const SizedBox(height: 16),
          _miniReportPreview(),
        ],
      ),
    );
  }

  Widget _miniInvoicePreview() {
    return Container(
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
              const Text('PROMPT-TO-INVOICE',
                  style: TextStyle(fontWeight: FontWeight.w800, color: BigDoggTheme.teal800, fontSize: 10, letterSpacing: 0.5)),
              const Icon(Icons.auto_awesome, color: BigDoggTheme.gold500, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          const Text('"4 uur consultancy voor Janssen B.V."',
              style: TextStyle(color: BigDoggTheme.lightTextSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t('Factuur gegenereerd!', 'Invoice ready!'),
                  style: const TextStyle(color: BigDoggTheme.success, fontSize: 11, fontWeight: FontWeight.bold)),
              const Text('€ 360,00',
                  style: TextStyle(fontWeight: FontWeight.bold, color: BigDoggTheme.teal800, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniReportPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BigDoggTheme.teal800,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights, color: BigDoggTheme.gold400, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('Belastingtip ontdekt!', 'Tax tip discovered!'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                Text(t('Bespaar €450 op je kwartaalaangifte', 'Save €450 on your quarterly return'),
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatures(bool isWide) {
    final features = [
      {
        'icon': Icons.bolt,
        'title': t('Prompt-naar-Factuur', 'Prompt-to-Invoice'),
        'desc': t(
          'Beschrijf je werk in één zin. BigDogg maakt automatisch een professionele factuur.',
          'Describe your work in one sentence. BigDogg creates a professional invoice automatically.',
        ),
      },
      {
        'icon': Icons.history,
        'title': t('10 Jaar Historie', '10 Years of History'),
        'desc': t(
          'Upload oude facturen van andere platforms en krijg direct een compleet historisch jaarrapport.',
          'Upload old invoices from other platforms and get a complete historical annual report instantly.',
        ),
      },
      {
        'icon': Icons.savings_outlined,
        'title': t('ROI-Gedreven Tax Tips', 'ROI-Driven Tax Tips'),
        'desc': t(
          'Verdien je abonnement 4x terug met gepersonaliseerde belastingbesparingen voor ZZP\'ers.',
          'Earn your subscription back 4x over with personalized tax savings for Dutch freelancers.',
        ),
      },
      {
        'icon': Icons.language,
        'title': t('NL / EN Support', 'NL / EN Support'),
        'desc': t(
          'Schakel direct tussen talen. Zowel voor je administratie als voor je klant-rapportages.',
          'Switch languages instantly. For your admin and for your client reporting.',
        ),
      },
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 64 : 20, vertical: 80),
      color: BigDoggTheme.lightSurface,
      child: Column(
        children: [
          _buildTrustBar(isWide),
          const SizedBox(height: 80),
          Text(
            t('Waarom freelancers overstappen', 'Why freelancers are switching'),
            style: TextStyle(
                fontSize: isWide ? 36 : 28,
                fontWeight: FontWeight.w900,
                color: BigDoggTheme.teal800,
                letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            t('Geen gedoe, alleen wat je nodig hebt om te groeien.', 'No fuss, only what you need to grow.'),
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

  Widget _buildTrustBar(bool isWide) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: isWide ? 64 : 32,
      runSpacing: 24,
      children: [
        _trustItem(Icons.security, t('Belastingdienst Proof', 'Tax Office Compliant')),
        _trustItem(Icons.account_balance, t('iDEAL Integratie', 'iDEAL Integrated')),
        _trustItem(Icons.devices, t('Desktop & Mobiel', 'Desktop & Mobile')),
      ],
    );
  }

  Widget _trustItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: BigDoggTheme.teal800.withOpacity(0.5)),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: BigDoggTheme.teal800.withOpacity(0.6), fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _featureCard(Map f) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BigDoggTheme.lightBorder.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BigDoggTheme.gold500.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(f['icon'] as IconData, color: BigDoggTheme.gold600, size: 26),
          ),
          const SizedBox(height: 20),
          Text(f['title'] as String,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: BigDoggTheme.teal800)),
          const SizedBox(height: 12),
          Text(f['desc'] as String,
              style: const TextStyle(color: BigDoggTheme.lightTextSecondary, fontSize: 14, height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildPricing(bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 64 : 20, vertical: 100),
      child: Column(
        children: [
          Text(
            t('Eerlijke prijs voor elke ZZP\'er', 'Fair pricing for every freelancer'),
            style: TextStyle(
                fontSize: isWide ? 36 : 28,
                fontWeight: FontWeight.w900,
                color: BigDoggTheme.teal800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: BigDoggTheme.teal800,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: BigDoggTheme.teal800.withOpacity(0.3),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text('PLATINUM', style: TextStyle(color: BigDoggTheme.gold400, fontWeight: FontWeight.w800, letterSpacing: 2)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('€7,99',
                        style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(t('/ maand', '/ month'),
                          style: const TextStyle(color: Colors.white60, fontSize: 18)),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Divider(color: Colors.white12),
                const SizedBox(height: 24),
                ...[
                  t('Onbeperkt factureren & klanten', 'Unlimited invoicing & clients'),
                  t('AI "Prompt-to-Invoice" Assistent', 'AI "Prompt-to-Invoice" Assistant'),
                  t('10 jaar historie importeren', 'Import 10 years of history'),
                  t('BTW & Jaarrapportage (NL/EN)', 'VAT & Annual Reports (NL/EN)'),
                  t('Gepersonaliseerde Belastingtips', 'Personalized Tax-Saving Tips'),
                  t('Client Self-Onboarding Portal', 'Client Self-Onboarding Portal'),
                ].map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: BigDoggTheme.gold500, size: 20),
                          const SizedBox(width: 12),
                          Expanded(child: Text(item, style: const TextStyle(color: Colors.white, fontSize: 15))),
                        ],
                      ),
                    )),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go('/register'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BigDoggTheme.gold500,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(t('Start Nu Gratis Trial', 'Start Free Trial Now'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
      padding: EdgeInsets.symmetric(horizontal: isWide ? 64 : 20, vertical: 60),
      color: BigDoggTheme.teal900,
      child: Column(
        children: [
          if (isWide)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _footerLogo(),
                _footerLinks(),
              ],
            )
          else
            Column(
              children: [
                _footerLogo(),
                const SizedBox(height: 32),
                _footerLinks(),
              ],
            ),
          const Divider(height: 60, color: Colors.white10),
          Text(
            t('© 2026 BigDogg.nl · Gebouwd voor de ondernemers van de toekomst.',
                '© 2026 BigDogg.nl · Built for the entrepreneurs of the future.'),
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _footerLogo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/images/logo.png', width: 32, height: 32),
        const SizedBox(width: 12),
        const Text('BigDogg',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
      ],
    );
  }

  Widget _footerLinks() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(onPressed: () {}, child: Text(t('Voorwaarden', 'Terms'), style: const TextStyle(color: Colors.white60))),
        const SizedBox(width: 16),
        TextButton(onPressed: () {}, child: Text(t('Privacy', 'Privacy'), style: const TextStyle(color: Colors.white60))),
        const SizedBox(width: 16),
        TextButton(onPressed: () {}, child: Text(t('Contact', 'Support'), style: const TextStyle(color: Colors.white60))),
      ],
    );
  }
}
