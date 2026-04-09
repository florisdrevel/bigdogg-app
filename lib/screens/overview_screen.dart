import 'package:flutter/material.dart';
import '../services/overview_service.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> with SingleTickerProviderStateMixin {
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Overview', style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'This Quarter'),
            Tab(text: 'This Year'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQuarterlyView(),
          _buildAnnualView(),
        ],
      ),
    );
  }

  Widget _buildQuarterlyView() {
    if (_loadingQuarterly) return const Center(child: CircularProgressIndicator());
    if (_quarterly == null) return const Center(child: Text('Failed to load overview'));

    final q = _quarterly!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q['period'], style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                Text('${q['start_date']} — ${q['end_date']}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('📤 Revenue'),
          _overviewCard([
            _overviewRow('Omzet ex BTW', '€${q['revenue_ex_btw']}'),
            _overviewRow('BTW ontvangen', '€${q['revenue_btw']}'),
            _overviewRow('Totaal incl BTW', '€${q['revenue_total']}', bold: true),
            const Divider(),
            _overviewRow('Betaald ontvangen', '€${q['paid_revenue']}', color: const Color(0xFF059669)),
            _overviewRow('Nog openstaand', '€${q['outstanding']}', color: const Color(0xFFF59E0B)),
          ]),
          const SizedBox(height: 16),
          _sectionTitle('📥 Expenses'),
          _overviewCard([
            _overviewRow('Kosten ex BTW', '€${q['expenses_ex_btw']}'),
            _overviewRow('BTW betaald', '€${q['expenses_btw']}'),
            _overviewRow('Totaal incl BTW', '€${q['expenses_total']}', bold: true),
          ]),
          const SizedBox(height: 16),
          _sectionTitle('🏦 BTW'),
          _overviewCard([
            _overviewRow('BTW ontvangen', '€${q['revenue_btw']}'),
            _overviewRow('BTW betaald op kosten', '€${q['expenses_btw']}'),
            const Divider(),
            _overviewRow('Te betalen BTW', '€${q['btw_to_pay']}',
                bold: true, large: true,
                color: (q['btw_to_pay'] as num) > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669)),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFF59E0B)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Vergeet niet je BTW-aangifte in te dienen bij de Belastingdienst.',
                    style: const TextStyle(color: Color(0xFF92400E), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnualView() {
    if (_loadingAnnual) return const Center(child: CircularProgressIndicator());
    if (_annual == null) return const Center(child: Text('Failed to load overview'));

    final a = _annual!;
    final quarters = a['quarters'] as List;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${a['year']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                      const Text('Jaaroverzicht', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Netto winst (indicatief)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('€${a['net_profit_indicative']}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('Per kwartaal'),
          ...quarters.map((q) => _quarterCard(q)),
          const SizedBox(height: 16),
          _sectionTitle('Totaal ${a['year']}'),
          _overviewCard([
            _overviewRow('Totale omzet ex BTW', '€${a['total_revenue_ex_btw']}', bold: true),
            _overviewRow('Totale kosten ex BTW', '€${a['total_expenses_ex_btw']}'),
            const Divider(),
            _overviewRow('Netto winst (indicatief)', '€${a['net_profit_indicative']}', bold: true, large: true),
            _overviewRow('Totale BTW te betalen', '€${a['total_btw_to_pay']}', color: const Color(0xFFDC2626)),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFF59E0B)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Dit is een indicatief overzicht. Raadpleeg een belastingadviseur voor je definitieve aangifte.',
                    style: TextStyle(color: Color(0xFF92400E), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quarterCard(Map q) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Q${q['quarter']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _miniStat('Omzet', '€${q['revenue_ex_btw']}')),
                Expanded(child: _miniStat('Kosten', '€${q['expenses_ex_btw']}')),
                Expanded(child: _miniStat('BTW', '€${q['btw_to_pay']}')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _overviewCard(List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _overviewRow(String label, String value, {bool bold = false, bool large = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            color: const Color(0xFF6B7280),
            fontSize: large ? 15 : 14,
          )),
          Text(value, style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontSize: large ? 15 : 14,
            color: color,
          )),
        ],
      ),
    );
  }
}