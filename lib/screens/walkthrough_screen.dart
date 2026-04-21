import 'package:flutter/material.dart';
import '../theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WalkthroughOverlay — wraps the dashboard Scaffold
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
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeInOut);
    if (widget.active) _anim.forward();
  }

  @override
  void didUpdateWidget(WalkthroughOverlay old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _stepIndex = 0;
      _anim.forward(from: 0);
      final steps = _buildSteps(widget.projectsEnabled);
      _applyTab(steps[0]);
    }
    if (!widget.active && old.active) _anim.reverse();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  // ── Step definitions ──────────────────────────────────────────────────────

  List<_Step> _buildSteps(bool projectsEnabled) => [
        // 1 — Profile: business details form
        _Step(
          tabIndex: 5,
          spot: _SpotDef.profileForm,
          titleNl: 'Profiel — Bedrijfsgegevens',
          titleEn: 'Profile — Business details',
          bodyNl:
              'Vul je bedrijfsnaam, adres, KVK-nummer, BTW-nummer en IBAN in. Deze gegevens verschijnen automatisch op al je facturen.',
          bodyEn:
              'Fill in your business name, address, KVK, VAT number and IBAN. These appear automatically on all your invoices.',
          cardBelow: false,
        ),
        // 2 — Profile: logo
        _Step(
          tabIndex: 5,
          spot: _SpotDef.profileLogo,
          titleNl: 'Profiel — Logo',
          titleEn: 'Profile — Logo',
          bodyNl:
              'Upload je bedrijfslogo. Het wordt automatisch linksboven op elke factuur geplaatst.',
          bodyEn:
              'Upload your company logo. It appears automatically top-left on every invoice.',
          cardBelow: true,
        ),
        // 3 — Profile: historical import
        _Step(
          tabIndex: 5,
          spot: _SpotDef.profileImport,
          titleNl: 'Profiel — Historische import',
          titleEn: 'Profile — Historical import',
          bodyNl:
              'Heb je facturen of kosten van vóór BigDogg? Importeer ze als PDF. BigDogg leest ze uit met AI en voegt ze toe aan je administratie.',
          bodyEn:
              'Have invoices or expenses from before BigDogg? Import them as PDF. BigDogg reads them with AI and adds them to your records.',
          cardBelow: false,
        ),
        // 4 — Products FAB
        _Step(
          tabIndex: 2,
          spot: _SpotDef.singleFab,
          titleNl: 'Producten',
          titleEn: 'Products',
          bodyNl:
              'Voeg je diensten of producten toe met prijs en BTW-tarief. Zet ze daarna met één tik op elke factuur — geen handmatig invoeren meer.',
          bodyEn:
              'Add your services or products with price and VAT rate. Add them to any invoice with one tap — no more manual entry.',
          cardBelow: false,
        ),
        // 5 — Clients FABs
        _Step(
          tabIndex: 1,
          spot: _SpotDef.doubleFab,
          titleNl: 'Klanten',
          titleEn: 'Clients',
          bodyNl:
              'Voeg klanten handmatig toe (+ knop), of stuur een uitnodigingslink (deel-knop). De klant vult zelf zijn gegevens in — jij hoeft niets over te typen.',
          bodyEn:
              'Add clients manually (+ button), or send an invite link (share button). The client fills in their own details — no typing needed.',
          cardBelow: false,
        ),
        // 6 — Invoices double FAB
        _Step(
          tabIndex: 0,
          spot: _SpotDef.doubleFab,
          titleNl: 'Facturen — Aanmaken',
          titleEn: 'Invoices — Create',
          bodyNl:
              'Robot-knop: AI genereert de factuur vanuit een beschrijving in gewone taal. Plus-knop: bouw de factuur zelf stap voor stap op.',
          bodyEn:
              'Robot button: AI generates the invoice from a plain-language description. Plus button: build the invoice yourself step by step.',
          cardBelow: false,
        ),
        // 7 — Expenses FABs
        _Step(
          tabIndex: 3,
          spot: _SpotDef.doubleFab,
          titleNl: 'Kosten',
          titleEn: 'Expenses',
          bodyNl:
              'Voeg kosten toe via de camera (foto van bon), handmatig, of als afschrijving voor investeringen. BTW wordt automatisch berekend.',
          bodyEn:
              'Add expenses via camera (photo of receipt), manually, or as depreciation for investments. VAT is calculated automatically.',
          cardBelow: false,
        ),
        // 8 — Overview: quarterly/BTW
        _Step(
          tabIndex: 4,
          spot: _SpotDef.contentTop,
          titleNl: 'Overzicht — BTW aangifte',
          titleEn: 'Overview — VAT return',
          bodyNl:
              'Bekijk per kwartaal je omzet, kosten en te betalen BTW. Download de aangifte als PDF en dien hem in bij de Belastingdienst.',
          bodyEn:
              'See revenue, expenses and VAT due per quarter. Download the return as PDF and submit it to the Tax Authority.',
          cardBelow: true,
        ),
        // 9 — Overview: annual report
        _Step(
          tabIndex: 4,
          spot: _SpotDef.contentMid,
          titleNl: 'Overzicht — Jaarrapport',
          titleEn: 'Overview — Annual report',
          bodyNl:
              'Schakel naar "Dit jaar" voor een volledig jaaroverzicht. Download het jaarrapport als PDF — inclusief persoonlijke belastingtips van AI.',
          bodyEn:
              'Switch to "This year" for a full annual overview. Download the annual report as PDF — with personalised AI tax tips.',
          cardBelow: true,
        ),
        // 10 — Overview: hours
        _Step(
          tabIndex: 4,
          spot: _SpotDef.contentBottom,
          titleNl: 'Overzicht — Urenregistratie',
          titleEn: 'Overview — Hours tracker',
          bodyNl:
              'Registreer je gewerkte uren. BigDogg houdt bij of je het urencriterium van 1.225 uur haalt — belangrijk voor de zelfstandigenaftrek.',
          bodyEn:
              'Log your worked hours. BigDogg tracks whether you meet the 1,225-hour criterion — key for the self-employed tax deduction.',
          cardBelow: false,
        ),
        // 11 — Projects (conditional)
        if (projectsEnabled)
          _Step(
            tabIndex: 4,
            spot: _SpotDef.contentTop,
            titleNl: 'Projecten',
            titleEn: 'Projects',
            bodyNl:
                'Maak projecten aan en koppel facturen en kosten eraan. Zie per opdracht exact wat je hebt verdiend en uitgegeven.',
            bodyEn:
                'Create projects and link invoices and expenses to them. See exactly what each job earned and cost.',
            cardBelow: true,
            isProjectsTab: true,
          ),
        // 12 — Settings: Stripe
        _Step(
          tabIndex: -1, // resolved in _resolvedTab
          spot: _SpotDef.contentMid,
          titleNl: 'Instellingen — Stripe',
          titleEn: 'Settings — Stripe',
          bodyNl:
              'Koppel je Stripe account om betaallinks op facturen te zetten. Klanten betalen direct via iDEAL of creditcard. Handig voor betaling op locatie via QR-code.',
          bodyEn:
              'Connect Stripe to add payment links to invoices. Clients pay directly via iDEAL or credit card — great for on-the-spot payment via QR code.',
          cardBelow: true,
          isSettings: true,
        ),
      ];

  int _resolvedTab(_Step step) {
    if (step.isSettings) return widget.projectsEnabled ? 7 : 6;
    if (step.isProjectsTab) return 4;
    return step.tabIndex;
  }

  void _applyTab(_Step step) {
    final idx = _resolvedTab(step);
    if (widget.currentTabIndex != idx) widget.onTabChange(idx);
  }

  void _next() {
    final steps = _buildSteps(widget.projectsEnabled);
    if (_stepIndex < steps.length - 1) {
      setState(() => _stepIndex++);
      _applyTab(steps[_stepIndex]);
    } else {
      widget.onComplete();
    }
  }

  void _prev() {
    if (_stepIndex > 0) {
      final steps = _buildSteps(widget.projectsEnabled);
      setState(() => _stepIndex--);
      _applyTab(steps[_stepIndex]);
    }
  }

  // ── Spotlight rect calculation ────────────────────────────────────────────
  //
  // Key measurements (all from actual code):
  //   AppBar = kToolbarHeight (56) + statusBar + 1px border
  //   BottomNav = 70px
  //   FAB size = 56px (Material default)
  //   Robot FAB: bottom=88 right=16  →  top = h - navH - 88 - 56
  //   Plus FAB:  bottom=16 right=16  →  top = h - navH - 16 - 56
  //   Combined both: top of robot to bottom of plus
  //
  //   Profile logo card: first card in scrollview, starts at ~appBarH+16,
  //     approx 130px tall (padding 16 + title ~20 + subtitle ~16 + row 80 + bottom 16)
  //   Profile form section: right after logo card + 12px gap, ~200px tall
  //   Profile import: lower half of scrollview

  Rect _spotlight(_SpotDef def, Size sz, double appBarH, double navH) {
    final w = sz.width;
    final h = sz.height;
    const pad = 12.0;
    const fabSize = 56.0;
    const fabRight = 16.0;

    switch (def) {
      // Profile logo card — first card, fixed position at top of scrollview
      case _SpotDef.profileLogo:
        return Rect.fromLTWH(
          pad,
          appBarH + pad,
          w - pad * 2,
          132, // logo card height: 16+20+4+16+16+80px row+16 padding
        );

      // Profile business form — second card after logo
      case _SpotDef.profileForm:
        final logoCardH = 132.0;
        final gap = 12.0;
        return Rect.fromLTWH(
          pad,
          appBarH + pad + logoCardH + gap,
          w - pad * 2,
          220, // business details card: title + 4 fields + padding
        );

      // Profile import — bottom half, import sections
      case _SpotDef.profileImport:
        return Rect.fromLTWH(
          pad,
          appBarH + pad,
          w - pad * 2,
          150, // show the top (intro text + logo) to indicate "scroll down"
          // We actually want to indicate the import area so show a hint card
          // pointing down — easier to just show full content area top portion
          // and say "scroll down" in the copy
        );

      // Single FAB (+ only) — bottom right
      case _SpotDef.singleFab:
        final fabTop = h - navH - fabRight - fabSize;
        return Rect.fromLTWH(
          w - fabRight - fabSize - pad,
          fabTop - pad,
          fabSize + pad * 2,
          fabSize + pad * 2,
        );

      // Double FAB (robot + plus stacked) — exact from code: bottom 88 and 16
      case _SpotDef.doubleFab:
        final plusTop = h - navH - fabRight - fabSize;
        final robotTop = h - navH - 88 - fabSize;
        return Rect.fromLTWH(
          w - fabRight - fabSize - pad,
          robotTop - pad,
          fabSize + pad * 2,
          (plusTop + fabSize) - robotTop + pad * 2,
        );

      // Content zones for overview / settings
      case _SpotDef.contentTop:
        return Rect.fromLTWH(pad, appBarH + pad, w - pad * 2, (h - appBarH - navH) * 0.45);

      case _SpotDef.contentMid:
        final cH = h - appBarH - navH;
        return Rect.fromLTWH(pad, appBarH + cH * 0.25, w - pad * 2, cH * 0.42);

      case _SpotDef.contentBottom:
        final cH = h - appBarH - navH;
        return Rect.fromLTWH(pad, appBarH + cH * 0.50, w - pad * 2, cH * 0.42);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;

    final steps = _buildSteps(widget.projectsEnabled);
    final step = steps[_stepIndex];
    final sz = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;
    final appBarH = kToolbarHeight + topPad + 1;
    const navH = 70.0;

    final spot = _spotlight(step.spot, sz, appBarH, navH);

    return Stack(
      children: [
        widget.child,
        FadeTransition(
          opacity: _fade,
          child: _Overlay(
            spotlight: spot,
            step: step,
            isNl: widget.isNl,
            stepIndex: _stepIndex,
            total: steps.length,
            isFirst: _stepIndex == 0,
            isLast: _stepIndex == steps.length - 1,
            onNext: _next,
            onPrev: _prev,
            onSkip: widget.onComplete,
            sz: sz,
            appBarH: appBarH,
            navH: navH,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overlay widget
// ─────────────────────────────────────────────────────────────────────────────

class _Overlay extends StatelessWidget {
  final Rect spotlight;
  final _Step step;
  final bool isNl;
  final int stepIndex, total;
  final bool isFirst, isLast;
  final VoidCallback onNext, onPrev, onSkip;
  final Size sz;
  final double appBarH, navH;

  const _Overlay({
    required this.spotlight,
    required this.step,
    required this.isNl,
    required this.stepIndex,
    required this.total,
    required this.isFirst,
    required this.isLast,
    required this.onNext,
    required this.onPrev,
    required this.onSkip,
    required this.sz,
    required this.appBarH,
    required this.navH,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dark backdrop with cutout
        CustomPaint(
          size: sz,
          painter: _BackdropPainter(spot: spotlight),
        ),

        // Gold border glow around spotlight
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
                    color: BigDoggTheme.gold500.withOpacity(0.45),
                    blurRadius: 16,
                    spreadRadius: 2,
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
          child: _pill('${ stepIndex + 1} / $total'),
        ),

        // Skip
        Positioned(
          top: appBarH + 10,
          right: 16,
          child: GestureDetector(
            onTap: onSkip,
            child: _pill(isNl ? 'Overslaan' : 'Skip'),
          ),
        ),

        // Info card
        _card(),
      ],
    );
  }

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      );

  Widget _card() {
    const cardH = 170.0; // estimated card height
    const margin = 12.0;
    final cardW = sz.width - 32;

    // Place card below spotlight if there's room, otherwise above
    double top;
    if (step.cardBelow) {
      top = spotlight.bottom + margin;
    } else {
      top = spotlight.top - cardH - margin;
    }

    // Clamp to visible area (between appbar and nav)
    top = top.clamp(appBarH + 44.0, sz.height - navH - cardH - 4);

    return Positioned(
      left: 16,
      top: top,
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
                  color: Colors.black.withOpacity(0.45),
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
                      height: 1.5),
                ),
                const SizedBox(height: 14),
                Row(
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
                            width: active ? 14 : 5,
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
                    const SizedBox(width: 8),
                    if (!isFirst) ...[
                      _btn(isNl ? 'Vorige' : 'Prev', onPrev,
                          bg: Colors.white12, fg: Colors.white),
                      const SizedBox(width: 8),
                    ],
                    _btn(
                      isLast ? (isNl ? 'Klaar!' : 'Done!') : (isNl ? 'Volgende' : 'Next'),
                      onNext,
                      bg: BigDoggTheme.gold500,
                      fg: Colors.white,
                      bold: true,
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

  Widget _btn(String label, VoidCallback onTap,
      {required Color bg, required Color fg, bool bold = false}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Text(label,
              style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.normal)),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Backdrop painter
// ─────────────────────────────────────────────────────────────────────────────

class _BackdropPainter extends CustomPainter {
  final Rect spot;
  const _BackdropPainter({required this.spot});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.65);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(spot, const Radius.circular(14)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.spot != spot;
}

// ─────────────────────────────────────────────────────────────────────────────
// Data
// ─────────────────────────────────────────────────────────────────────────────

enum _SpotDef {
  profileLogo,
  profileForm,
  profileImport,
  singleFab,
  doubleFab,
  contentTop,
  contentMid,
  contentBottom,
}

class _Step {
  final int tabIndex;
  final _SpotDef spot;
  final String titleNl, titleEn, bodyNl, bodyEn;
  final bool cardBelow;
  final bool isProjectsTab;
  final bool isSettings;

  const _Step({
    required this.tabIndex,
    required this.spot,
    required this.titleNl,
    required this.titleEn,
    required this.bodyNl,
    required this.bodyEn,
    required this.cardBelow,
    this.isProjectsTab = false,
    this.isSettings = false,
  });
}