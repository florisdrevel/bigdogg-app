import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/accountants_service.dart';
import '../theme.dart';

/// Token-gated read-only accountant portal at `/accountant/portal/:token`.
/// No login required. Five tabs: Overview / Invoices / Expenses /
/// Investments / Hours. Language toggle NL/EN persisted in prefs.
class AccountantPortalScreen extends StatefulWidget {
  final String token;
  const AccountantPortalScreen({super.key, required this.token});

  @override
  State<AccountantPortalScreen> createState() =>
      _AccountantPortalScreenState();
}

class _AccountantPortalScreenState extends State<AccountantPortalScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _bootstrapping = true;
  bool _yearLoading = false;
  bool _valid = false;
  String? _error;
  bool _isNl = true;

  Map<String, dynamic> _meta = {};
  List<int> _years = [];
  int _year = DateTime.now().year;
  int _btwQuarter = 1;

  Map<String, dynamic>? _overview;
  Map<String, dynamic>? _btwBreakdown;
  Map<String, dynamic>? _aging;
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _expenses = [];
  Map<String, dynamic>? _investments;
  Map<String, dynamic>? _hours;
  final Set<String> _expandedInvoices = {};
  final Set<String> _expandedInvestments = {};

  String t(String nl, String en) => _isNl ? nl : en;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _bootstrap();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _isNl = (prefs.getString('accountant_portal_lang') ?? 'nl') == 'nl';

    final metaResult = await AccountantsService.portalMeta(widget.token);
    if (!mounted) return;
    if (metaResult['ok'] != true) {
      setState(() {
        _bootstrapping = false;
        _valid = false;
        _error = metaResult['error']?.toString() ?? 'lookup_failed';
      });
      return;
    }
    _meta = (metaResult['meta'] as Map?)?.cast<String, dynamic>() ?? {};
    _years = await AccountantsService.portalYears(widget.token);
    if (!mounted) return;
    if (_years.isNotEmpty) _year = _years.first;
    final currentMonth = DateTime.now().month;
    _btwQuarter = ((currentMonth - 1) ~/ 3) + 1;
    await _loadYear(_year);
    if (!mounted) return;
    setState(() {
      _valid = true;
      _bootstrapping = false;
    });
  }

  Future<void> _loadYear(int year) async {
    setState(() => _yearLoading = true);
    final results = await Future.wait([
      AccountantsService.portalOverview(widget.token, year),
      AccountantsService.portalInvoices(widget.token, year),
      AccountantsService.portalExpenses(widget.token, year),
      AccountantsService.portalInvestments(widget.token, year),
      AccountantsService.portalHours(widget.token, year),
      AccountantsService.portalBtwBreakdown(widget.token, year),
      AccountantsService.portalAging(widget.token),
    ]);
    if (!mounted) return;
    setState(() {
      _overview     = results[0] as Map<String, dynamic>?;
      _invoices     = results[1] as List<Map<String, dynamic>>;
      _expenses     = results[2] as List<Map<String, dynamic>>;
      _investments  = results[3] as Map<String, dynamic>?;
      _hours        = results[4] as Map<String, dynamic>?;
      _btwBreakdown = results[5] as Map<String, dynamic>?;
      _aging        = results[6] as Map<String, dynamic>?;
      _expandedInvoices.clear();
      _expandedInvestments.clear();
      _yearLoading = false;
    });
  }

  Future<void> _toggleLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final next = !_isNl;
    await prefs.setString('accountant_portal_lang', next ? 'nl' : 'en');
    if (!mounted) return;
    setState(() => _isNl = next);
  }

  String _humanizeError(String code) {
    switch (code) {
      case 'link_not_found':
      case 'not_found':
        return t('Deze toegangslink bestaat niet (meer).',
            'This access link no longer exists.');
      case 'link_expired':
      case 'expired':
        return t('Deze link is verlopen — vraag de eigenaar om een nieuwe.',
            'This link has expired — ask the owner for a new one.');
      case 'link_revoked':
      case 'revoked':
      case 'already_used':
        return t('De eigenaar heeft deze toegang ingetrokken.',
            'The owner has revoked this access.');
      default:
        return t('Er ging iets mis: $code', 'Something went wrong: $code');
    }
  }

  String _euros(dynamic v) {
    final n = v is num
        ? v.toDouble()
        : double.tryParse(v?.toString() ?? '') ?? 0.0;
    final sign = n < 0 ? '-' : '';
    final abs = n.abs();
    final whole = abs.truncate();
    final cents =
        ((abs - whole) * 100).round().toString().padLeft(2, '0');
    final wholeStr = whole.toString();
    final groups = <String>[];
    for (var i = wholeStr.length; i > 0; i -= 3) {
      groups.insert(0, wholeStr.substring(i - 3 < 0 ? 0 : i - 3, i));
    }
    return '$sign€ ${groups.join('.')},$cents';
  }

  int _daysUntilExpiry() {
    final expRaw = _meta['expires_at']?.toString();
    if (expRaw == null || expRaw.isEmpty) return -1;
    try {
      final exp = DateTime.parse(expRaw);
      return exp.difference(DateTime.now()).inDays;
    } catch (_) {
      return -1;
    }
  }

  String _expiryLabel() {
    final d = _daysUntilExpiry();
    if (d < 0) return t('Toegang verlopen', 'Access expired');
    if (d == 0) return t('Toegang vervalt vandaag', 'Access expires today');
    if (d == 1) return t('Toegang vervalt morgen', 'Access expires tomorrow');
    return t('Toegang vervalt over $d dagen',
        'Access expires in $d days');
  }

  Future<void> _downloadInvoicePdf(String invoiceId, String invoiceNumber) async {
    final url = AccountantsService.portalInvoicePdfUrl(
        widget.token, invoiceId);
    try {
      await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: url));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: BigDoggTheme.error,
        duration: const Duration(seconds: 6),
        content: Text(t(
            'Kon PDF $invoiceNumber niet openen — link gekopieerd.',
            'Could not open PDF $invoiceNumber — link copied.')),
      ));
    }
  }

  Future<void> _openReceipt(String url) async {
    try {
      await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: url));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 4),
        content: Text(t('Kon bonnetje niet openen — link gekopieerd.',
            'Could not open receipt — link copied.')),
      ));
    }
  }

  Future<void> _exportCsv() async {
    final url = AccountantsService.portalCsvExportUrl(widget.token, _year);
    try {
      await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: url));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 4),
        content: Text(t('Kon export niet openen — link gekopieerd.',
            'Could not open export — link copied.')),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapping) {
      return const Scaffold(
        backgroundColor: BigDoggTheme.lightBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_valid) return _invalidScreen();

    final daysLeft = _daysUntilExpiry();
    final warnExpiry = daysLeft >= 0 && daysLeft <= 5;

    return Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            _summaryBar(),
            if (warnExpiry || daysLeft < 0) _expiryBanner(daysLeft < 0),
            _tabBar(),
            if (_yearLoading)
              const LinearProgressIndicator(
                  minHeight: 2, color: BigDoggTheme.gold500),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _overviewTab(),
                  _invoicesTab(),
                  _expensesTab(),
                  _investmentsTab(),
                  _hoursTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header & shared chrome ───────────────────────────────
  Widget _header() {
    final ownerName =
        (_meta['owner_name'] ?? '').toString().trim().isEmpty
            ? t('BigDogg-gebruiker', 'BigDogg user')
            : (_meta['owner_name']).toString();
    final kvk = (_meta['kvk_number'] ?? '').toString();
    final btw = (_meta['btw_number'] ?? '').toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
      decoration: const BoxDecoration(color: BigDoggTheme.teal800),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                t('BigDogg · Accountantsportaal',
                    'BigDogg · Accountant Portal'),
                style: const TextStyle(
                  color: Color(0xFFC9A96E),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            _langToggle(),
            const SizedBox(width: 6),
            _exportButton(),
          ]),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  ownerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _yearDropdown(),
            ],
          ),
          if (kvk.isNotEmpty || btw.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              children: [
                if (kvk.isNotEmpty)
                  Text('KvK $kvk',
                      style: const TextStyle(
                          color: Color(0xFFE2DDD6),
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                if (btw.isNotEmpty)
                  Text('BTW $btw',
                      style: const TextStyle(
                          color: Color(0xFFE2DDD6),
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _langToggle() {
    return GestureDetector(
      onTap: _toggleLanguage,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFC9A96E).withOpacity(0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFC9A96E).withOpacity(0.5)),
        ),
        child: Text(
          _isNl ? 'EN' : 'NL',
          style: const TextStyle(
            color: Color(0xFFC9A96E),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _exportButton() {
    return GestureDetector(
      onTap: _exportCsv,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFC9A96E).withOpacity(0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFC9A96E).withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.download, size: 12, color: Color(0xFFC9A96E)),
            const SizedBox(width: 4),
            Text(
              t('CSV', 'CSV'),
              style: const TextStyle(
                color: Color(0xFFC9A96E),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _yearDropdown() {
    final years = _years.isEmpty ? [_year] : _years;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFC9A96E).withOpacity(0.5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: years.contains(_year) ? _year : years.first,
          icon: const Icon(Icons.expand_more,
              color: Color(0xFFC9A96E), size: 18),
          dropdownColor: BigDoggTheme.teal800,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600),
          items: years
              .map((y) => DropdownMenuItem(
                    value: y,
                    child: Text('$y',
                        style: const TextStyle(color: Colors.white)),
                  ))
              .toList(),
          onChanged: (y) {
            if (y == null || y == _year) return;
            setState(() => _year = y);
            _loadYear(y);
          },
        ),
      ),
    );
  }

  Widget _summaryBar() {
    final o = _overview ?? {};
    final korRatio = (o['kor_ratio'] is num)
        ? (o['kor_ratio'] as num).toDouble()
        : 0.0;
    final korPct = (korRatio * 100).clamp(0, 100).toStringAsFixed(0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: BigDoggTheme.lightSurface,
        border: Border(
            bottom: BorderSide(color: BigDoggTheme.lightBorder)),
      ),
      child: Row(
        children: [
          Expanded(
              child: _summaryCell(
                  t('Omzet', 'Revenue'),
                  _euros(o['revenue_ex']),
                  BigDoggTheme.success)),
          _vSep(),
          Expanded(
              child: _summaryCell(
                  t('Winst', 'Profit'),
                  _euros(o['profit_ex']),
                  BigDoggTheme.teal800)),
          _vSep(),
          Expanded(
              child: _summaryCell(
                  t('BTW te betalen', 'VAT payable'),
                  _euros(o['btw_payable']),
                  BigDoggTheme.gold600)),
          _vSep(),
          Expanded(
              child: _summaryCell(
                  t('KOR', 'KOR'),
                  '$korPct%',
                  BigDoggTheme.teal700)),
        ],
      ),
    );
  }

  Widget _vSep() => Container(
        width: 1,
        height: 24,
        color: BigDoggTheme.lightBorder,
      );

  Widget _summaryCell(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: BigDoggTheme.lightTextSecondary)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }

  Widget _expiryBanner(bool expired) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: expired
            ? BigDoggTheme.error.withOpacity(0.14)
            : const Color(0xFFFEF3C7),
        border: Border(
          bottom: BorderSide(
              color: expired
                  ? BigDoggTheme.error.withOpacity(0.5)
                  : const Color(0xFFD97706),
              width: 1),
        ),
      ),
      child: Row(children: [
        Icon(
          expired ? Icons.error_outline : Icons.warning_amber_rounded,
          size: 16,
          color: expired
              ? BigDoggTheme.error
              : const Color(0xFFD97706),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _expiryLabel(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: expired
                  ? BigDoggTheme.error
                  : const Color(0xFF92400E),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _tabBar() {
    return Container(
      color: BigDoggTheme.lightSurface,
      child: TabBar(
        controller: _tabs,
        isScrollable: true,
        labelColor: BigDoggTheme.teal800,
        unselectedLabelColor: BigDoggTheme.lightTextSecondary,
        indicatorColor: BigDoggTheme.gold500,
        labelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: [
          Tab(text: t('Overzicht', 'Overview')),
          Tab(text: t('Facturen', 'Invoices')),
          Tab(text: t('Kosten', 'Expenses')),
          Tab(text: t('Investeringen', 'Investments')),
          Tab(text: t('Uren', 'Hours')),
        ],
      ),
    );
  }

  // ── Tab 1: Overview ──────────────────────────────────────
  Widget _overviewTab() {
    final o = _overview ?? {};
    final hasData = (o['invoice_count'] ?? 0) > 0 ||
        (o['expense_count'] ?? 0) > 0;
    return RefreshIndicator(
      onRefresh: () => _loadYear(_year),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!hasData)
            _emptyHint(
                t('Geen facturen of kosten geboekt in $_year.',
                    'No invoices or expenses recorded in $_year.'),
                Icons.inbox_outlined)
          else ...[
            _kpiGrid(o),
            const SizedBox(height: 16),
            _korMeter(o),
            const SizedBox(height: 16),
            _sectionTitle(t('Per kwartaal', 'Per quarter')),
            _quartersTable(o),
            const SizedBox(height: 16),
            _sectionTitle(t('BTW aangifte', 'VAT return')),
            _btwAangifteCard(),
            const SizedBox(height: 16),
            _sectionTitle(t('Kosten per categorie', 'Expenses by category')),
            _categoriesList(o),
            const SizedBox(height: 16),
            _countsStrip(o),
          ],
        ],
      ),
    );
  }

  Widget _kpiGrid(Map<String, dynamic> o) {
    final tiles = [
      _KpiData(t('Omzet (excl. BTW)', 'Revenue (excl. VAT)'),
          _euros(o['revenue_ex']),
          BigDoggTheme.success, Icons.trending_up),
      _KpiData(t('Kosten (excl. BTW)', 'Expenses (excl. VAT)'),
          _euros(o['expense_ex']),
          BigDoggTheme.error, Icons.trending_down),
      _KpiData(t('Winst (excl. BTW)', 'Profit (excl. VAT)'),
          _euros(o['profit_ex']),
          BigDoggTheme.teal800, Icons.account_balance_wallet_outlined),
      _KpiData(t('BTW af te dragen', 'VAT payable'),
          _euros(o['btw_payable']),
          BigDoggTheme.gold600, Icons.balance),
      _KpiData(t('BTW geïnd', 'VAT collected'),
          _euros(o['btw_collected']),
          BigDoggTheme.teal700, Icons.arrow_downward),
      _KpiData(t('BTW betaald', 'VAT paid'),
          _euros(o['btw_paid']),
          BigDoggTheme.teal700, Icons.arrow_upward),
    ];
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: tiles
          .map((tile) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BigDoggTheme.lightSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: BigDoggTheme.lightBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(children: [
                      Icon(tile.icon, size: 14, color: tile.color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(tile.label,
                            style: const TextStyle(
                                fontSize: 11,
                                color: BigDoggTheme.lightTextSecondary,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(tile.value,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: tile.color)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _korMeter(Map<String, dynamic> o) {
    final ratio = (o['kor_ratio'] is num)
        ? (o['kor_ratio'] as num).toDouble()
        : 0.0;
    final revenue = (o['revenue_ex'] is num)
        ? (o['revenue_ex'] as num).toDouble()
        : 0.0;
    final threshold = (o['kor_threshold'] is num)
        ? (o['kor_threshold'] as num).toDouble()
        : 20000.0;
    final pct = (ratio * 100).clamp(0, 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.shield_outlined,
                size: 16, color: BigDoggTheme.teal700),
            const SizedBox(width: 6),
            Expanded(
              child: Text(t('KOR-drempel', 'KOR threshold'),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: BigDoggTheme.lightTextSecondary)),
            ),
            Text('$pct%',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: BigDoggTheme.teal700)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: ratio,
              backgroundColor: BigDoggTheme.lightBorder,
              valueColor: const AlwaysStoppedAnimation(
                  BigDoggTheme.gold500),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_euros(revenue)} ${t('van', 'of')} ${_euros(threshold)}',
            style: const TextStyle(
                fontSize: 11,
                color: BigDoggTheme.lightTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _quartersTable(Map<String, dynamic> o) {
    final qs = (o['quarters'] as List?) ?? [];
    final totalRev = qs.fold<double>(
        0.0,
        (sum, q) =>
            sum + ((q as Map)['revenue_ex'] as num? ?? 0).toDouble());
    final totalBtwIn = qs.fold<double>(
        0.0,
        (sum, q) =>
            sum + ((q as Map)['btw_collected'] as num? ?? 0).toDouble());
    final totalBtwOut = qs.fold<double>(
        0.0,
        (sum, q) =>
            sum + ((q as Map)['btw_paid'] as num? ?? 0).toDouble());
    final totalPayable = qs.fold<double>(
        0.0,
        (sum, q) =>
            sum + ((q as Map)['btw_payable'] as num? ?? 0).toDouble());

    return Container(
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: BigDoggTheme.lightBg,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(children: [
              _QCell(t('Kw.', 'Q'), flex: 1),
              _QCell(t('Omzet', 'Revenue'),
                  flex: 3, align: TextAlign.right),
              _QCell(t('BTW in', 'VAT in'),
                  flex: 2, align: TextAlign.right),
              _QCell(t('BTW uit', 'VAT out'),
                  flex: 2, align: TextAlign.right),
              _QCell(t('Af te dragen', 'Payable'),
                  flex: 3, align: TextAlign.right),
            ]),
          ),
          ...qs.map((q) {
            final m = (q as Map).cast<String, dynamic>();
            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: BigDoggTheme.lightBorder),
                ),
              ),
              child: Row(children: [
                _QCell('Q${m['quarter']}', flex: 1, bold: true),
                Expanded(
                  flex: 3,
                  child: Text(
                    _euros(m['revenue_ex']),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(_euros(m['btw_collected']),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12)),
                ),
                Expanded(
                  flex: 2,
                  child: Text(_euros(m['btw_paid']),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12)),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    _euros(m['btw_payable']),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: BigDoggTheme.teal800),
                  ),
                ),
              ]),
            );
          }),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: BigDoggTheme.lightBg,
              border: const Border(
                  top: BorderSide(color: BigDoggTheme.lightBorder)),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(10)),
            ),
            child: Row(children: [
              Expanded(
                flex: 1,
                child: Text(t('Jaar', 'Year'),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: BigDoggTheme.teal800)),
              ),
              Expanded(
                flex: 3,
                child: Text(_euros(totalRev),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              Expanded(
                flex: 2,
                child: Text(_euros(totalBtwIn),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              Expanded(
                flex: 2,
                child: Text(_euros(totalBtwOut),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  _euros(totalPayable),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: BigDoggTheme.teal800),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _btwAangifteCard() {
    final b = _btwBreakdown;
    if (b == null) {
      return _emptyHint(
          t('Geen aangifte-gegevens beschikbaar.',
              'No VAT return data available.'),
          Icons.description_outlined);
    }
    final isYear = _btwQuarter == 0;
    final src = isYear
        ? (b['year'] as Map?)?.cast<String, dynamic>() ?? {}
        : ((b['quarters'] as Map?)?[_btwQuarter.toString()]
                as Map?)
                ?.cast<String, dynamic>() ??
            {};
    final r21 = (src['rate_21'] as Map?)?.cast<String, dynamic>() ?? {};
    final r9 = (src['rate_9'] as Map?)?.cast<String, dynamic>() ?? {};
    final r0 = (src['rate_0'] as Map?)?.cast<String, dynamic>() ?? {};
    final voorbel = src['voorbelasting'];
    final owed = src['btw_owed'];
    final payable = src['btw_payable'];

    return Container(
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
            decoration: const BoxDecoration(
              color: BigDoggTheme.lightBg,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  t('Periode', 'Period'),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: BigDoggTheme.lightTextSecondary),
                ),
              ),
              _quarterPicker(),
            ]),
          ),
          _btwRow(
            '1a',
            t('Leveringen/diensten belast met hoog tarief (21%)',
                'Supplies/services at high rate (21%)'),
            r21['ex'],
            r21['btw'],
          ),
          if ((r9['ex'] is num) && (r9['ex'] as num).toDouble() != 0)
            _btwRow(
              '1b',
              t('Leveringen/diensten belast met laag tarief (9%)',
                  'Supplies/services at low rate (9%)'),
              r9['ex'],
              r9['btw'],
            ),
          if ((r0['ex'] is num) && (r0['ex'] as num).toDouble() != 0)
            _btwRow(
              '1c',
              t('Leveringen/diensten belast met 0%',
                  'Supplies/services at 0%'),
              r0['ex'],
              r0['btw'],
            ),
          _btwRow(
            '5b',
            t('Voorbelasting (BTW op kosten)',
                'Input VAT (VAT on expenses)'),
            null,
            voorbel,
            isCredit: true,
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: BigDoggTheme.lightBg,
              border: const Border(
                  top: BorderSide(color: BigDoggTheme.lightBorder)),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(10)),
            ),
            child: Row(children: [
              const SizedBox(width: 30),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        t('Te betalen aan Belastingdienst',
                            'Payable to tax authority'),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: BigDoggTheme.teal800)),
                    Text(
                        '${t('BTW geïnd', 'VAT collected')} ${_euros(owed)}  −  ${t('voorbelasting', 'input VAT')} ${_euros(voorbel)}',
                        style: const TextStyle(
                            fontSize: 10,
                            color: BigDoggTheme.lightTextSecondary)),
                  ],
                ),
              ),
              Text(
                _euros(payable),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: BigDoggTheme.gold600),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _quarterPicker() {
    final options = [
      ('Q1', 1),
      ('Q2', 2),
      ('Q3', 3),
      ('Q4', 4),
      (t('Jaar', 'Year'), 0),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: options.map((opt) {
        final label = opt.$1;
        final value = opt.$2;
        final selected = value == _btwQuarter;
        return GestureDetector(
          onTap: () => setState(() => _btwQuarter = value),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: selected
                  ? BigDoggTheme.teal800
                  : BigDoggTheme.lightSurface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: selected
                      ? BigDoggTheme.teal800
                      : BigDoggTheme.lightBorder),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected
                    ? Colors.white
                    : BigDoggTheme.lightTextSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _btwRow(String code, String label, dynamic ex, dynamic btw,
      {bool isCredit = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: BigDoggTheme.lightBorder),
        ),
      ),
      child: Row(children: [
        Container(
          width: 30,
          alignment: Alignment.centerLeft,
          child: Text(code,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: BigDoggTheme.gold600)),
        ),
        Expanded(
          flex: 6,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: BigDoggTheme.lightTextPrimary)),
        ),
        if (ex != null)
          SizedBox(
            width: 80,
            child: Text(_euros(ex),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 12,
                    color: BigDoggTheme.lightTextSecondary)),
          )
        else
          const SizedBox(width: 80),
        SizedBox(
          width: 80,
          child: Text(
            (isCredit ? '−' : '') + _euros(btw),
            textAlign: TextAlign.right,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isCredit
                    ? BigDoggTheme.success
                    : BigDoggTheme.teal700),
          ),
        ),
      ]),
    );
  }

  Widget _categoriesList(Map<String, dynamic> o) {
    final cats = (o['categories'] as List?) ?? [];
    if (cats.isEmpty) {
      return _emptyHint(
          t('Geen kosten geboekt.', 'No expenses recorded.'),
          Icons.shopping_bag_outlined);
    }
    return Container(
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Column(
        children: cats.map((c) {
          final m = (c as Map).cast<String, dynamic>();
          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: cats.first == c
                  ? null
                  : const Border(
                      top: BorderSide(color: BigDoggTheme.lightBorder),
                    ),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  (m['category'] ?? '—').toString(),
                  style: const TextStyle(
                      fontSize: 13,
                      color: BigDoggTheme.lightTextPrimary),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: BigDoggTheme.lightBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${m['count']}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: BigDoggTheme.lightTextSecondary)),
              ),
              Text(
                _euros(m['amount_ex']),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: BigDoggTheme.error),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _countsStrip(Map<String, dynamic> o) {
    return Row(children: [
      Expanded(
          child: _countTile(
              label: t('Facturen', 'Invoices'),
              value: o['invoice_count']?.toString() ?? '0')),
      const SizedBox(width: 8),
      Expanded(
          child: _countTile(
              label: t('Betaald', 'Paid'),
              value: o['paid_count']?.toString() ?? '0')),
      const SizedBox(width: 8),
      Expanded(
          child: _countTile(
              label: t('Kosten', 'Expenses'),
              value: o['expense_count']?.toString() ?? '0')),
    ]);
  }

  // ── Tab 2: Invoices ──────────────────────────────────────
  Widget _invoicesTab() {
    return RefreshIndicator(
      onRefresh: () => _loadYear(_year),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _agingCard(),
          const SizedBox(height: 12),
          if (_invoices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: _emptyHint(
                  t('Geen facturen in $_year', 'No invoices in $_year'),
                  Icons.receipt_long_outlined),
            )
          else
            ..._invoices.map((inv) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _invoiceTile(inv),
                )),
        ],
      ),
    );
  }

  Widget _agingCard() {
    final a = _aging;
    if (a == null) return const SizedBox.shrink();
    final order = (a['buckets_order'] as List?)?.cast<String>() ??
        ['0-30', '31-60', '61-90', '90+'];
    final buckets = (a['buckets'] as Map?)?.cast<String, dynamic>() ?? {};
    final total = a['grand_total'];
    final count = a['grand_count'];
    final bucketColors = {
      '0-30': BigDoggTheme.success,
      '31-60': BigDoggTheme.gold500,
      '61-90': BigDoggTheme.gold600,
      '90+': BigDoggTheme.error,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.hourglass_bottom_outlined,
                size: 16, color: BigDoggTheme.teal800),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                t('Debiteuren — openstaand & vervallen',
                    'Receivables — outstanding & overdue'),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: BigDoggTheme.teal800),
              ),
            ),
            Text(
              '$count ${t("openstaand", "outstanding")} · ${_euros(total)}',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: BigDoggTheme.teal800),
            ),
          ]),
          const SizedBox(height: 10),
          Row(
            children: order.map((key) {
              final b = (buckets[key] as Map?)?.cast<String, dynamic>() ?? {};
              final c = b['count'] ?? 0;
              final tot = b['total'] ?? 0;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                      right: key == order.last ? 0 : 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: BigDoggTheme.lightBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: (bucketColors[key] ??
                                BigDoggTheme.lightBorder)
                            .withOpacity(0.45)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _agingBucketLabel(key),
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: bucketColors[key] ??
                                BigDoggTheme.lightTextSecondary,
                            letterSpacing: 0.3),
                      ),
                      const SizedBox(height: 2),
                      Text(_euros(tot),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: BigDoggTheme.teal800)),
                      Text(
                          '$c ${c == 1 ? t("factuur", "invoice") : t("facturen", "invoices")}',
                          style: const TextStyle(
                              fontSize: 9,
                              color:
                                  BigDoggTheme.lightTextSecondary)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _agingBucketLabel(String key) {
    switch (key) {
      case '0-30':
        return t('0–30 DAGEN', '0–30 DAYS');
      case '31-60':
        return t('31–60 DAGEN', '31–60 DAYS');
      case '61-90':
        return t('61–90 DAGEN', '61–90 DAYS');
      case '90+':
        return t('90+ DAGEN', '90+ DAYS');
    }
    return key;
  }

  Widget _invoiceTile(Map<String, dynamic> inv) {
    final num = (inv['invoice_number'] ?? '').toString();
    final clientName = (inv['client_name'] ??
            inv['client_company'] ??
            '—')
        .toString();
    final issue = (inv['invoice_date'] ?? '').toString();
    final status = (inv['status'] ?? '').toString().toLowerCase();
    final paid = status == 'paid';
    final totalIncl = inv['total_incl_btw'];
    final totalEx = inv['subtotal_ex_btw'];
    final id = (inv['id'] ?? '').toString();
    final expanded = _expandedInvoices.contains(id);
    final lines = (inv['lines'] as List?) ?? [];

    return Container(
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (expanded) {
                  _expandedInvoices.remove(id);
                } else {
                  _expandedInvoices.add(id);
                }
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(num,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: BigDoggTheme.teal800)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: paid
                                ? BigDoggTheme.success.withOpacity(0.15)
                                : BigDoggTheme.gold500.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            paid
                                ? t('Betaald', 'Paid')
                                : (status.isEmpty
                                    ? t('Open', 'Open')
                                    : status),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: paid
                                  ? BigDoggTheme.success
                                  : BigDoggTheme.gold600,
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 2),
                      Text(clientName,
                          style: const TextStyle(
                              fontSize: 12,
                              color: BigDoggTheme.lightTextPrimary)),
                      Text(issue,
                          style: const TextStyle(
                              fontSize: 11,
                              color: BigDoggTheme.lightTextSecondary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_euros(totalIncl),
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: BigDoggTheme.teal800)),
                    Text(
                      t('(incl. BTW)', '(incl. VAT)'),
                      style: const TextStyle(
                          fontSize: 9,
                          color: BigDoggTheme.lightTextSecondary,
                          fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${t("excl.", "excl.")} ${_euros(totalEx)}',
                      style: const TextStyle(
                          fontSize: 10,
                          color: BigDoggTheme.lightTextSecondary),
                    ),
                    const SizedBox(height: 2),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: BigDoggTheme.teal700,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 28),
                        tapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: id.isEmpty
                          ? null
                          : () => _downloadInvoicePdf(id, num),
                      icon: const Icon(Icons.download, size: 14),
                      label: const Text('PDF',
                          style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: BigDoggTheme.lightTextSecondary,
                ),
              ]),
            ),
          ),
          if (expanded && lines.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                children: lines.map((ln) {
                  final m = (ln as Map).cast<String, dynamic>();
                  final qty = m['quantity'];
                  final price = m['unit_price_ex_btw'];
                  final rate = m['btw_rate'];
                  final lineTotal = m['line_total_ex_btw'];
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(
                            color: BigDoggTheme.lightBorder),
                      ),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              (m['description'] ?? '').toString(),
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              '$qty × ${_euros(price)} · BTW $rate%',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: BigDoggTheme.lightTextSecondary),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _euros(lineTotal),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: BigDoggTheme.teal700),
                      ),
                    ]),
                  );
                }).toList(),
              ),
            ),
          if (expanded && lines.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(
                t('Geen factuurregels gevonden.',
                    'No line items found.'),
                style: const TextStyle(
                    fontSize: 11,
                    color: BigDoggTheme.lightTextSecondary),
              ),
            ),
        ],
      ),
    );
  }

  // ── Tab 3: Expenses ──────────────────────────────────────
  Widget _expensesTab() {
    if (_expenses.isEmpty) {
      return _emptyState(
          t('Geen kosten in $_year', 'No expenses in $_year'),
          Icons.shopping_bag_outlined);
    }
    return RefreshIndicator(
      onRefresh: () => _loadYear(_year),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _expenses.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          final e = _expenses[i];
          final desc = (e['description'] ?? '—').toString();
          final date = (e['expense_date'] ?? '').toString();
          final amountIncl = e['amount_incl_btw'];
          final amountEx = e['amount_ex_btw'];
          final btw = e['btw_amount'];
          final btwRate = e['btw_rate'];
          final category = (e['category'] ?? '').toString();
          final receipt = (e['receipt_url'] ?? '').toString();
          return Container(
            decoration: BoxDecoration(
              color: BigDoggTheme.lightSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BigDoggTheme.lightBorder),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(desc,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: BigDoggTheme.teal800)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Text(date,
                          style: const TextStyle(
                              fontSize: 11,
                              color: BigDoggTheme.lightTextSecondary)),
                      if (category.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text('· $category',
                            style: const TextStyle(
                                fontSize: 11,
                                color:
                                    BigDoggTheme.lightTextSecondary)),
                      ],
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: BigDoggTheme.lightBg,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text('BTW ${btwRate ?? 0}%',
                            style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color:
                                    BigDoggTheme.lightTextSecondary)),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    Text(
                        '${t("excl.", "excl.")} ${_euros(amountEx)} · BTW ${_euros(btw)}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: BigDoggTheme.lightTextSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_euros(amountIncl),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: BigDoggTheme.error)),
                  Text(
                    t('(incl. BTW)', '(incl. VAT)'),
                    style: const TextStyle(
                        fontSize: 9,
                        color: BigDoggTheme.lightTextSecondary,
                        fontWeight: FontWeight.w600),
                  ),
                  if (receipt.isNotEmpty)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: BigDoggTheme.teal700,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6),
                        minimumSize: const Size(0, 28),
                        tapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _openReceipt(receipt),
                      icon: const Icon(Icons.attach_file, size: 14),
                      label: Text(t('Bon', 'Receipt'),
                          style: const TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ]),
          );
        },
      ),
    );
  }

  // ── Tab 4: Investments ────────────────────────────────────
  Widget _investmentsTab() {
    final data = _investments;
    final items = (data?['investments'] as List?) ?? [];
    if (items.isEmpty) {
      return _emptyState(
          t('Geen investeringen geregistreerd',
              'No investments recorded'),
          Icons.savings_outlined);
    }
    final totalThisYear = data?['total_this_year'];
    return RefreshIndicator(
      onRefresh: () => _loadYear(_year),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BigDoggTheme.lightSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BigDoggTheme.lightBorder),
            ),
            child: Row(children: [
              const Icon(Icons.summarize_outlined,
                  size: 18, color: BigDoggTheme.teal800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(t('Afschrijving dit jaar',
                    'This year\'s depreciation'),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: BigDoggTheme.teal800)),
              ),
              Text(_euros(totalThisYear),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: BigDoggTheme.gold600)),
            ]),
          ),
          const SizedBox(height: 8),
          ...items.map((inv) {
            final m = (inv as Map).cast<String, dynamic>();
            final id = (m['id'] ?? '').toString();
            final desc = (m['description'] ?? '—').toString();
            final purchase = (m['purchase_date'] ?? '').toString();
            final years = m['depreciation_years'];
            final schedule = (m['schedule'] as List?) ?? [];
            final expanded = _expandedInvestments.contains(id);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: BigDoggTheme.lightSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BigDoggTheme.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (expanded) {
                          _expandedInvestments.remove(id);
                        } else {
                          _expandedInvestments.add(id);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(desc,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: BigDoggTheme.teal800)),
                            ),
                            Text(_euros(m['amount']),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: BigDoggTheme.teal800)),
                            const SizedBox(width: 6),
                            Icon(
                              expanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 18,
                              color: BigDoggTheme.lightTextSecondary,
                            ),
                          ]),
                          const SizedBox(height: 2),
                          Text(
                              t('Aangeschaft $purchase · $years jaar afschrijving',
                                  'Purchased $purchase · $years-year depreciation'),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: BigDoggTheme.lightTextSecondary)),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(
                                child: _depCell(
                                    label: t('Dit jaar', 'This year'),
                                    value: _euros(
                                        m['this_year_depreciation']),
                                    color: BigDoggTheme.gold600)),
                            Expanded(
                                child: _depCell(
                                    label: t('Cumulatief', 'Cumulative'),
                                    value: _euros(
                                        m['cumulative_depreciation']),
                                    color: BigDoggTheme.error)),
                            Expanded(
                                child: _depCell(
                                    label: t('Restwaarde', 'Book value'),
                                    value: _euros(m['book_value']),
                                    color: BigDoggTheme.success)),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  if (expanded && schedule.isNotEmpty)
                    _scheduleTable(schedule),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _scheduleTable(List<dynamic> schedule) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        decoration: BoxDecoration(
          color: BigDoggTheme.lightBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: BigDoggTheme.lightBorder),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: BigDoggTheme.lightBorder)),
              ),
              child: Row(children: [
                _SCell(t('Jaar', 'Year'), flex: 2),
                _SCell(t('Afschrijving', 'Depreciation'),
                    flex: 3, align: TextAlign.right),
                _SCell(t('Cumulatief', 'Cumulative'),
                    flex: 3, align: TextAlign.right),
                _SCell(t('Restwaarde', 'Book value'),
                    flex: 3, align: TextAlign.right),
              ]),
            ),
            ...schedule.map((row) {
              final m = (row as Map).cast<String, dynamic>();
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                child: Row(children: [
                  Expanded(
                    flex: 2,
                    child: Text('${m['year']}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: BigDoggTheme.teal800)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(_euros(m['amount']),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 11)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(_euros(m['cumulative']),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 11,
                            color: BigDoggTheme.lightTextSecondary)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(_euros(m['book_value']),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: BigDoggTheme.success)),
                  ),
                ]),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Tab 5: Hours ──────────────────────────────────────────
  Widget _hoursTab() {
    final h = _hours;
    final total = h?['total_hours'];
    final ratio = (h?['urencriterium_ratio'] is num)
        ? (h!['urencriterium_ratio'] as num).toDouble()
        : 0.0;
    final urencriterium = h?['urencriterium'] ?? 1225;
    final summary = (h?['project_summary'] as List?) ?? [];
    final hasNoProjectHours = summary.any((p) {
      final m = (p as Map).cast<String, dynamic>();
      return m['project_id'] == null && (m['hours'] as num? ?? 0) > 0;
    });
    return RefreshIndicator(
      onRefresh: () => _loadYear(_year),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (hasNoProjectHours) _noProjectWarning(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BigDoggTheme.lightSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BigDoggTheme.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.schedule_outlined,
                      size: 16, color: BigDoggTheme.teal700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                        t('Urencriterium', 'Hours criterion'),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: BigDoggTheme.lightTextSecondary)),
                  ),
                  Text(
                      '${(ratio * 100).clamp(0, 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: BigDoggTheme.teal700)),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: ratio,
                    backgroundColor: BigDoggTheme.lightBorder,
                    valueColor:
                        const AlwaysStoppedAnimation(BigDoggTheme.gold500),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${total ?? 0} ${t("van", "of")} $urencriterium ${t("uur", "hours")}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: BigDoggTheme.lightTextSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionTitle(t('Uren per project', 'Hours per project')),
          if (summary.isEmpty)
            _emptyHint(
                t('Geen uren geregistreerd in $_year.',
                    'No hours recorded in $_year.'),
                Icons.schedule_outlined)
          else
            Container(
              decoration: BoxDecoration(
                color: BigDoggTheme.lightSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BigDoggTheme.lightBorder),
              ),
              child: Column(
                children: summary.map((p) {
                  final m = (p as Map).cast<String, dynamic>();
                  final noProject = m['project_id'] == null;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: summary.first == p
                          ? null
                          : const Border(
                              top: BorderSide(
                                  color: BigDoggTheme.lightBorder),
                            ),
                    ),
                    child: Row(children: [
                      if (noProject)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.warning_amber_rounded,
                              size: 14,
                              color: Color(0xFFD97706)),
                        ),
                      Expanded(
                        child: Text(
                          noProject
                              ? t('Geen project', 'No project')
                              : (m['project_name'] ?? '—').toString(),
                          style: TextStyle(
                              fontSize: 13,
                              color: noProject
                                  ? const Color(0xFF92400E)
                                  : BigDoggTheme.lightTextPrimary,
                              fontWeight: noProject
                                  ? FontWeight.w600
                                  : FontWeight.w500),
                        ),
                      ),
                      Text(
                        '${m['hours']} ${t("u", "h")}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: BigDoggTheme.teal800),
                      ),
                    ]),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _noProjectWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD97706)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 18, color: Color(0xFFD97706)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t(
                'Uren zonder project tellen mogelijk niet mee voor de urencriterium-claim. Wijs projecten toe in BigDogg om dit op te lossen.',
                'Hours without a project may not count toward the hours-criterion claim. Assign projects in BigDogg to fix this.',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared bits ───────────────────────────────────────────
  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: BigDoggTheme.teal800)),
      );

  Widget _countTile({required String label, required String value}) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BigDoggTheme.lightSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: BigDoggTheme.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: BigDoggTheme.teal800)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: BigDoggTheme.lightTextSecondary)),
          ],
        ),
      );

  Widget _depCell({
    required String label,
    required String value,
    required Color color,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: BigDoggTheme.lightTextSecondary)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      );

  Widget _emptyHint(String text, IconData icon) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: BigDoggTheme.lightSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: BigDoggTheme.lightBorder),
        ),
        child: Row(children: [
          Icon(icon, color: BigDoggTheme.lightTextHint, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13,
                    color: BigDoggTheme.lightTextSecondary)),
          ),
        ]),
      );

  Widget _emptyState(String text, IconData icon) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: BigDoggTheme.lightTextHint),
            const SizedBox(height: 12),
            Text(text,
                style: const TextStyle(
                    fontSize: 14,
                    color: BigDoggTheme.lightTextSecondary)),
          ],
        ),
      );

  Widget _invalidScreen() {
    return Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: BigDoggTheme.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BigDoggTheme.lightBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline,
                        size: 56, color: BigDoggTheme.error),
                    const SizedBox(height: 16),
                    Text(
                      _humanizeError(_error ?? 'unknown'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BigDoggTheme.teal800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => context.go('/login'),
                        child: Text(t('Naar BigDogg', 'To BigDogg')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiData {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _KpiData(this.label, this.value, this.color, this.icon);
}

class _QCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool bold;
  final TextAlign align;
  const _QCell(this.text,
      {this.flex = 1, this.bold = false, this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Text(
          text,
          textAlign: align,
          style: TextStyle(
            fontSize: 11,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: BigDoggTheme.lightTextSecondary,
          ),
        ),
      );
}

class _SCell extends StatelessWidget {
  final String text;
  final int flex;
  final TextAlign align;
  const _SCell(this.text, {this.flex = 1, this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Text(
          text,
          textAlign: align,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BigDoggTheme.lightTextSecondary,
              letterSpacing: 0.3),
        ),
      );
}
