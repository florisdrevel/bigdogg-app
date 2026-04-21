import 'package:flutter/material.dart';
import '../theme.dart';

class WalkthroughScreen extends StatefulWidget {
  final bool isNl;
  final VoidCallback onComplete;

  const WalkthroughScreen({
    super.key,
    required this.isNl,
    required this.onComplete,
  });

  @override
  State<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends State<WalkthroughScreen>
    with SingleTickerProviderStateMixin {
  int _currentPage = 0;
  late final PageController _pageController;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  List<_WalkthroughStep> get _steps => [
        _WalkthroughStep(
          icon: Icons.waving_hand_rounded,
          iconColor: BigDoggTheme.gold500,
          titleNl: 'Welkom bij BigDogg!',
          titleEn: 'Welcome to BigDogg!',
          bodyNl:
              'Slim boekhouden voor ZZP\'ers. We laten je in een paar stappen zien hoe alles werkt. Je kunt deze rondleiding altijd opnieuw starten vanuit de instellingen.',
          bodyEn:
              'Smart accounting for freelancers. We\'ll walk you through the app in a few steps. You can always restart this tour from settings.',
          highlight: null,
        ),
        _WalkthroughStep(
          icon: Icons.receipt_long_outlined,
          iconColor: BigDoggTheme.teal700,
          titleNl: 'Facturen',
          titleEn: 'Invoices',
          bodyNl:
              'Maak professionele facturen in seconden. Gebruik de AI-assistent om facturen te genereren vanuit een beschrijving, of importeer historische facturen via PDF.',
          bodyEn:
              'Create professional invoices in seconds. Use the AI assistant to generate invoices from a description, or import historical invoices via PDF.',
          highlight: _HighlightTab.invoices,
          featureTagNl: 'AI-assistent inbegrepen',
          featureTagEn: 'AI assistant included',
        ),
        _WalkthroughStep(
          icon: Icons.account_balance_wallet_outlined,
          iconColor: BigDoggTheme.teal700,
          titleNl: 'Kosten',
          titleEn: 'Expenses',
          bodyNl:
              'Houd al je zakelijke uitgaven bij. Scan bonnetjes, voeg kosten handmatig toe of importeer meerdere uitgaven tegelijk. BTW wordt automatisch berekend.',
          bodyEn:
              'Track all your business expenses. Scan receipts, add costs manually, or bulk-import expenses. VAT is calculated automatically.',
          highlight: _HighlightTab.expenses,
          featureTagNl: 'BTW automatisch berekend',
          featureTagEn: 'VAT auto-calculated',
        ),
        _WalkthroughStep(
          icon: Icons.bar_chart_rounded,
          iconColor: BigDoggTheme.teal700,
          titleNl: 'Overzicht',
          titleEn: 'Overview',
          bodyNl:
              'Bekijk per kwartaal je omzet, kosten en te betalen BTW. Download je BTW-aangifte als PDF of genereer je volledige jaarrapport — inclusief AI-belastingtips.',
          bodyEn:
              'See your revenue, expenses and VAT per quarter. Download your VAT report as PDF or generate your full annual report — including AI tax tips.',
          highlight: _HighlightTab.overview,
          featureTagNl: 'Jaarrapport met AI-tips',
          featureTagEn: 'Annual report with AI tips',
        ),
        _WalkthroughStep(
          icon: Icons.people_outline_rounded,
          iconColor: BigDoggTheme.teal700,
          titleNl: 'Klanten',
          titleEn: 'Clients',
          bodyNl:
              'Beheer al je klanten op één plek. Stuur een uitnodigingslink waarmee klanten hun eigen gegevens invullen — jij hoeft niets handmatig over te typen.',
          bodyEn:
              'Manage all your clients in one place. Send an invite link so clients fill in their own details — no manual data entry for you.',
          highlight: _HighlightTab.clients,
          featureTagNl: 'Klant vult zelf in',
          featureTagEn: 'Client self-onboarding',
        ),
        _WalkthroughStep(
          icon: Icons.person_outline_rounded,
          iconColor: BigDoggTheme.teal700,
          titleNl: 'Profiel',
          titleEn: 'Profile',
          bodyNl:
              'Vul je bedrijfsgegevens in: naam, adres, KVK, BTW-nummer en IBAN. Upload je logo zodat het automatisch op al je facturen verschijnt.',
          bodyEn:
              'Fill in your business details: name, address, KVK, VAT number and IBAN. Upload your logo so it appears automatically on all your invoices.',
          highlight: _HighlightTab.profile,
          featureTagNl: 'Logo op facturen',
          featureTagEn: 'Logo on invoices',
        ),
        _WalkthroughStep(
          icon: Icons.rocket_launch_rounded,
          iconColor: BigDoggTheme.gold500,
          titleNl: 'Je bent er klaar voor!',
          titleEn: 'You\'re all set!',
          bodyNl:
              'BigDogg staat klaar. Begin met het aanmaken van je eerste factuur, of vul eerst je profiel in. Succes als ondernemer!',
          bodyEn:
              'BigDogg is ready for you. Start by creating your first invoice, or fill in your profile first. Good luck as a freelancer!',
          highlight: null,
        ),
      ];

  void _next() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onComplete();
    }
  }

  void _prev() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNl = widget.isNl;
    final steps = _steps;
    final isLast = _currentPage == steps.length - 1;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Scaffold(
        backgroundColor: BigDoggTheme.teal800,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(
                  children: [
                    const Text(
                      'BigDogg.',
                      style: TextStyle(
                        color: BigDoggTheme.gold500,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: widget.onComplete,
                      child: Text(
                        isNl ? 'Overslaan' : 'Skip',
                        style: const TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

              // Page indicator
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(steps.length, (i) {
                    final active = i == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 24 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active ? BigDoggTheme.gold500 : Colors.white24,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),

              // Page content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: steps.length,
                  itemBuilder: (_, i) => _StepPage(
                    step: steps[i],
                    isNl: isNl,
                  ),
                ),
              ),

              // Bottom nav mockup + buttons
              _BottomArea(
                step: steps[_currentPage],
                isNl: isNl,
                isLast: isLast,
                isFirst: _currentPage == 0,
                onNext: _next,
                onPrev: _prev,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step data ─────────────────────────────────────────────────────────────────

enum _HighlightTab { invoices, expenses, overview, clients, profile }

class _WalkthroughStep {
  final IconData icon;
  final Color iconColor;
  final String titleNl;
  final String titleEn;
  final String bodyNl;
  final String bodyEn;
  final _HighlightTab? highlight;
  final String? featureTagNl;
  final String? featureTagEn;

  const _WalkthroughStep({
    required this.icon,
    required this.iconColor,
    required this.titleNl,
    required this.titleEn,
    required this.bodyNl,
    required this.bodyEn,
    required this.highlight,
    this.featureTagNl,
    this.featureTagEn,
  });
}

// ── Step page ─────────────────────────────────────────────────────────────────

class _StepPage extends StatelessWidget {
  final _WalkthroughStep step;
  final bool isNl;

  const _StepPage({required this.step, required this.isNl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon circle
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12, width: 1.5),
            ),
            child: Icon(step.icon, size: 48, color: step.iconColor),
          ),
          const SizedBox(height: 32),

          // Title
          Text(
            isNl ? step.titleNl : step.titleEn,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              fontFamily: 'PlusJakartaSans',
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),

          // Body
          Text(
            isNl ? step.bodyNl : step.bodyEn,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 15,
              height: 1.6,
            ),
          ),

          // Feature tag
          if (step.featureTagNl != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: BigDoggTheme.gold500.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: BigDoggTheme.gold500.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, size: 14, color: BigDoggTheme.gold500),
                  const SizedBox(width: 6),
                  Text(
                    isNl ? step.featureTagNl! : step.featureTagEn!,
                    style: const TextStyle(
                      color: BigDoggTheme.gold500,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Bottom area with nav mockup ───────────────────────────────────────────────

class _BottomArea extends StatelessWidget {
  final _WalkthroughStep step;
  final bool isNl;
  final bool isLast;
  final bool isFirst;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const _BottomArea({
    required this.step,
    required this.isNl,
    required this.isLast,
    required this.isFirst,
    required this.onNext,
    required this.onPrev,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Nav mockup — only shown when highlighting a tab
        if (step.highlight != null) ...[
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.receipt_long_outlined,
                  label: isNl ? 'Facturen' : 'Invoices',
                  active: step.highlight == _HighlightTab.invoices,
                ),
                _NavItem(
                  icon: Icons.account_balance_wallet_outlined,
                  label: isNl ? 'Kosten' : 'Expenses',
                  active: step.highlight == _HighlightTab.expenses,
                ),
                _NavItem(
                  icon: Icons.bar_chart_rounded,
                  label: isNl ? 'Overzicht' : 'Overview',
                  active: step.highlight == _HighlightTab.overview,
                ),
                _NavItem(
                  icon: Icons.people_outline_rounded,
                  label: isNl ? 'Klanten' : 'Clients',
                  active: step.highlight == _HighlightTab.clients,
                ),
                _NavItem(
                  icon: Icons.person_outline_rounded,
                  label: isNl ? 'Profiel' : 'Profile',
                  active: step.highlight == _HighlightTab.profile,
                ),
              ],
            ),
          ),
          // Arrow pointing up at the active tab
          if (step.highlight != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Icon(
                Icons.keyboard_arrow_up_rounded,
                color: BigDoggTheme.gold500,
                size: 28,
              ),
            ),
        ],

        // Buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Row(
            children: [
              if (!isFirst)
                Expanded(
                  child: OutlinedButton(
                    onPressed: onPrev,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isNl ? 'Vorige' : 'Previous'),
                  ),
                ),
              if (!isFirst) const SizedBox(width: 12),
              Expanded(
                flex: isFirst ? 1 : 1,
                child: ElevatedButton(
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BigDoggTheme.gold500,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    isLast
                        ? (isNl ? 'Aan de slag!' : 'Let\'s go!')
                        : (isNl ? 'Volgende' : 'Next'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _NavItem({required this.icon, required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: active
          ? BoxDecoration(
              color: BigDoggTheme.gold500.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BigDoggTheme.gold500.withOpacity(0.6)),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 22,
            color: active ? BigDoggTheme.gold500 : Colors.white38,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: active ? BigDoggTheme.gold500 : Colors.white38,
              fontWeight: active ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}