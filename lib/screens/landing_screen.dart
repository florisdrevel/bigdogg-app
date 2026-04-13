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

  void _showTerms(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 600),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: BigDoggTheme.teal800,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
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
Het abonnement bedraagt €9,99 per maand. Na een gratis proefperiode van 30 dagen wordt er overgegaan op een betaald abonnement, tenzij je vóór het einde van de proefperiode opzegt. Opzegging kan op elk moment via de instellingen in de app. Je behoudt toegang tot het einde van de lopende betaalperiode.

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
The subscription fee is €9.99 per month. After a 30-day free trial, a paid subscription begins unless cancelled before the end of the trial period. You may cancel at any time via the settings in the app. You retain access until the end of the current billing period.

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
            'De complete boekhoudtool voor Nederlandse ZZP\'ers. Slim, snel en slechts €9,99/maand.',
            'The all-in-one accounting powerhouse for Dutch freelancers. Simple, smart, and only €9.99/month.',
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
              child: Text(t('Start gratis proefperiode →',
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
          // Large logo
          Image.asset('assets/images/logo.png',
              width: 120, height: 120),
          const SizedBox(height: 20),
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
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
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
                        color: BigDoggTheme.success
                            .withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(6),
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
                    t('Coaching — 5 dagen',
                        'Coaching — 5 days'),
                    '€ 3.025,00'),
                _invoiceLineItem('21% BTW', '€ 635,25'),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
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
          // AI prompt preview with robot icon
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
            t('AI maakt je factuur in een oogwenk.',
                'AI creates your invoice near-instantly.'),
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
              _statItem('€ 0',
                  t('Verborgen kosten', 'Hidden fees')),
              _statItem('30',
                  t('Dagen gratis proberen', 'Days free trial')),
              _statItem('~instant',
                  t('Factuur aanmaken', 'To create invoice')),
              _statItem('€9,99',
                  t('Per maand, alles inbegrepen', 'Per month, all in')),
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
          'Sleep je volledige factuurhistorie erin. BigDogg genereert direct historische jaarrapporten en organiseert je verleden.',
          'Drag in your complete invoice history. BigDogg instantly generates historical annual reports and organises your past.',
        ),
        'highlight': true,
      },
      {
        'icon': Icons.smart_toy_outlined,
        'title': t('Prompt-to-factuur', 'Prompt-to-invoice'),
        'desc': t(
          'Stop met typen, begin met factureren. Maak professionele, BTW-conforme facturen in een oogwenk met eenvoudige tekst.',
          'Stop typing, start billing. Create professional, tax-compliant invoices near-instantly using simple prompts.',
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
        'title':
            t('Klant-onboarding', 'Client self-onboarding'),
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
            t('Waarom €9,99 en niet €29,99?',
                'Why €9.99 and not €29.99?'),
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
              border:
                  Border.all(color: BigDoggTheme.lightBorder),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: const BoxDecoration(
                    color: BigDoggTheme.teal800,
                    borderRadius: BorderRadius.vertical(
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
                          child: const Text('BigDogg',
                              style: TextStyle(
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
                ..._comparisonRows(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color:
                        BigDoggTheme.gold500.withOpacity(0.06),
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
                                  color:
                                      BigDoggTheme.teal800))),
                      Expanded(
                          child: const Text('€29+',
                              style: TextStyle(
                                  color: BigDoggTheme.error,
                                  fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: const Text('€39+',
                              style: TextStyle(
                                  color: BigDoggTheme.error,
                                  fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center)),
                      Expanded(
                        child: const Text('€9,99',
                            style: TextStyle(
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

  List<Widget> _comparisonRows() {
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
                        color: BigDoggTheme.lightTextPrimary))),
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
                    const Text('€9,99',
                        style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    const SizedBox(width: 8),
                    Padding(
                      padding:
                          const EdgeInsets.only(bottom: 10),
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
                    color:
                        BigDoggTheme.gold500.withOpacity(0.2),
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
                  t('✓ Historische factuurimport',
                      '✓ Historical invoice import'),
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
                    child: Text(t(
                        'Start gratis proefperiode →',
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
              'Sluit je aan bij Nederlandse ZZP\'ers die al slimmer werken.',
              'Join Dutch freelancers already working smarter.',
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
            t(
                '30 dagen gratis. Daarna €9,99/maand. Altijd opzegbaar.',
                '30 days free. Then €9.99/month. Cancel anytime.'),
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
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _showTerms(context),
                      child: Text(
                          t('Algemene Voorwaarden',
                              'Terms & Conditions'),
                          style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(t('Inloggen', 'Sign in'),
                          style: const TextStyle(
                              color: Colors.white60)),
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
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(t('Inloggen', 'Sign in'),
                          style: const TextStyle(
                              color: Colors.white60)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _showTerms(context),
                  child: Text(
                      t('Algemene Voorwaarden',
                          'Terms & Conditions'),
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
}
