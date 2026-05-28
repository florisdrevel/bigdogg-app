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

  // Anchor for the "Bekijk de functies" / "See the features" CTA
  final GlobalKey _featuresKey = GlobalKey();

  String t(String nl, String en) => _isNl ? nl : en;

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
            _buildStatBar(isWide),
            _buildProblemSolution(isWide),
            _buildFeatures(isWide),
            _buildComparison(isWide),
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

  // ─── Nav ────────────────────────────────────────────────────
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
          Image.asset('assets/images/logo.png',
              width: isWide ? 96 : 80, height: isWide ? 96 : 80),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _isNl = !_isNl),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
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
            child: Text(t('Probeer gratis', 'Try free')),
          ),
        ],
      ),
    );
  }

  // ─── Hero ───────────────────────────────────────────────────
  Widget _buildHero(bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 64 : 20,
        vertical: isWide ? 96 : 56,
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
            'Boekhouden hoeft geen hoofdpijn te zijn.',
            'Accounting shouldn\'t give you a headache.',
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
                ? 'Maak facturen, doe je BTW en houd uitgaven bij — zonder accountant en voor €9,99 per maand.'
                : 'Maak facturen, doe je BTW en houd uitgaven bij — zonder accountant.',
            kIsWeb
                ? 'Make invoices, file your VAT and track expenses — without an accountant, for €9.99 a month.'
                : 'Make invoices, file your VAT and track expenses — without an accountant.',
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
                child: Text(t('Probeer 30 dagen gratis',
                    'Try free for 30 days')),
              ),
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
                child: Text(t('Bekijk de functies', 'See the features')),
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () => context.go('/register'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BigDoggTheme.teal800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                  elevation: 3,
                ),
                child: Text(t('Probeer 30 dagen gratis',
                    'Try free for 30 days')),
              ),
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
                child: Text(t('Bekijk de functies', 'See the features')),
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
          Image.asset('assets/images/logo.png', width: 120, height: 120),
          const SizedBox(height: 20),
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
                  fontSize: 11,
                  color: BigDoggTheme.lightTextSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Text(amount,
              style: const TextStyle(
                  fontSize: 11,
                  color: BigDoggTheme.lightTextSecondary)),
        ],
      ),
    );
  }

  // ─── Honest stat bar ──────────────────────────────────────
  Widget _buildStatBar(bool isWide) {
    final items = [
      t('Net gelanceerd', 'Just launched'),
      if (kIsWeb) '€9,99 / ${t('maand', 'month')}',
      t('30 dagen gratis', '30 days free'),
      t('Gemaakt in Nederland', 'Built in the Netherlands'),
    ];
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 64 : 20, vertical: 22),
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
                color: items[i].startsWith('€')
                    ? BigDoggTheme.gold400
                    : Colors.white70,
                fontSize: isWide ? 14 : 12.5,
                fontWeight: items[i].startsWith('€')
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
            if (i < items.length - 1)
              Text(
                '·',
                style: TextStyle(
                    color: Colors.white30,
                    fontSize: isWide ? 14 : 12.5),
              ),
          ],
        ],
      ),
    );
  }

  // ─── Problem / solution ───────────────────────────────────
  Widget _buildProblemSolution(bool isWide) {
    final items = [
      if (kIsWeb)
        {
          'pain': t(
            'Je betaalt €17 of meer per maand voor functies die je nooit gebruikt.',
            'You pay €17 or more a month for features you never use.',
          ),
          'fix': t(
            'BigDogg kost €9,99 per maand. Alles zit erin. Geen extra pakketten.',
            'BigDogg is €9.99 a month. Everything is included. No add-ons.',
          ),
        },
      {
        'pain': t(
          'Elk kwartaal zit je weer met je BTW-aangifte in je maag.',
          'Every quarter your VAT return hangs over your head.',
        ),
        'fix': t(
          'BigDogg maakt je BTW-rapport met één klik. Klaar voor de Belastingdienst.',
          'BigDogg builds your VAT report in one click. Ready for the tax office.',
        ),
      },
      {
        'pain': t(
          'Je blijft achter je geld aanrennen omdat klanten te laat betalen.',
          'You spend half your time chasing clients who pay late.',
        ),
        'fix': t(
          'Zet een iDEAL-betaallink direct op de factuur. Klanten betalen met één tik.',
          'Drop an iDEAL payment link straight on the invoice. Clients pay with one tap.',
        ),
      },
    ];

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 64 : 20, vertical: 64),
      child: Column(
        children: [
          Text(
            t('Drie irritaties die we hebben opgelost',
                'Three frustrations we fixed'),
            style: TextStyle(
                fontSize: isWide ? 30 : 24,
                fontWeight: FontWeight.w800,
                color: BigDoggTheme.teal800,
                letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            t('Boekhouden voor ZZP\'ers, dan eindelijk simpel.',
                'Accounting for freelancers, finally simple.'),
            style: const TextStyle(
                fontSize: 15,
                color: BigDoggTheme.lightTextSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: items
                      .map((p) => Expanded(child: _problemCard(p)))
                      .toList(),
                )
              : Column(
                  children: items
                      .map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _problemCard(p),
                          ))
                      .toList(),
                ),
        ],
      ),
    );
  }

  Widget _problemCard(Map p) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: BigDoggTheme.error.withOpacity(0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              t('Probleem', 'Problem'),
              style: const TextStyle(
                  color: BigDoggTheme.error,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            p['pain'] as String,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: BigDoggTheme.teal800,
                height: 1.4),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: BigDoggTheme.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              t('Met BigDogg', 'With BigDogg'),
              style: const TextStyle(
                  color: BigDoggTheme.success,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            p['fix'] as String,
            style: const TextStyle(
                color: BigDoggTheme.lightTextSecondary,
                fontSize: 14,
                height: 1.55),
          ),
        ],
      ),
    );
  }

  // ─── Features ─────────────────────────────────────────────
  Widget _buildFeatures(bool isWide) {
    final features = [
      {
        'icon': Icons.smart_toy_outlined,
        'title': t('AI facturering', 'AI invoicing'),
        'desc': t(
          'Typ kort wat je hebt gedaan en BigDogg maakt de factuur. Met de juiste BTW, klantgegevens en je eigen logo.',
          'Type a short note about what you\'ve done and BigDogg writes the invoice — with the right VAT, client details and your own logo.',
        ),
      },
      {
        'icon': Icons.task_alt_outlined,
        'title': t('BTW aangifte', 'VAT reports'),
        'desc': t(
          'Elk kwartaal een PDF met alles wat de Belastingdienst nodig heeft. Aanklikken en versturen.',
          'A quarterly PDF with everything the tax office needs. One click and you\'re done.',
        ),
      },
      {
        'icon': Icons.description_outlined,
        'title': t('Jaarrapport', 'Annual report'),
        'desc': t(
          'Een compleet jaarrapport met tips voor aftrekposten — werk dat een accountant je honderden euro\'s per jaar kost. Je abonnement is meteen terugverdiend.',
          'A complete annual report with deduction tips — work an accountant would charge you hundreds for. Your subscription pays for itself many times over.',
        ),
      },
      {
        'icon': Icons.payments_outlined,
        'title': t('Stripe betaallinks', 'Stripe payment links'),
        'desc': t(
          'Zet een iDEAL- of creditcardbetaallink direct op de factuur. Betalingen worden automatisch geboekt.',
          'Add an iDEAL or card payment link straight on the invoice. Payments get logged automatically.',
        ),
      },
      {
        'icon': Icons.camera_alt_outlined,
        'title': t('Bonnen scannen', 'Scan receipts'),
        'desc': t(
          'Maak een foto van je bonnetje. BigDogg ziet het bedrag, de BTW en de categorie. Niets meer overtypen.',
          'Snap a photo of your receipt. BigDogg picks up the amount, VAT and category — no retyping.',
        ),
      },
      {
        'icon': Icons.schedule_outlined,
        'title': t('Urenregistratie', 'Hours tracker'),
        'desc': t(
          'Houd je uren bij voor de zelfstandigenaftrek. BigDogg laat zien hoe ver je bent met de 1.225-uurdrempel.',
          'Log your hours for the self-employed deduction. BigDogg shows how close you are to the 1,225-hour threshold.',
        ),
      },
    ];

    return Container(
      key: _featuresKey,
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 64 : 20, vertical: 64),
      color: BigDoggTheme.lightSurface,
      child: Column(
        children: [
          Text(
            t('Wat zit erin?', 'What\'s included?'),
            style: TextStyle(
                fontSize: isWide ? 30 : 24,
                fontWeight: FontWeight.w800,
                color: BigDoggTheme.teal800,
                letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            t('Geen poespas. Gewoon wat werkt.',
                'No fluff. Just what works.'),
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
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _featureCard(f),
                          ))
                      .toList(),
                ),
          const SizedBox(height: 24),
          _afschrijvingenHighlight(isWide),
        ],
      ),
    );
  }

  Widget _afschrijvingenHighlight(bool isWide) {
    final title = t('Investeringen & afschrijvingen',
        'Investments & depreciation');
    final body = t(
      'Veel ZZP\'ers slaan afschrijvingen over — te ingewikkeld. BigDogg doet het automatisch zodra je een investering invoert. Honderden euro\'s belastingvoordeel die anders blijven liggen.',
      'Many freelancers skip depreciation — too complicated. BigDogg does it automatically the moment you log an investment. Hundreds in tax savings that would otherwise be left on the table.',
    );

    return Container(
      padding: EdgeInsets.all(isWide ? 32 : 22),
      decoration: BoxDecoration(
        color: BigDoggTheme.teal800,
        borderRadius: BorderRadius.circular(16),
      ),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: BigDoggTheme.gold500,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.trending_up_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        body,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.55),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BigDoggTheme.gold500,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.trending_up_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.55),
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
              .map((f) => Expanded(child: _featureCard(f as Map)))
              .toList(),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: features
              .skip(3)
              .map((f) => Expanded(child: _featureCard(f as Map)))
              .toList(),
        ),
      ],
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
            child: Icon(f['icon'] as IconData,
                color: BigDoggTheme.teal800, size: 22),
          ),
          const SizedBox(height: 14),
          Text(f['title'] as String,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: BigDoggTheme.teal800)),
          const SizedBox(height: 6),
          Text(f['desc'] as String,
              style: const TextStyle(
                  color: BigDoggTheme.lightTextSecondary,
                  fontSize: 13,
                  height: 1.5)),
        ],
      ),
    );
  }

  // ─── Comparison + alleen-bij-BigDogg cards ──────────────
  Widget _buildComparison(bool isWide) {
    const double tableWidth = 760;
    const double labelWidth = 240;
    const double brandWidth = 104;

    // Each row: [label, BigDogg, Moneybird, Exact, Tellow, Bunni]
    final rows = <List<String>>[
      if (kIsWeb)
        [
          t('Prijs / maand', 'Price / month'),
          '€9,99', '€14+', '€49+', '€8–15', '€9,95',
        ],
      [
        t('Gratis proberen', 'Free trial'),
        t('30 dagen', '30 days'),
        t('60 dagen*', '60 days*'),
        t('30 dagen', '30 days'),
        t('Beperkt', 'Limited'),
        t('30 dagen', '30 days'),
      ],
      [
        t('AI facturen genereren', 'AI invoice generation'),
        '✅', '❌', '❌', '❌', '❌',
      ],
      [
        t('AI jaarrapport + belastingtips',
            'AI annual report + tax tips'),
        '✅', '❌', '❌', '❌', '❌',
      ],
      [
        t('Betaallink op factuur', 'Payment link on invoice'),
        '✅', '❌', '❌', '❌', '❌',
      ],
      [
        t('QR-code betaling', 'QR-code payment'),
        '✅', '❌', '❌', '❌', '❌',
      ],
      [
        t('Urencriterium tracker', 'Hours-criterion tracker'),
        '✅',
        t('Basis', 'Basic'),
        '❌', '❌', '✅',
      ],
      [
        t('Historische import via AI', 'Historical AI import'),
        '✅', '❌', '❌', '❌', '❌',
      ],
      [
        t('Klant self-onboarding', 'Client self-onboarding'),
        '✅', '❌', '❌', '❌', '❌',
      ],
      [
        t('Geschikt voor gewone ZZP\'er',
            'Right for everyday freelancers'),
        '✅', '⚠️', '❌', '✅', '✅',
      ],
      [
        t('Klantenservice', 'Support'),
        t('👤 Mens + videogesprek', '👤 Human + video call'),
        t('📧 E-mail (traag)', '📧 Email (slow)'),
        '📧 E-mail',
        '📧 E-mail',
        '📧 E-mail',
      ],
    ];

    Widget brandHeaderCell(String name, {bool highlight = false}) {
      final inner = Text(
        name,
        style: TextStyle(
          color: highlight ? Colors.white : Colors.white70,
          fontSize: 12,
          fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      );
      if (!highlight) {
        return SizedBox(
          width: brandWidth,
          child: Center(
            child: FittedBox(fit: BoxFit.scaleDown, child: inner),
          ),
        );
      }
      return SizedBox(
        width: brandWidth,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: BigDoggTheme.gold500,
              borderRadius: BorderRadius.circular(6),
            ),
            child: FittedBox(fit: BoxFit.scaleDown, child: inner),
          ),
        ),
      );
    }

    Widget valueCell(String s, {required bool isBigDogg}) {
      final isEmoji = s == '✅' || s == '❌' || s == '⚠️';
      Color color = BigDoggTheme.lightTextPrimary;
      if (isBigDogg && s.startsWith('€')) {
        color = BigDoggTheme.teal800;
      }
      return SizedBox(
        width: brandWidth,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              s,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isEmoji ? 18 : 12,
                color: color,
                fontWeight: isBigDogg && s.startsWith('€')
                    ? FontWeight.w800
                    : FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ),
      );
    }

    final headerRow = Container(
      width: tableWidth,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: const BoxDecoration(
        color: BigDoggTheme.teal800,
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: labelWidth),
          brandHeaderCell('BigDogg', highlight: true),
          brandHeaderCell('Moneybird'),
          brandHeaderCell('Exact'),
          brandHeaderCell('Tellow'),
          brandHeaderCell('Bunni'),
        ],
      ),
    );

    final dataRows = rows.asMap().entries.map((entry) {
      final i = entry.key;
      final row = entry.value;
      final isLast = i == rows.length - 1;
      return Container(
        width: tableWidth,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: i.isEven
              ? BigDoggTheme.lightBg.withOpacity(0.5)
              : BigDoggTheme.lightSurface,
          border: Border(
            top: BorderSide(color: BigDoggTheme.lightBorder),
          ),
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(15))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: labelWidth,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  row[0],
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: BigDoggTheme.lightTextPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            valueCell(row[1], isBigDogg: true),
            valueCell(row[2], isBigDogg: false),
            valueCell(row[3], isBigDogg: false),
            valueCell(row[4], isBigDogg: false),
            valueCell(row[5], isBigDogg: false),
          ],
        ),
      );
    }).toList();

    final table = Container(
      width: tableWidth,
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
      child: Column(children: [headerRow, ...dataRows]),
    );

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 64 : 16, vertical: 64),
      child: Column(
        children: [
          Text(
            t('Waarom ZZP\'ers kiezen voor BigDogg',
                'Why freelancers choose BigDogg'),
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
              'Wij zeggen niet dat anderen slecht zijn. Maar dit zijn wel de feiten.',
              'We\'re not saying the others are bad. These are just the facts.',
            ),
            style: const TextStyle(
                fontSize: 15,
                color: BigDoggTheme.lightTextSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          isWide
              ? Center(child: table)
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: table,
                ),
          if (!isWide) ...[
            const SizedBox(height: 8),
            Text(
              t('→ Veeg om alle kolommen te zien',
                  '→ Swipe to see all columns'),
              style: const TextStyle(
                  fontSize: 11,
                  color: BigDoggTheme.lightTextHint,
                  fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            t('* Alleen met Moneybird bankrekening',
                '* Only with a Moneybird bank account'),
            style: const TextStyle(
                fontSize: 11,
                color: BigDoggTheme.lightTextHint,
                fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          _buildAlleenBijBigDoggSection(isWide),
        ],
      ),
    );
  }

  Widget _buildAlleenBijBigDoggSection(bool isWide) {
    final cards = [
      {
        'title': t('AI facturering uit één zin',
            'AI invoicing from one sentence'),
        'body': t(
          'Typ in gewoon Nederlands wat je hebt gedaan. BigDogg maakt de factuur compleet — met BTW, klantgegevens en je logo. Geen ander pakket doet dit.',
          'Type in plain language what you did. BigDogg writes the complete invoice — with VAT, client details and your logo. No other tool does this.',
        ),
      },
      {
        'title': t('AI jaarrapport met belastingtips',
            'AI annual report with tax tips'),
        'body': t(
          'Aan het eind van het jaar krijg je een compleet rapport mét tips voor aftrekposten op basis van jouw cijfers. Werk dat een accountant honderden euro\'s kost.',
          'At year-end you get a complete report with deduction tips based on your numbers. Work an accountant would charge you hundreds for.',
        ),
      },
      {
        'title': t('Historische import via AI', 'Historical import via AI'),
        'body': t(
          'Sleep oude facturen van Moneybird of Exact erin. BigDogg leest ze automatisch in en bouwt direct een jaarrapport. Overstappen kost 5 minuten.',
          'Drop old invoices from Moneybird or Exact in. BigDogg reads them automatically and builds an annual report instantly. Switching takes 5 minutes.',
        ),
      },
    ];

    return isWide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: cards
                .map((c) => Expanded(child: _alleenBijBigDoggCard(c)))
                .toList(),
          )
        : Column(
            children: cards
                .map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _alleenBijBigDoggCard(c),
                    ))
                .toList(),
          );
  }

  Widget _alleenBijBigDoggCard(Map c) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(14),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: BigDoggTheme.gold500,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              t('Alleen bij BigDogg', 'Only at BigDogg'),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5),
            ),
          ),
          const SizedBox(height: 12),
          Text(c['title'] as String,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: BigDoggTheme.teal800,
                  height: 1.3)),
          const SizedBox(height: 8),
          Text(c['body'] as String,
              style: const TextStyle(
                  color: BigDoggTheme.lightTextSecondary,
                  fontSize: 13,
                  height: 1.55)),
        ],
      ),
    );
  }

  // ─── Support callout ─────────────────────────────────────
  Widget _buildSupportCallout(bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 64 : 20,
          vertical: isWide ? 32 : 24),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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

  // ─── Pricing ──────────────────────────────────────────────
  Widget _buildPricing(bool isWide) {
    final list = [
      t('✓ Onbeperkt facturen maken', '✓ Unlimited invoices'),
      t('✓ AI factuur uit één zin', '✓ AI invoice from one sentence'),
      t('✓ Oude facturen importeren', '✓ Import old invoices'),
      t('✓ PDF maken & versturen', '✓ Make & send PDFs'),
      t('✓ Klanten beheren', '✓ Manage clients'),
      t('✓ Uitgaven & bonnen bijhouden', '✓ Track expenses & receipts'),
      t('✓ BTW-aangifte per kwartaal', '✓ Quarterly VAT report'),
      t('✓ Jaarrapport met aftrekposten-tips',
          '✓ Annual report with deduction tips'),
      t('✓ iDEAL betaallinks via Stripe', '✓ iDEAL payment links via Stripe'),
    ];

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
            t('Eén vaste prijs. Geen verrassingen.',
                'One flat price. No surprises.'),
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
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(t('/ maand', '/ month'),
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 16)),
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
                    border: Border.all(
                        color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      const Text('🇳🇱',
                          style: TextStyle(fontSize: 16)),
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
                    child: Text(t('Probeer 30 dagen gratis →',
                        'Try free for 30 days →')),
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
        ],
      ),
    );
  }

  // ─── Final CTA ────────────────────────────────────────────
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
              'Klaar voor simpele administratie?',
              'Ready for simple admin?',
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
                'Probeer gratis — geen creditcard nodig',
                'Try free — no credit card needed')),
          ),
          const SizedBox(height: 16),
          Text(
            kIsWeb
                ? t(
                    '30 dagen gratis. Daarna €9,99 per maand. Altijd opzegbaar.',
                    '30 days free. Then €9.99 per month. Cancel anytime.')
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

  // ─── App store badges ─────────────────────────────────────
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

  // ─── Footer ───────────────────────────────────────────────
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
                          t('Algemene Voorwaarden',
                              'Terms & Conditions'),
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12)),
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

// ─── Support dialog ───────────────────────────────────────
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
      setState(() => _error = t(
          'Vul alle velden in.', 'Please fill in all fields.'));
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: BigDoggTheme.lightSurface,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints:
            const BoxConstraints(maxWidth: 480, maxHeight: 680),
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
              fontSize: 13,
              color: BigDoggTheme.lightTextSecondary),
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
        _label(t('Hoe wil je antwoord?',
            'How would you like a reply?')),
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
                  fontWeight: selected
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
