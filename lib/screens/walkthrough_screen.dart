import 'package:flutter/material.dart';
import '../theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point — wraps the dashboard Scaffold
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
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeInOut);
    if (widget.active) _anim.forward();
  }

  @override
  void didUpdateWidget(WalkthroughOverlay old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _stepIndex = 0;
      _anim.forward(from: 0);
      final steps = _steps(widget.isNl, widget.projectsEnabled);
      _applyTab(steps[0]);
    }
    if (!widget.active && old.active) {
      _anim.reverse();
    }
  }

  List<_Step> _steps(bool isNl, bool projectsEnabled) {
    return <_Step>[
      _Step(
        tabIndex: 5,
        spotType: _SpotType.topContent,
        titleNl: 'Profiel — Bedrijfsgegevens',
        titleEn: 'Profile — Business details',
        bodyNl: 'Vul je naam, adres, KVK-nummer, BTW-nummer en IBAN in. Deze gegevens verschijnen automatisch op al je facturen.',
        bodyEn: 'Fill in your name, address, KVK, VAT number and IBAN. These appear automatically on all your invoices.',
        cardPosition: _CardPos.bottom,
      ),
      _Step(
        tabIndex: 5,
        spotType: _SpotType.logoArea,
        titleNl: 'Profiel — Logo',
        titleEn: 'Profile — Logo',
        bodyNl: 'Upload je bedrijfslogo. Het wordt automatisch linksboven op elke factuur geplaatst.',
        bodyEn: 'Upload your company logo. It appears automatically top-left on every invoice.',
        cardPosition: _CardPos.bottom,
      ),
      _Step(
        tabIndex: 5,
        spotType: _SpotType.bottomContent,
        titleNl: 'Profiel — Historische import',
        titleEn: 'Profile — Historical import',
        bodyNl: 'Facturen of kosten van vóór BigDogg? Importeer ze als PDF. BigDogg leest ze uit met AI en voegt ze toe aan je administratie.',
        bodyEn: 'Invoices or expenses from before BigDogg? Import them as PDF. BigDogg reads them with AI and adds them to your records.',
        cardPosition: _CardPos.top,
      ),
      _Step(
        tabIndex: 2,
        spotType: _SpotType.fab,
        titleNl: 'Producten',
        titleEn: 'Products',
        bodyNl: 'Voeg je diensten of producten toe met prijs en BTW-tarief. Zet ze daarna met één tik op elke factuur — geen handmatig invoeren meer.',
        bodyEn: 'Add your services or products with price and VAT rate. Then add them to any invoice with one tap.',
        cardPosition: _CardPos.top,
      ),
      _Step(
        tabIndex: 1,
        spotType: _SpotType.fab,
        titleNl: 'Klanten',
        titleEn: 'Clients',
        bodyNl: 'Voeg klanten handmatig toe, of stuur een uitnodigingslink. De klant vult zelf zijn gegevens in — jij hoeft niets over te typen.',
        bodyEn: 'Add clients manually, or send an invite link. The client fills in their own details — no typing needed.',
        cardPosition: _CardPos.top,
      ),
      _Step(
        tabIndex: 0,
        spotType: _SpotType.doubleFab,
        titleNl: 'Facturen — Aanmaken',
        titleEn: 'Invoices — Create',
        bodyNl: 'Robot-knop: AI genereert de factuur vanuit een beschrijving in gewone taal. Plus-knop: bouw de factuur zelf stap voor stap op.',
        bodyEn: 'Robot button: AI generates the invoice from a plain-language description. Plus button: build the invoice yourself step by step.',
        cardPosition: _CardPos.top,
      ),
      _Step(
        tabIndex: 3,
        spotType: _SpotType.fab,
        titleNl: 'Kosten',
        titleEn: 'Expenses',
        bodyNl: 'Voeg kosten toe via de camera (foto van je bon), handmatig, of als afschrijving voor investeringen. BTW wordt automatisch berekend.',
        bodyEn: 'Add expenses via camera (photo of your receipt), manually, or as depreciation for investments. VAT is calculated automatically.',
        cardPosition: _CardPos.top,
      ),
      _Step(
        tabIndex: 4,
        spotType: _SpotType.topContent,
        titleNl: 'Overzicht — BTW aangifte',
        titleEn: 'Overview — VAT return',
        bodyNl: 'Bekijk per kwartaal je omzet, kosten en te betalen BTW. Download de aangifte als PDF en dien hem in bij de Belastingdienst.',
        bodyEn: 'See revenue, expenses and VAT due per quarter. Download the return as PDF and submit it to the Tax Authority.',
        cardPosition: _CardPos.bottom,
      ),
      _Step(
        tabIndex: 4,
        spotType: _SpotType.midContent,
        titleNl: 'Overzicht — Jaarrapport',
        titleEn: 'Overview — Annual report',
        bodyNl: 'Schakel naar "Dit jaar" voor een volledig jaaroverzicht. Download het jaarrapport als PDF — inclusief persoonlijke belastingtips van AI.',
        bodyEn: 'Switch to "This year" for a full annual overview. Download the annual report as PDF — with personalised AI tax tips.',
        cardPosition: _CardPos.bottom,
      ),
      _Step(
        tabIndex: 4,
        spotType: _SpotType.bottomContent,
        titleNl: 'Overzicht — Urenregistratie',
        titleEn: 'Overview — Hours tracker',
        bodyNl: 'Registreer je gewerkte uren. BigDogg houdt bij of je het urencriterium van 1.225 uur haalt — belangrijk voor de zelfstandigenaftrek.',
        bodyEn: 'Log your worked hours. BigDogg tracks whether you meet the 1,225-hour criterion — key for the self-employed tax deduction.',
        cardPosition: _CardPos.top,
      ),
      if (projectsEnabled)
        _Step(
          tabIndex: -1, // resolved separately
          spotType: _SpotType.topContent,
          titleNl: 'Projecten',
          titleEn: 'Projects',
          bodyNl: 'Maak projecten aan en koppel facturen en kosten eraan. Zo zie je per opdracht precies wat je hebt verdiend en uitgegeven.',
          bodyEn: 'Create projects and link invoices and expenses to them. See exactly what each job earned and cost.',
          cardPosition: _CardPos.bottom,
          isProjectsTab: true,
        ),
      _Step(
        tabIndex: -2, // settings — resolved separately
        spotType: _SpotType.midContent,
        titleNl: 'Instellingen — Stripe',
        titleEn: 'Settings — Stripe',
        bodyNl: 'Koppel je Stripe account om betaallinks op facturen te zetten. Klanten betalen direct via iDEAL of creditcard. Handig voor betaling op locatie via QR-code.',
        bodyEn: 'Connect Stripe to add payment links to invoices. Clients pay directly via iDEAL or credit card — great for on-the-spot payment via QR code.',
        cardPosition: _CardPos.bottom,
      ),
    ];
  }

  int _resolvedTabIndex(_Step step, bool projectsEnabled) {
    if (step.isProjectsTab) return 4; // projects tab is index 4 when enabled
    if (step.tabIndex == -2) return projectsEnabled ? 7 : 6; // settings
    return step.tabIndex;
  }

  void _applyTab(_Step step) {
    final idx = _resolvedTabIndex(step, widget.projectsEnabled);
    if (widget.currentTabIndex != idx) {
      widget.onTabChange(idx);
    }
  }

  void _next() {
    final steps = _steps(widget.isNl, widget.projectsEnabled);
    if (_stepIndex < steps.length - 1) {
      setState(() => _stepIndex++);
      _applyTab(steps[_stepIndex]);
    } else {
      widget.onComplete();
    }
  }

  void _prev() {
    if (_stepIndex > 0) {
      final steps = _steps(widget.isNl, widget.projectsEnabled);
      setState(() => _stepIndex--);
      _applyTab(steps[_stepIndex]);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;

    final steps = _steps(widget.isNl, widget.projectsEnabled);
    final step = steps[_stepIndex];
    final size = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;
    final appBarH = kToolbarHeight + topPad + 1;
    const bottomNavH = 70.0;
    final contentH = size.height - appBarH - bottomNavH;

    final spotlight = _spotRect(step.spotType, size, appBarH, contentH, bottomNavH);

    return Stack(
      children: [
        widget.child,
        FadeTransition(
          opacity: _fade,
          child: _CoachMarkLayer(
            spotlight: spotlight,
            step: step,
            isNl: widget.isNl,
            stepIndex: _stepIndex,
            totalSteps: steps.length,
            isLast: _stepIndex == steps.length - 1,
            isFirst: _stepIndex == 0,
            onNext: _next,
            onPrev: _prev,
            onSkip: widget.onComplete,
            screenSize: size,
            appBarH: appBarH,
            bottomNavH: bottomNavH,
          ),
        ),
      ],
    );
  }

  Rect _spotRect(_SpotType type, Size size, double appBarH, double contentH, double bottomNavH) {
    final w = size.width;
    final h = size.height;
    const pad = 12.0;

    switch (type) {
      case _SpotType.topContent:
        return Rect.fromLTWH(pad, appBarH + pad, w - pad * 2, contentH * 0.42);
      case _SpotType.logoArea:
        return Rect.fromLTWH(w * 0.25, appBarH + pad, w * 0.5, contentH * 0.20);
      case _SpotType.midContent:
        return Rect.fromLTWH(pad, appBarH + contentH * 0.28, w - pad * 2, contentH * 0.38);
      case _SpotType.bottomContent:
        return Rect.fromLTWH(pad, appBarH + contentH * 0.52, w - pad * 2, contentH * 0.40);
      case _SpotType.fab:
        return Rect.fromLTWH(w - 80, h - bottomNavH - 76, 64, 64);
      case _SpotType.doubleFab:
        return Rect.fromLTWH(w - 80, h - bottomNavH - 152, 64, 140);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Coach mark layer
// ─────────────────────────────────────────────────────────────────────────────

class _CoachMarkLayer extends StatelessWidget {
  final Rect spotlight;
  final _Step step;
  final bool isNl;
  final int stepIndex;
  final int totalSteps;
  final bool isLast;
  final bool isFirst;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onSkip;
  final Size screenSize;
  final double appBarH;
  final double bottomNavH;

  const _CoachMarkLayer({
    required this.spotlight,
    required this.step,
    required this.isNl,
    required this.stepIndex,
    required this.totalSteps,
    required this.isLast,
    required this.isFirst,
    required this.onNext,
    required this.onPrev,
    required this.onSkip,
    required this.screenSize,
    required this.appBarH,
    required this.bottomNavH,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dark backdrop with hole
        CustomPaint(
          size: screenSize,
          painter: _SpotlightPainter(spotlight: spotlight),
        ),

        // Gold border around spotlight
        Positioned(
          left: spotlight.left - 3,
          top: spotlight.top - 3,
          child: IgnorePointer(
            child: Container(
              width: spotlight.width + 6,
              height: spotlight.height + 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: BigDoggTheme.gold500, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: BigDoggTheme.gold500.withOpacity(0.4),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Step counter
        Positioned(
          top: appBarH + 10,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${stepIndex + 1} / $totalSteps',
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        // Skip
        Positioned(
          top: appBarH + 10,
          right: 16,
          child: GestureDetector(
            onTap: onSkip,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isNl ? 'Overslaan' : 'Skip',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ),

        // Info card
        _buildCard(),
      ],
    );
  }

  Widget _buildCard() {
    final cardW = screenSize.width - 32;
    double cardTop;
    if (step.cardPosition == _CardPos.bottom) {
      cardTop = spotlight.bottom + 14;
    } else {
      cardTop = spotlight.top - 190;
    }

    // Clamp so card never leaves visible area
    final safeTop = cardTop.clamp(
      appBarH + 50.0,
      screenSize.height - bottomNavH - 200.0,
    );

    return Positioned(
      left: 16,
      top: safeTop,
      child: SizedBox(
        width: cardW,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: BoxDecoration(
              color: BigDoggTheme.teal800,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isNl ? step.titleNl : step.titleEn,
                  style: const TextStyle(
                    color: BigDoggTheme.gold500,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  isNl ? step.bodyNl : step.bodyEn,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    // Progress dots
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        children: List.generate(totalSteps, (i) {
                          final active = i == stepIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: active ? 14 : 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: active ? BigDoggTheme.gold500 : Colors.white24,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!isFirst) ...[
                      GestureDetector(
                        onTap: onPrev,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isNl ? 'Vorige' : 'Prev',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    GestureDetector(
                      onTap: onNext,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                        decoration: BoxDecoration(
                          color: BigDoggTheme.gold500,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isLast
                              ? (isNl ? 'Klaar!' : 'Done!')
                              : (isNl ? 'Volgende' : 'Next'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Spotlight backdrop painter
// ─────────────────────────────────────────────────────────────────────────────

class _SpotlightPainter extends CustomPainter {
  final Rect spotlight;
  const _SpotlightPainter({required this.spotlight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.65);
    final full = Rect.fromLTWH(0, 0, size.width, size.height);
    final hole = RRect.fromRectAndRadius(spotlight, const Radius.circular(14));
    final path = Path()
      ..addRect(full)
      ..addRRect(hole)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.spotlight != spotlight;
}

// ─────────────────────────────────────────────────────────────────────────────
// Data
// ─────────────────────────────────────────────────────────────────────────────

enum _SpotType { topContent, logoArea, midContent, bottomContent, fab, doubleFab }
enum _CardPos { top, bottom }

class _Step {
  final int tabIndex;
  final _SpotType spotType;
  final String titleNl;
  final String titleEn;
  final String bodyNl;
  final String bodyEn;
  final _CardPos cardPosition;
  final bool isProjectsTab;

  const _Step({
    required this.tabIndex,
    required this.spotType,
    required this.titleNl,
    required this.titleEn,
    required this.bodyNl,
    required this.bodyEn,
    required this.cardPosition,
    this.isProjectsTab = false,
  });
}