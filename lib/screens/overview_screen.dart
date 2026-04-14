import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/overview_service.dart';
import '../services/invoices_service.dart';
import '../services/api_config.dart';
import '../providers/app_provider.dart';
import '../theme.dart';

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
  int _selectedYear = DateTime.now().year;

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
    final result = await OverviewService.getAnnualOverview(year: _selectedYear);
    setState(() {
      _loadingAnnual = false;
      if (result['success']) _annual = result['overview'];
    });
  }

  Future<void> _downloadBtwReport(bool isNl, {int? quarter, int? year}) async {
    final token = await InvoicesService.getToken();
    final lang = isNl ? 'nl' : 'en';
    String url = '${ApiConfig.baseUrl}/api/v1/reports/btw/pdf?token=$token&lang=$lang';
    if (quarter != null && year != null) {
      url += '&quarter=$quarter&year=$year';
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNl ? 'Kan rapport niet openen' : 'Could not open report'),
            backgroundColor: BigDoggTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _downloadAnnualReport(bool isNl, int year) async {
    // Check access FIRST — never launch the URL until we know the user is allowed
    final checkResult = await OverviewService.checkAnnualReportAccess(year: year);
    if (checkResult == 'paid_tier_required') {
      if (mounted) _showPaywallDialog(isNl);
      return;
    }

    final token = await InvoicesService.getToken();
    final lang = isNl ? 'nl' : 'en';
    final url =
        '${ApiConfig.baseUrl}/api/v1/reports/annual/pdf?token=$token&year=$year&lang=$lang';
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNl ? 'Kan rapport niet openen' : 'Could not open report'),
            backgroundColor: BigDoggTheme.error,
          ),
        );
      }
    }
  }

  void _showPaywallDialog(bool isNl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Lock icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: BigDoggTheme.teal800.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 36,
                color: BigDoggTheme.teal800,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isNl ? 'Betaald abonnement vereist' : 'Paid plan required',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: BigDoggTheme.teal800,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isNl
                  ? 'Het jaarrapport is alleen beschikbaar voor gebruikers met een betaald abonnement. Upgrade je account om toegang te krijgen tot alle rapporten en functies.'
                  : 'The annual report is only available for users on a paid plan. Upgrade your account to unlock all reports and features.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            // Feature list
            _paywallFeatureRow(
              Icons.analytics_outlined,
              isNl ? 'Jaarlijkse financiële rapporten' : 'Annual financial reports',
            ),
            _paywallFeatureRow(
              Icons.upload_file_outlined,
              isNl ? 'Facturen & kosten importeren' : 'Import invoices & expenses',
            ),
            _paywallFeatureRow(
              Icons.picture_as_pdf_outlined,
              isNl ? 'PDF exports voor alle kwartalen' : 'PDF exports for all quarters',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: Navigate to subscription/upgrade screen
                  // Navigator.pushNamed(context, '/upgrade');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: BigDoggTheme.gold500,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isNl ? 'Upgraden naar betaald' : 'Upgrade to paid',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                isNl ? 'Niet nu' : 'Not now',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paywallFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: BigDoggTheme.teal800.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: BigDoggTheme.teal800),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(fontSize: 14, color: BigDoggTheme.lightTextPrimary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNl = context.watch<AppProvider>().language == 'nl';

    return Column(
      children: [
        Container(
          color: BigDoggTheme.teal800,
          child: TabBar(
            controller: _tabController,
            indicatorColor: BigDoggTheme.gold500,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: BigDoggTheme.teal400,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'PlusJakartaSans'),
            tabs: [
              Tab(text: isNl ? 'Dit kwartaal' : 'This Quarter'),
              Tab(text: isNl ? 'Dit jaar' : 'This Year'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildQuarterlyView(isNl),
              _buildAnnualView(isNl),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuarterlyView(bool isNl) {
    if (_loadingQuarterly) return const Center(child: CircularProgressIndicator());
    if (_quarterly == null) return Center(child: Text(isNl ? 'Laden mislukt' : 'Failed to load'));

    final q = _quarterly!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BigDoggTheme.teal800,
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
          _sectionTitle(isNl ? 'Omzet' : 'Revenue'),
          _overviewCard([
            _overviewRow(isNl ? 'Omzet ex BTW' : 'Revenue ex VAT', '€${q['revenue_ex_btw']}'),
            _overviewRow(isNl ? 'BTW ontvangen' : 'VAT received', '€${q['revenue_btw']}'),
            _overviewRow(isNl ? 'Totaal incl BTW' : 'Total incl VAT', '€${q['revenue_total']}', bold: true),
            const Divider(),
            _overviewRow(isNl ? 'Betaald ontvangen' : 'Received', '€${q['paid_revenue']}', color: BigDoggTheme.success),
            _overviewRow(isNl ? 'Nog openstaand' : 'Outstanding', '€${q['outstanding']}', color: BigDoggTheme.warning),
          ]),
          const SizedBox(height: 16),
          _sectionTitle(isNl ? 'Kosten' : 'Expenses'),
          _overviewCard([
            _overviewRow(isNl ? 'Kosten ex BTW' : 'Expenses ex VAT', '€${q['expenses_ex_btw']}'),
            _overviewRow(isNl ? 'BTW betaald' : 'VAT paid', '€${q['expenses_btw']}'),
            _overviewRow(isNl ? 'Totaal incl BTW' : 'Total incl VAT', '€${q['expenses_total']}', bold: true),
          ]),
          const SizedBox(height: 16),
          _sectionTitle('BTW / VAT'),
          _overviewCard([
            _overviewRow(isNl ? 'BTW ontvangen' : 'VAT received', '€${q['revenue_btw']}'),
            _overviewRow(isNl ? 'BTW betaald op kosten' : 'VAT paid on expenses', '€${q['expenses_btw']}'),
            const Divider(),
            _overviewRow(
              isNl ? 'Te betalen BTW' : 'VAT to pay',
              '€${q['btw_to_pay']}',
              bold: true,
              large: true,
              color: (q['btw_to_pay'] as num) > 0 ? BigDoggTheme.error : BigDoggTheme.success,
            ),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _downloadBtwReport(isNl),
              icon: const Icon(Icons.download_outlined, color: Colors.white),
              label: Text(
                isNl ? 'Download BTW Aangifte PDF' : 'Download VAT Report PDF',
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: BigDoggTheme.teal800,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BigDoggTheme.warningBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BigDoggTheme.warning.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: BigDoggTheme.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isNl
                        ? 'Vergeet niet je BTW-aangifte in te dienen bij de Belastingdienst.'
                        : 'Don\'t forget to submit your VAT return to the Tax Authority.',
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

  Widget _buildAnnualView(bool isNl) {
    if (_loadingAnnual) return const Center(child: CircularProgressIndicator());
    if (_annual == null) return Center(child: Text(isNl ? 'Laden mislukt' : 'Failed to load'));

    final a = _annual!;
    final quarters = a['quarters'] as List;
    final currentYear = DateTime.now().year;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BigDoggTheme.teal800,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${a['year']}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                      Text(isNl ? 'Jaaroverzicht' : 'Annual overview',
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                      onPressed: () {
                        setState(() => _selectedYear--);
                        _loadAnnual();
                      },
                    ),
                    Text('$_selectedYear',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    IconButton(
                      icon: Icon(Icons.chevron_right,
                          color: _selectedYear < currentYear ? Colors.white : Colors.white30),
                      onPressed: _selectedYear < currentYear
                          ? () {
                              setState(() => _selectedYear++);
                              _loadAnnual();
                            }
                          : null,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(isNl ? 'Netto winst' : 'Net profit',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('€${a['net_profit_indicative']}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle(isNl ? 'Per kwartaal' : 'Per quarter'),
          ...quarters.map((q) => _quarterCard(q, isNl, _selectedYear)),
          const SizedBox(height: 16),
          _sectionTitle(isNl ? 'Totaal $_selectedYear' : 'Total $_selectedYear'),
          _overviewCard([
            _overviewRow(isNl ? 'Totale omzet ex BTW' : 'Total revenue ex VAT',
                '€${a['total_revenue_ex_btw']}', bold: true),
            _overviewRow(isNl ? 'Totale kosten ex BTW' : 'Total expenses ex VAT',
                '€${a['total_expenses_ex_btw']}'),
            const Divider(),
            _overviewRow(isNl ? 'Netto winst (indicatief)' : 'Net profit (indicative)',
                '€${a['net_profit_indicative']}', bold: true, large: true),
            _overviewRow(isNl ? 'Totale BTW te betalen' : 'Total VAT to pay',
                '€${a['total_btw_to_pay']}', color: BigDoggTheme.error),
          ]),
          const SizedBox(height: 16),

          // Annual report download button — shows paywall for trial users
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _downloadAnnualReport(isNl, _selectedYear),
              icon: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 20),
              label: Text(
                isNl
                    ? 'Download Jaarrapport $_selectedYear'
                    : 'Download Annual Report $_selectedYear',
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: BigDoggTheme.gold500,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Subtle hint that this is a paid feature
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.workspace_premium_outlined, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                isNl ? 'Alleen beschikbaar voor betaalde gebruikers' : 'Available on paid plan only',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BigDoggTheme.warningBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BigDoggTheme.warning.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: BigDoggTheme.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isNl
                        ? 'Dit is een indicatief overzicht. Raadpleeg een belastingadviseur voor je definitieve aangifte.'
                        : 'This is an indicative overview. Consult a tax advisor for your final return.',
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

  Widget _quarterCard(Map q, bool isNl, int year) {
    final quarterNum = q['quarter'] as int;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Q$quarterNum $year',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: BigDoggTheme.teal800)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _downloadBtwReport(isNl, quarter: quarterNum, year: year),
                icon: const Icon(Icons.download_outlined, size: 16, color: BigDoggTheme.teal700),
                label: Text(
                  isNl ? 'BTW PDF' : 'VAT PDF',
                  style: const TextStyle(fontSize: 12, color: BigDoggTheme.teal700),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _miniStat(isNl ? 'Omzet' : 'Revenue', '€${q['revenue_ex_btw']}')),
              Expanded(child: _miniStat(isNl ? 'Kosten' : 'Expenses', '€${q['expenses_ex_btw']}')),
              Expanded(child: _miniStat('BTW / VAT', '€${q['btw_to_pay']}')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: BigDoggTheme.lightTextSecondary)),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: BigDoggTheme.teal800)),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: BigDoggTheme.lightTextPrimary)),
    );
  }

  Widget _overviewCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(children: children),
    );
  }

  Widget _overviewRow(String label, String value,
      {bool bold = false, bool large = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: BigDoggTheme.lightTextSecondary,
                  fontSize: large ? 15 : 14)),
          Text(value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                fontSize: large ? 15 : 14,
                color: color ?? BigDoggTheme.lightTextPrimary,
              )),
        ],
      ),
    );
  }
}