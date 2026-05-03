import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme.dart';

class WalkthroughOverlay extends StatefulWidget {
  final Widget child;
  final bool isNl;
  final bool active;
  final VoidCallback onComplete;
  final ValueChanged<int> onTabChange;
  final int currentTabIndex;
  final bool projectsEnabled;
  final bool quotesEnabled;

  const WalkthroughOverlay({
    super.key,
    required this.child,
    required this.isNl,
    required this.active,
    required this.onComplete,
    required this.onTabChange,
    required this.currentTabIndex,
    required this.projectsEnabled,
    required this.quotesEnabled,
  });

  @override
  State<WalkthroughOverlay> createState() => _WalkthroughOverlayState();
}

class _WalkthroughOverlayState extends State<WalkthroughOverlay>
    with SingleTickerProviderStateMixin {
  int _stepIndex = 0;
  late AnimationController _anim;
  late Animation<double> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _slide = Tween<double>(begin: -1, end: 0).animate(
        CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    if (widget.active) _anim.forward();
  }

  @override
  void didUpdateWidget(WalkthroughOverlay old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _stepIndex = 0;
      _anim.forward(from: 0);
      _applyTab(_steps[0]);
    }
    if (!widget.active && old.active) _anim.reverse();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  List<_Step> get _steps {
    final proj = widget.projectsEnabled;
    final quotes = widget.quotesEnabled;
    return [
      _Step(
        tabIndex: 5,
        icon: Icons.person_outline_rounded,
        titleNl: 'Profiel — Bedrijfsgegevens',
        titleEn: 'Profile — Business details',
        bodyNl: 'Vul je bedrijfsnaam, adres, KVK-nummer, BTW-nummer en IBAN in. Deze gegevens verschijnen automatisch op al je facturen. Upload ook je logo — het staat dan linksboven op elke factuur.',
        bodyEn: 'Fill in your business name, address, KVK, VAT number and IBAN. These appear automatically on all your invoices. Upload your logo too — it appears top-left on every invoice.',
      ),
      _Step(
        tabIndex: 5,
        icon: Icons.upload_file_outlined,
        titleNl: 'Profiel — Historische import',
        titleEn: 'Profile — Historical import',
        bodyNl: 'Scroll naar beneden op dit scherm. Heb je facturen of kosten van vóór BigDogg? Importeer ze als PDF. BigDogg leest ze uit met AI en voegt ze toe aan je administratie. Dubbele worden automatisch geblokkeerd.',
        bodyEn: 'Scroll down on this screen. Have invoices or expenses from before BigDogg? Import them as PDF. BigDogg reads them with AI and adds them to your records. Duplicates are blocked automatically.',
      ),
      _Step(
        tabIndex: 5,
        icon: Icons.palette_outlined,
        titleNl: 'Profiel — Factuurkleuren',
        titleEn: 'Profile — Invoice colors',
        bodyNl: 'Scroll naar het kaartje "Factuurkleuren". Tik op een kleurvakje om je hoofd- en accentkleur te kiezen — kies uit de presets of voer een eigen hex-code in. Standaard zijn dit de BigDogg kleuren (donker teal + goud).',
        bodyEn: 'Scroll to the "Invoice colors" card. Tap a swatch to pick your primary and accent colors — choose from the presets or enter a custom hex. Defaults to the BigDogg teal + gold.',
      ),
      _Step(
        tabIndex: 2,
        icon: Icons.inventory_2_outlined,
        titleNl: 'Producten',
        titleEn: 'Products',
        bodyNl: 'Voeg je diensten of producten toe met een prijs, Unit-type en BTW-tarief. Een dag-unit voegt automatisch 9 uren toe aan je urenregistratie.  Daarna kun je ze met één tik op elke factuur zetten — geen handmatig invoeren meer.',
        bodyEn: 'Add your services or products with a price, Unit-type and VAT rate. A day-unit automatically counts 9 hours towards your hour registration.  Then add them to any invoice with one tap — no more manual entry.',
      ),
      _Step(
        tabIndex: 1,
        icon: Icons.people_outline_rounded,
        titleNl: 'Klanten',
        titleEn: 'Clients',
        bodyNl: 'Voeg klanten handmatig toe met de + knop, of stuur ze een uitnodigingslink via de deel-knop. De klant vult zelf zijn gegevens in — jij hoeft niets over te typen.',
        bodyEn: 'Add clients manually with the + button, or send them an invite link via the share button. The client fills in their own details — no typing needed.',
      ),
      _Step(
        tabIndex: 0,
        subTab: 0,
        icon: Icons.receipt_long_outlined,
        titleNl: 'Facturen — Aanmaken',
        titleEn: 'Invoices — Create',
        bodyNl: 'Gebruik de robot-knop rechtsonder om AI een factuur te laten genereren vanuit een beschrijving in gewone taal. Of gebruik de + knop om een factuur stap voor stap zelf op te bouwen.',
        bodyEn: 'Use the robot button (bottom-right) to let AI generate an invoice from a plain-language description. Or use the + button to build an invoice step by step yourself.',
      ),
      if (quotes)
        _Step(
          tabIndex: 0,
          subTab: 1,
          icon: Icons.description_outlined,
          titleNl: 'Offertes',
          titleEn: 'Quotes',
          bodyNl: 'Maak een offerte met de robot-knop (AI) of de + knop en verstuur \'m per e-mail. De klant krijgt een mailtje met een Accepteer-knop — één klik en de status wordt automatisch in BigDogg bijgewerkt. Bij een geaccepteerde offerte zet je hem met één tik om naar een factuur. Heb je geen offertes nodig? Zet ze uit in Instellingen.',
          bodyEn: 'Create a quote via the robot (AI) or + button and send it by email. The client gets a mail with an Accept button — one click and the status updates in BigDogg automatically. Once accepted, convert to an invoice with a single tap. Don\'t need quotes? Turn them off in Settings.',
        ),
      _Step(
        tabIndex: 3,
        subTab: 0,
        icon: Icons.account_balance_wallet_outlined,
        titleNl: 'Kosten',
        titleEn: 'Expenses',
        bodyNl: 'Voeg kosten toe via de camera (foto van je bon) of handmatig met de + knop. BTW wordt automatisch berekend. Bovenaan kun je per kwartaal filteren — zo zie je alleen de kosten van het lopende kwartaal.',
        bodyEn: 'Add expenses via camera (photo of your receipt) or manually with the + button. VAT is calculated automatically. The selector at the top filters per quarter — handy to focus on the running quarter.',
      ),
      _Step(
        tabIndex: 3,
        subTab: 1,
        icon: Icons.trending_up_outlined,
        titleNl: 'Investeringen & Afschrijvingen',
        titleEn: 'Investments & Depreciation',
        bodyNl: 'Investeringen vanaf €450 schrijf je af over meerdere jaren (NL belastingwet). Voeg ze hier toe met de + knop — BigDogg berekent het afschrijvingsschema automatisch en neemt het mee in je jaarrapport.',
        bodyEn: 'Investments of €450 or more are depreciated over multiple years (Dutch tax law). Add them here with the + button — BigDogg calculates the depreciation schedule and rolls it into your annual report.',
      ),
      _Step(
        tabIndex: 4,
        icon: Icons.bar_chart_rounded,
        titleNl: 'Overzicht — BTW & Jaarrapport',
        titleEn: 'Overview — VAT & Annual report',
        bodyNl: 'Bekijk per kwartaal je omzet, kosten en te betalen BTW. Download de BTW-aangifte als PDF. Schakel naar "Dit jaar" voor het volledige jaarrapport met AI-belastingtips.',
        bodyEn: 'See revenue, expenses and VAT due per quarter. Download the VAT return as PDF. Switch to "This year" for the full annual report with AI tax tips.',
      ),
      _Step(
        tabIndex: 4,
        icon: Icons.access_time_rounded,
        titleNl: 'Overzicht — Urenregistratie',
        titleEn: 'Overview — Hours tracker',
        bodyNl: 'Bovenin in het kwartaaloverzicht kun je handmatig je uren te registreren. BigDogg houdt bij of je het urencriterium van 1.225 uur haalt — belangrijk voor de zelfstandigenaftrek.',
        bodyEn: 'At the top of the quarterly overview you are able to manually log your hours. BigDogg tracks whether you meet the 1,225-hour criterion — key for the self-employed tax deduction.',
      ),
      if (proj)
        _Step(
          tabIndex: 4,
          icon: Icons.folder_outlined,
          titleNl: 'Projecten',
          titleEn: 'Projects',
          bodyNl: 'Maak projecten aan en koppel facturen en kosten eraan. Zo zie je per opdracht precies wat je hebt verdiend en uitgegeven.',
          bodyEn: 'Create projects and link invoices and expenses to them. See exactly what each job earned and cost.',
          isProjectsTab: true,
        ),
      _Step(
        tabIndex: -1,
        icon: Icons.tune_rounded,
        titleNl: 'Instellingen — Functies aan-/uitzetten',
        titleEn: 'Settings — Toggle features on/off',
        bodyNl: 'Bovenaan in Instellingen vind je schakelaars voor Offertes en Projecten. Niet iedereen heeft alles nodig — zet aan of uit wat past bij hoe jij werkt. Verberg Offertes als je alleen factureert, of zet Projecten aan om opdrachten apart bij te houden.',
        bodyEn: 'At the top of Settings you\'ll find switches for Quotes and Projects. Not everyone needs everything — toggle whatever fits how you work. Hide Quotes if you only invoice, or enable Projects to track work per job.',
        isSettings: true,
      ),
      _Step(
        tabIndex: -1,
        icon: Icons.credit_card_rounded,
        titleNl: 'Instellingen — Stripe & abonnement',
        titleEn: 'Settings — Stripe & subscription',
        bodyNl: 'Koppel je Stripe-account om betaallinks op facturen te zetten. Klanten betalen direct via iDEAL of creditcard — ideaal voor betaling op locatie via QR-code. Op dit scherm beheer je ook je abonnement en wachtwoord.',
        bodyEn: 'Connect Stripe to add payment links to invoices. Clients pay directly via iDEAL or credit card — great for on-the-spot payment via QR code. You also manage your subscription and password on this screen.',
        isSettings: true,
      ),
      _Step(
        tabIndex: -1,
        icon: Icons.account_balance_outlined,
        titleNl: 'Instellingen — Bankrekening koppelen',
        titleEn: 'Settings — Connect your bank',
        bodyNl: 'Koppel je Nederlandse bankrekening via Tink (PSD2). BigDogg krijgt alleen leestoegang en kan dan automatisch je transacties inlezen, zodat je kosten niet meer met de hand hoeft in te voeren.',
        bodyEn: 'Connect your Dutch bank account via Tink (PSD2). BigDogg only gets read access and can then automatically pull in your transactions, so you don\'t need to enter expenses by hand.',
        isSettings: true,
      ),
    ];
  }

  int _resolvedTab(_Step step) {
    if (step.isSettings) return widget.projectsEnabled ? 7 : 6;
    if (step.isProjectsTab) return 4;
    // step.tabIndex is written for the projects-OFF layout
    // (Overview=4, Profile=5). When Projects is enabled, the Projects
    // screen inserts at index 4 and shifts everything from 4 upward by +1.
    if (widget.projectsEnabled && step.tabIndex >= 4) {
      return step.tabIndex + 1;
    }
    return step.tabIndex;
  }

  void _applyTab(_Step step) {
    final idx = _resolvedTab(step);
    if (widget.currentTabIndex != idx) widget.onTabChange(idx);
    // If the step also targets an inner sub-tab, push it through AppProvider
    // so the affected screen (Invoices or Expenses) animates its TabController.
    final sub = step.subTab;
    if (sub != null) {
      final app = context.read<AppProvider>();
      if (step.tabIndex == 0) {
        app.setInvoicesSubTab(sub);
      } else if (step.tabIndex == 3) {
        app.setExpensesSubTab(sub);
      }
    }
  }

  void _animateToNext(VoidCallback after) {
    _anim.reverse().then((_) {
      after();
      _anim.forward();
    });
  }

  void _next() {
    final steps = _steps;
    if (_stepIndex < steps.length - 1) {
      _animateToNext(() {
        setState(() => _stepIndex++);
        _applyTab(steps[_stepIndex]);
      });
    } else {
      widget.onComplete();
    }
  }

  void _prev() {
    if (_stepIndex > 0) {
      _animateToNext(() {
        setState(() => _stepIndex--);
        _applyTab(_steps[_stepIndex]);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;

    final steps = _steps;
    final step = steps[_stepIndex];
    final topPad = MediaQuery.of(context).padding.top;
    final appBarH = kToolbarHeight + topPad + 1;

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: appBarH,
          left: 0,
          right: 0,
          child: AnimatedBuilder(
            animation: _anim,
            builder: (context, child) => FractionalTranslation(
              translation: Offset(0, _slide.value),
              child: Opacity(
                  opacity: _fade.value.clamp(0.0, 1.0), child: child),
            ),
            child: _Banner(
              step: step,
              isNl: widget.isNl,
              stepIndex: _stepIndex,
              total: steps.length,
              isFirst: _stepIndex == 0,
              isLast: _stepIndex == steps.length - 1,
              onNext: _next,
              onPrev: _prev,
              onSkip: widget.onComplete,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner
// ─────────────────────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  final _Step step;
  final bool isNl;
  final int stepIndex, total;
  final bool isFirst, isLast;
  final VoidCallback onNext, onPrev, onSkip;

  const _Banner({
    required this.step,
    required this.isNl,
    required this.stepIndex,
    required this.total,
    required this.isFirst,
    required this.isLast,
    required this.onNext,
    required this.onPrev,
    required this.onSkip,
  });

  // Shared style that explicitly kills any underline or decoration
  static const _noDecoration = TextDecoration.none;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: BigDoggTheme.teal800,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: icon + title + skip ────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: BigDoggTheme.gold500.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(step.icon, size: 18, color: BigDoggTheme.gold500),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isNl ? step.titleNl : step.titleEn,
                    style: const TextStyle(
                      color: BigDoggTheme.gold500,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'PlusJakartaSans',
                      decoration: _noDecoration,
                      decorationColor: Colors.transparent,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    isNl ? 'Overslaan' : 'Skip',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      decoration: _noDecoration,
                      decorationColor: Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body text ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              isNl ? step.bodyNl : step.bodyEn,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                height: 1.55,
                fontWeight: FontWeight.w400,
                decoration: _noDecoration,
                decorationColor: Colors.transparent,
              ),
            ),
          ),

          // ── Bottom row: dots + prev + next ───────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: List.generate(total, (i) {
                      final active = i == stepIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: active ? 16 : 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: active
                              ? BigDoggTheme.gold500
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                if (!isFirst) ...[
                  _btn(
                    label: isNl ? 'Vorige' : 'Prev',
                    onTap: onPrev,
                    bg: Colors.white12,
                    fg: Colors.white,
                  ),
                  const SizedBox(width: 8),
                ],
                _btn(
                  label: isLast
                      ? (isNl ? 'Klaar!' : 'Done!')
                      : (isNl ? 'Volgende' : 'Next'),
                  onTap: onNext,
                  bg: BigDoggTheme.gold500,
                  fg: Colors.white,
                  bold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _btn({
    required String label,
    required VoidCallback onTap,
    required Color bg,
    required Color fg,
    bool bold = false,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              decoration: TextDecoration.none,
              decorationColor: Colors.transparent,
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Data
// ─────────────────────────────────────────────────────────────────────────────

class _Step {
  final int tabIndex;
  final IconData icon;
  final String titleNl, titleEn, bodyNl, bodyEn;
  final bool isProjectsTab;
  final bool isSettings;
  // Optional: switch the inner sub-tab inside the parent screen.
  // Used so the walkthrough lands on Offertes (1) inside Invoices and
  // Investeringen (1) inside Expenses, instead of always the first sub-tab.
  final int? subTab;

  const _Step({
    required this.tabIndex,
    required this.icon,
    required this.titleNl,
    required this.titleEn,
    required this.bodyNl,
    required this.bodyEn,
    this.isProjectsTab = false,
    this.isSettings = false,
    this.subTab,
  });
}