import 'package:flutter/material.dart';
import '../services/overview_service.dart';
import '../app_theme.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _quarterly;
  Map<String, dynamic>? _annual;
  bool _loadingQuarterly = true;
  bool _loadingAnnual = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadQuarterly();
    _loadAnnual();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadQuarterly() async {
    setState(() => _loadingQuarterly = true);
    final result = await OverviewService.getQuarterlyOverview();
    setState(() {
      _loadingQuarterly = false;
      if (result['success']) _quarterly = result['overview'];
    });
  }

  Future<void> _loadAnnual() async {
    setState(() => _loadingAnnual = true);
    final result = await OverviewService.getAnnualOverview();
    setState(() {
      _loadingAnnual = false;
      if (result['success']) _annual = result['overview'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Column(
        children: [
          // Tab bar header
          Container(
            decoration: const BoxDecoration(
              gradient: AppGradients.navySubtle,
            ),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'This Quarter'),
                Tab(text: 'This Year'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildQuarterlyView(),
                _buildAnnualView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuarterlyView() {
    if (_loadingQuarterly) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_quarterly == null) {
      return const Center(child: Text('Failed to load overview'));
    }

    final q = _quarterly!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              gradient: AppGradients.navySubtle,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        q['period'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${q['start_date']} — ${q['end_date']}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const SectionHeader('Revenue'),
          _OverviewCard(children: [
            _OverviewRow('Omzet ex BTW', '€${q['revenue_ex_btw']}'),
            _OverviewRow('BTW ontvangen', '€${q['revenue_btw']}'),
            _OverviewRow(
              'Totaal incl BTW',
              '€${q['revenue_total']}',
              bold: true,
            ),
            const _Divider(),
            _OverviewRow(
              'Betaald ontvangen',
              '€${q['paid_revenue']}',
              color: AppColors.success,
            ),
            _OverviewRow(
              'Nog openstaand',
              '€${q['outstanding']}',
              color: AppColors.warning,
            ),
          ]),

          const SizedBox(height: 16),
          const SectionHeader('Expenses'),
          _OverviewCard(children: [
            _OverviewRow('Kosten ex BTW', '€${q['expenses_ex_btw']}'),
            _OverviewRow('BTW betaald', '€${q['expenses_btw']}'),
            _OverviewRow(
              'Totaal incl BTW',
              '€${q['expenses_total']}',
              bold: true,
            ),
          ]),

          const SizedBox(height: 16),
          const SectionHeader('BTW'),
          _OverviewCard(children: [
            _OverviewRow('BTW ontvangen', '€${q['revenue_btw']}'),
            _OverviewRow('BTW betaald op kosten', '€${q['expenses_btw']}'),
            const _Divider(),
            _OverviewRow(
              'Te betalen BTW',
              '€${q['btw_to_pay']}',
              bold: true,
              large: true,
              color: (q['btw_to_pay'] as num) > 0
                  ? AppColors.danger
                  : AppColors.success,
            ),
          ]),

          const SizedBox(height: 20),
          _InfoBanner(
            'Vergeet niet je BTW-aangifte in te dienen bij de Belastingdienst.',
          ),
        ],
      ),
    );
  }

  Widget _buildAnnualView() {
    if (_loadingAnnual) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_annual == null) {
      return const Center(child: Text('Failed to load overview'));
    }

    final a = _annual!;
    final quarters = a['quarters'] as List;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Year header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              gradient: AppGradients.navySubtle,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${a['year']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Text(
                        'Jaaroverzicht',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Netto winst',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    Text(
                      '€${a['net_profit_indicative']}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const SectionHeader('Per kwartaal'),
          ...quarters.map((q) => _QuarterCard(quarter: q)),

          const SizedBox(height: 16),
          SectionHeader('Totaal ${a['year']}'),
          _OverviewCard(children: [
            _OverviewRow(
              'Totale omzet ex BTW',
              '€${a['total_revenue_ex_btw']}',
              bold: true,
            ),
            _OverviewRow(
              'Totale kosten ex BTW',
              '€${a['total_expenses_ex_btw']}',
            ),
            const _Divider(),
            _OverviewRow(
              'Netto winst (indicatief)',
              '€${a['net_profit_indicative']}',
              bold: true,
              large: true,
            ),
            _OverviewRow(
              'Totale BTW te betalen',
              '€${a['total_btw_to_pay']}',
              color: AppColors.danger,
            ),
          ]),

          const SizedBox(height: 20),
          _InfoBanner(
            'Dit is een indicatief overzicht. Raadpleeg een belastingadviseur voor je definitieve aangifte.',
          ),
        ],
      ),
    );
  }
}

class _QuarterCard extends StatelessWidget {
  final Map quarter;
  const _QuarterCard({required this.quarter});

  @override
  Widget build(BuildContext context) {
    final q = quarter;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.navy.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Q${q['quarter']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _MiniStat('Omzet', '€${q['revenue_ex_btw']}')),
              Expanded(child: _MiniStat('Kosten', '€${q['expenses_ex_btw']}')),
              Expanded(child: _MiniStat('BTW', '€${q['btw_to_pay']}')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final List<Widget> children;
  const _OverviewCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card,
      child: Column(children: children),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final bool large;
  final Color? color;

  const _OverviewRow(
    this.label,
    this.value, {
    this.bold = false,
    this.large = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: large ? 15 : 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              fontSize: large ? 15 : 13,
              color: color ?? AppColors.textPrimary,
              letterSpacing: bold ? -0.2 : 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Divider(height: 1),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  const _InfoBanner(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            color: AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
