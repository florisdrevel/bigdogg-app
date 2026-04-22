import 'package:flutter/material.dart';
import '../theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WalkthroughOverlay — sits on top of the dashboard, shows a banner at the
// top of the content area. No backdrop, no spotlight. Clean and simple.
// ─────────────────────────────────────────────────────────────────────────────

class WalkthroughOverlay extends StatefulWidget {
  final Widget child;
  final bool isNl;
  final bool active;
  final VoidCallback onComplete;
  final ValueChanged<int> onTabChange;
  final int currentTabIndex;
  final bool projectsEnabled;

  const WalkthroughOverlay({
    super.key,
    required this.child,
    required this.isNl,
    required this.active,
    required this.onComplete,
    required this.onTabChange,
    required this.currentTabIndex,
    required this.projectsEnabled,
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

  // ── Steps ─────────────────────────────────────────────────────────────────

  List<_Step> get _steps {
    final nl = widget.isNl;
    final proj = widget.projectsEnabled;
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
        bodyNl: 'Scroll naar beneden op dit scherm. Heb je facturen of kosten van vóór BigDogg? Importeer ze als PDF. BigDogg leest ze uit met AI en voegt ze toe aan je administratie.',
        bodyEn: 'Scroll down on this screen. Have invoices or expenses from before BigDogg? Import them as PDF. BigDogg reads them with AI and adds them to your records.',
      ),
      _Step(
        tabIndex: 2,
        icon: Icons.inventory_2_outlined,
        titleNl: 'Producten',
        titleEn: 'Products',
        bodyNl: 'Voeg je diensten of producten toe met een prijs en BTW-tarief. Daarna kun je ze met één tik op elke factuur zetten — geen handmatig invoeren meer.',
        bodyEn: 'Add your services or products with a price and VAT rate. Then add them to any invoice with one tap — no more manual entry.',
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
        icon: Icons.receipt_long_outlined,
        titleNl: 'Facturen — Aanmaken',
        titleEn: 'Invoices — Create',
        bodyNl: 'Gebruik de robot-knop rechtsonder om AI een factuur te laten genereren vanuit een beschrijving in gewone taal. Of gebruik de + knop om een factuur stap voor stap zelf op te bouwen.',
        bodyEn: 'Use the robot button (bottom-right) to let AI generate an invoice from a plain-language description. Or use the + button to build an invoice step by step yourself.',
      ),
      _Step(
        tabIndex: 3,
        icon: Icons.account_balance_wallet_outlined,
        titleNl: 'Kosten',
        titleEn: 'Expenses',
        bodyNl: 'Voeg kosten toe via de camera (foto van je bon) of handmatig met de + knop. Gebruik het map-icoon voor afschrijvingen op investeringen. BTW wordt automatisch berekend.',
        bodyEn: 'Add expenses via camera (photo of your receipt) or manually with the + button. Use the folder icon for depreciation on investments. VAT is calculated automatically.',
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
        bodyNl: 'Scroll naar beneden in het kwartaaloverzicht om je uren te registreren. BigDogg houdt bij of je het urencriterium van 1.225 uur haalt — belangrijk voor de zelfstandigenaftrek.',
        bodyEn: 'Scroll down in the quarterly overview to log your hours. BigDogg tracks whether you meet the 1,225-hour criterion — key for the self-employed tax deduction.',
      ),
      if (proj)
        _Step(
          tabIndex: 4,
          icon: Icons.folder_outlined,
          titleNl: 'Projecten',
          titleEn: 'Projects',
          bodyNl: 'Activeer projecten in Instellingen. Maak projecten aan en koppel facturen en kosten eraan. Zo zie je per opdracht precies wat je hebt verdiend en uitgegeven.',
          bodyEn: 'Enable projects in Settings. Create projects and link invoices and expenses to them. See exactly what each job earned and cost.',
          isProjectsTab: true,
        ),
      _Step(
        tabIndex: -1,
        icon: Icons.settings_outlined,
        titleNl: 'Instellingen — Stripe & meer',
        titleEn: 'Settings — Stripe & more',
        bodyNl: 'Koppel je Stripe account om betaallinks op facturen te zetten. Klanten betalen direct via iDEAL of creditcard — ideaal voor betaling op locatie via QR-code. Hier vind je ook je abonnement en wachtwoordinstellingen.',
        bodyEn: 'Connect Stripe to add payment links to invoices. Clients pay directly via iDEAL or credit card — great for on-the-spot payment via QR code. You\'ll also find subscription and password settings here.',
        isSettings: true,
      ),
    ];
  }

  int _resolvedTab(_Step step) {
    if (step.isSettings) return widget.projectsEnabled ? 7 : 6;
    if (step.isProjectsTab) return 4;
    return step.tabIndex;
  }

  void _applyTab(_Step step) {
    final idx = _resolvedTab(step);
    if (widget.currentTabIndex != idx) widget.onTabChange(idx);
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
    final isNl = widget.isNl;
    final isLast = _stepIndex == steps.length - 1;
    final isFirst = _stepIndex == 0;
    final topPad = MediaQuery.of(context).padding.top;
    final appBarH = kToolbarHeight + topPad + 1;

    return Stack(
      children: [
        widget.child,
        // Banner positioned just below the AppBar
        Positioned(
          top: appBarH,
          left: 0,
          right: 0,
          child: AnimatedBuilder(
            animation: _anim,
            builder: (context, child) => FractionalTranslation(
              translation: Offset(0, _slide.value),
              child: Opacity(opacity: _fade.value.clamp(0.0, 1.0), child: child),
            ),
            child: _Banner(
              step: step,
              isNl: isNl,
              stepIndex: _stepIndex,
              total: steps.length,
              isFirst: isFirst,
              isLast: isLast,
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
// Banner widget
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
        children: [
          // Top row: icon + title + skip
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
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // Body text
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              isNl ? step.bodyNl : step.bodyEn,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),

          // Bottom row: dots + prev + next
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                // Progress dots
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
                          color: active ? BigDoggTheme.gold500 : Colors.white24,
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

  const _Step({
    required this.tabIndex,
    required this.icon,
    required this.titleNl,
    required this.titleEn,
    required this.bodyNl,
    required this.bodyEn,
    this.isProjectsTab = false,
    this.isSettings = false,
  });
}