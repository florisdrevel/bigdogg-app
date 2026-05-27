import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/accountants_service.dart';
import '../theme.dart';

/// Token-gated read-only accountant portal at `/accountant/portal/:token`.
/// Six tabs: Overzicht / Facturen / Kosten / Investeringen / Uren / BTW.
/// Sticky header with client name, KvK, year, expiry banner, and a
/// prominent "Download Jaarrapport" button that fetches the same AI
/// annual PDF the owner can download.
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
  bool _downloadingPdf = false;
  String? _error;
  bool _isNl = true;

  // Dutch tax figures used by the indicative P&L.
  // MKB-winstvrijstelling per spec; zelfstandigenaftrek 2026 = €5.030.
  static const double _mkbExemptionRate = 0.1331;
  static const double _zelfstandigenaftrek = 5030.0;
  static const int _urencriterium = 1225;

  Map<String, dynamic> _meta = {};
  List<int> _years = [];
  int _year = DateTime.now().year;
  // 0 = full year, 1..4 = quarter
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

  // ── Responsive layout ────────────────────────────────────
  // On wide (desktop) viewports the portal was rendering a phone-width
  // layout stretched edge-to-edge: tiny text on very long lines. We cap
  // content to a centered column and scale type up. _bodyHPad is the
  // horizontal padding the tab bodies use to center within that column;
  // it's recomputed at the top of build().
  static const double _maxContentWidth = 1080;
  static const double _wideBreakpoint = 900;

  bool _isWide(BuildContext context) =>
      MediaQuery.of(context).size.width > _wideBreakpoint;

  /// Full-bleed background, content centered to [_maxContentWidth]. Used
  /// for the header / summary / tab bars whose colored backgrounds span
  /// the whole screen but whose content should line up with the body.
  Widget _capped(Widget child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: child,
        ),
      );

  /// Centers a scrollable tab body to [_maxContentWidth]. On phones the
  /// max-width never binds, so the layout is unchanged there.
  Widget _tabBody(Widget child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: child,
        ),
      );

  String t(String nl, String en) => _isNl ? nl : en;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _bootstrap();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ── Bootstrap & data loading ─────────────────────────────
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
    _btwQuarter = ((DateTime.now().month - 1) ~/ 3) + 1;
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

  // ── Helpers ──────────────────────────────────────────────
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

  double _asDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;

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
    return t('Toegang vervalt over $d dagen', 'Access expires in $d days');
  }

  String _monthName(int m) {
    const nl = ['Jan', 'Feb', 'Mrt', 'Apr', 'Mei', 'Jun',
                'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dec'];
    const en = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (m < 1 || m > 12) return '—';
    return (_isNl ? nl : en)[m - 1];
  }

  // ── Action handlers ──────────────────────────────────────
  Future<void> _downloadInvoicePdf(String invoiceId, String invoiceNumber) async {
    final url = AccountantsService.portalInvoicePdfUrl(widget.token, invoiceId);
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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

  Future<void> _downloadAnnualReport() async {
    if (_downloadingPdf) return;
    setState(() => _downloadingPdf = true);
    final url = AccountantsService.portalAnnualReportPdfUrl(
        widget.token, _year, _isNl ? 'nl' : 'en');
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: BigDoggTheme.success,
        duration: const Duration(seconds: 4),
        content: Text(t(
            'Jaarrapport $_year wordt geopend (het kan een paar tellen duren — AI-tips worden gegenereerd).',
            'Annual report $_year is opening (it may take a few seconds — AI tips are being generated).')),
      ));
    } catch (_) {
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: url));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: BigDoggTheme.error,
        duration: const Duration(seconds: 6),
        content: Text(t('Kon jaarrapport niet openen — link gekopieerd.',
            'Could not open annual report — link copied.')),
      ));
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  // ── build ────────────────────────────────────────────────
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
    final expired = daysLeft < 0;
    final warnExpiry = !expired && daysLeft <= 30;

    final mq = MediaQuery.of(context);
    final wide = _isWide(context);
    // Bump type ~17% on desktop so the phone-sized fonts become readable
    // on a large screen. textScaler multiplies every Text's fontSize, so
    // we don't have to touch each style individually.
    final scaler = wide
        ? const TextScaler.linear(1.17)
        : mq.textScaler;

    final column = Column(
      children: [
        _header(),
        if (expired || warnExpiry) _expiryBanner(expired, daysLeft),
        _summaryBar(),
        _tabBar(),
        if (_yearLoading)
          const LinearProgressIndicator(
              minHeight: 2, color: BigDoggTheme.gold500),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _tabBody(_overviewTab()),
              _tabBody(_invoicesTab()),
              _tabBody(_expensesTab()),
              _tabBody(_investmentsTab()),
              _tabBody(_hoursTab()),
              _tabBody(_btwTab()),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      body: MediaQuery(
        data: mq.copyWith(textScaler: scaler),
        child: SafeArea(child: column),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────
  Widget _header() {
    final ownerName =
        (_meta['owner_name'] ?? '').toString().trim().isEmpty
            ? t('BigDogg-gebruiker', 'BigDogg user')
            : (_meta['owner_name']).toString();
    final kvk = (_meta['kvk_number'] ?? '').toString();
    final btw = (_meta['btw_number'] ?? '').toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(color: BigDoggTheme.teal800),
      child: _capped(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                t('BigDogg · Accountantsportaal',
                    'BigDogg · Accountant Portal'),
                style: const TextStyle(
                  color: Color(0xFFC9A96E),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _langToggle(),
            const SizedBox(width: 6),
            _csvButton(),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ownerName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (kvk.isNotEmpty || btw.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(spacing: 14, runSpacing: 2, children: [
                      if (kvk.isNotEmpty)
                        Text('KvK $kvk',
                            style: const TextStyle(
                                color: Color(0xFFE2DDD6),
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      if (btw.isNotEmpty)
                        Text('BTW $btw',
                            style: const TextStyle(
                                color: Color(0xFFE2DDD6),
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                    ]),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            _yearDropdown(),
          ]),
          const SizedBox(height: 14),
          _annualReportButton(),
        ],
      )),
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
          border:
              Border.all(color: const Color(0xFFC9A96E).withOpacity(0.5)),
        ),
        child: Text(_isNl ? 'EN' : 'NL',
            style: const TextStyle(
                color: Color(0xFFC9A96E),
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _csvButton() {
    return GestureDetector(
      onTap: _exportCsv,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFC9A96E).withOpacity(0.18),
          borderRadius: BorderRadius.circular(6),
          border:
              Border.all(color: const Color(0xFFC9A96E).withOpacity(0.5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: const [
          Icon(Icons.table_view_outlined,
              size: 12, color: Color(0xFFC9A96E)),
          SizedBox(width: 4),
          Text('CSV',
              style: TextStyle(
                  color: Color(0xFFC9A96E),
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _annualReportButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC9A96E),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        onPressed: _downloadingPdf ? null : _downloadAnnualReport,
        icon: _downloadingPdf
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.picture_as_pdf_rounded, size: 16),
        label: Text(
          _downloadingPdf
              ? t('Jaarrapport openen…', 'Opening report…')
              : t('Download Jaarrapport $_year',
                  'Download Annual Report $_year'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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

  // ── Summary bar / expiry banner / tab bar ───────────────
  Widget _summaryBar() {
    final o = _overview ?? {};
    final korRatio = _asDouble(o['kor_ratio']);
    final korPct = (korRatio * 100).clamp(0, 100).toStringAsFixed(0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: BigDoggTheme.lightSurface,
        border:
            Border(bottom: BorderSide(color: BigDoggTheme.lightBorder)),
      ),
      child: _capped(Row(children: [
        Expanded(
            child: _summaryCell(
                t('Omzet', 'Revenue'),
                _euros(o['revenue_ex']),
                t('(excl. BTW)', '(excl. VAT)'),
                BigDoggTheme.success)),
        _vSep(),
        Expanded(
            child: _summaryCell(
                t('Winst', 'Profit'),
                _euros(o['profit_ex']),
                t('(excl. BTW)', '(excl. VAT)'),
                BigDoggTheme.teal800)),
        _vSep(),
        Expanded(
            child: _summaryCell(
                'BTW',
                _euros(o['btw_payable']),
                t('te betalen', 'payable'),
                BigDoggTheme.gold600)),
        _vSep(),
        Expanded(
            child: _summaryCell(
                'KOR',
                '$korPct%',
                t('drempel', 'threshold'),
                BigDoggTheme.teal700)),
      ])),
    );
  }

  Widget _vSep() => Container(
      width: 1, height: 40, color: BigDoggTheme.lightBorder);

  Widget _summaryCell(String label, String value, String hint, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: BigDoggTheme.lightTextSecondary)),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: color),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 1),
        Text(hint,
            style: const TextStyle(
                fontSize: 10, color: BigDoggTheme.lightTextHint)),
      ],
    );
  }

  Widget _expiryBanner(bool expired, int daysLeft) {
    final urgent = !expired && daysLeft <= 5;
    final bgColor = expired
        ? BigDoggTheme.error.withOpacity(0.14)
        : (urgent ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7));
    final fgColor = expired
        ? BigDoggTheme.error
        : (urgent ? const Color(0xFF991B1B) : const Color(0xFF92400E));
    final borderColor = expired
        ? BigDoggTheme.error.withOpacity(0.5)
        : (urgent ? const Color(0xFFB91C1C) : const Color(0xFFD97706));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: _capped(Row(children: [
        Icon(
          expired
              ? Icons.error_outline
              : Icons.warning_amber_rounded,
          size: 18,
          color: fgColor,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _expiryLabel(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: fgColor,
            ),
          ),
        ),
      ])),
    );
  }

  Widget _tabBar() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: BigDoggTheme.lightSurface,
        border: Border(bottom: BorderSide(color: BigDoggTheme.lightBorder)),
      ),
      child: _capped(TabBar(
        controller: _tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: BigDoggTheme.teal800,
        unselectedLabelColor: BigDoggTheme.lightTextSecondary,
        indicatorColor: BigDoggTheme.gold500,
        indicatorWeight: 3,
        labelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        tabs: [
          Tab(text: t('Overzicht', 'Overview')),
          Tab(text: t('Facturen', 'Invoices')),
          Tab(text: t('Kosten', 'Expenses')),
          Tab(text: t('Investeringen', 'Investments')),
          Tab(text: t('Uren', 'Hours')),
          const Tab(text: 'BTW'),
        ],
      )),
    );
  }

  // ── Tab 1: Overzicht (P&L statement) ─────────────────────
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
            _pnlCard(o),
            const SizedBox(height: 16),
            _sectionTitle(t('Per kwartaal', 'Per quarter')),
            _quartersTable(o),
            const SizedBox(height: 16),
            _sectionTitle(
                t('Kosten per categorie', 'Expenses by category')),
            _categoriesList(o),
            const SizedBox(height: 16),
            _countsStrip(o),
          ],
        ],
      ),
    );
  }

  /// Dutch Winst- & Verliesrekening as a boekhouder reads it.
  /// All values are excl. BTW.
  Widget _pnlCard(Map<String, dynamic> o) {
    final omzet = _asDouble(o['revenue_ex']);
    final kosten = _asDouble(o['expense_ex']);
    final brutowinst = omzet - kosten;
    final dep = _asDouble(_investments?['total_this_year']);
    final bedrijfsresultaat = brutowinst - dep;
    final totalHours = _asDouble(_hours?['total_hours']);
    final urencriteriumMet = totalHours >= _urencriterium;
    final mkbAftrek = bedrijfsresultaat > 0
        ? bedrijfsresultaat * _mkbExemptionRate
        : 0.0;
    final zaftrek = urencriteriumMet ? _zelfstandigenaftrek : 0.0;
    final belastbaar = bedrijfsresultaat - mkbAftrek - zaftrek;

    return Container(
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.calculate_outlined,
                size: 18, color: BigDoggTheme.teal800),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t('Winst- & Verliesrekening $_year',
                    'Profit & Loss Statement $_year'),
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: BigDoggTheme.teal800),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: BigDoggTheme.gold500.withOpacity(0.16),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('excl. BTW',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: BigDoggTheme.gold600)),
            ),
          ]),
          const SizedBox(height: 14),
          _pnlRow(t('Omzet', 'Revenue'), omzet, negative: false),
          _pnlRow(t('Kosten', 'Costs'), kosten, negative: true),
          _pnlDivider(),
          _pnlRow(t('Brutowinst', 'Gross profit'), brutowinst,
              negative: false, bold: true),
          _pnlRow(t('Afschrijvingen', 'Depreciation'), dep,
              negative: true),
          _pnlDivider(),
          _pnlRow(t('Bedrijfsresultaat', 'Operating profit'),
              bedrijfsresultaat,
              negative: false, bold: true),
          _pnlRow(
            t('MKB-winstvrijstelling (13,31%)',
                'SME profit exemption (13.31%)'),
            mkbAftrek,
            negative: true,
          ),
          _pnlRow(
            t('Zelfstandigenaftrek', 'Self-employed deduction'),
            zaftrek,
            negative: true,
            hint: urencriteriumMet
                ? t('✓ Urencriterium (1.225 u) gehaald',
                    '✓ Hours criterion (1,225 hrs) met')
                : t('✗ Urencriterium niet gehaald — niet toegepast',
                    '✗ Hours criterion not met — not applied'),
          ),
          _pnlDivider(thick: true),
          _pnlRow(
            t('Belastbare winst (indicatief)',
                'Taxable profit (indicative)'),
            belastbaar,
            negative: false,
            bold: true,
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _pnlRow(String label, double value,
      {required bool negative,
      bool bold = false,
      bool highlight = false,
      String? hint}) {
    final labelColor = highlight || bold
        ? BigDoggTheme.teal800
        : BigDoggTheme.lightTextPrimary;
    final amountColor = negative
        ? BigDoggTheme.error
        : (highlight || bold
            ? BigDoggTheme.teal800
            : BigDoggTheme.lightTextPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: highlight ? 14 : 13,
                        fontWeight:
                            bold ? FontWeight.w800 : FontWeight.w500,
                        color: labelColor)),
                if (hint != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(hint,
                        style: const TextStyle(
                            fontSize: 10,
                            color: BigDoggTheme.lightTextSecondary,
                            fontStyle: FontStyle.italic)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${negative ? '− ' : ''}${_euros(value.abs())}',
            style: TextStyle(
                fontSize: highlight ? 16 : (bold ? 14 : 13),
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: amountColor),
          ),
        ],
      ),
    );
  }

  Widget _pnlDivider({bool thick = false}) => Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        height: thick ? 2 : 1,
        color: thick ? BigDoggTheme.teal800 : BigDoggTheme.lightBorder,
      );

  Widget _quartersTable(Map<String, dynamic> o) {
    final qs = (o['quarters'] as List?) ?? [];
    final totalRev = qs.fold<double>(
        0.0,
        (sum, q) =>
            sum + ((q as Map)['revenue_ex'] as num? ?? 0).toDouble());
    final totalExp = qs.fold<double>(
        0.0,
        (sum, q) =>
            sum + ((q as Map)['expense_ex'] as num? ?? 0).toDouble());
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
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: BigDoggTheme.lightBg,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Row(children: [
            const _QCell('', flex: 1),
            _QCell(t('Omzet', 'Revenue'),
                flex: 3, align: TextAlign.right),
            _QCell(t('Kosten', 'Costs'),
                flex: 3, align: TextAlign.right),
            _QCell(t('BTW saldo', 'VAT balance'),
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
              Expanded(
                flex: 1,
                child: Text('Q${m['quarter']}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: BigDoggTheme.teal800)),
              ),
              Expanded(
                flex: 3,
                child: Text(_euros(m['revenue_ex']),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12)),
              ),
              Expanded(
                flex: 3,
                child: Text(_euros(m['expense_ex']),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12, color: BigDoggTheme.error)),
              ),
              Expanded(
                flex: 3,
                child: Text(_euros(m['btw_payable']),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: BigDoggTheme.teal800)),
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
                top: BorderSide(color: BigDoggTheme.teal800, width: 1.5)),
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(10)),
          ),
          child: Row(children: [
            Expanded(
              flex: 1,
              child: Text(t('Jaar', 'Year'),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: BigDoggTheme.teal800)),
            ),
            Expanded(
              flex: 3,
              child: Text(_euros(totalRev),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800)),
            ),
            Expanded(
              flex: 3,
              child: Text(_euros(totalExp),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: BigDoggTheme.error)),
            ),
            Expanded(
              flex: 3,
              child: Text(_euros(totalPayable),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: BigDoggTheme.teal800)),
            ),
          ]),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
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
              const SizedBox(width: 4),
              Text(t('excl.', 'excl.'),
                  style: const TextStyle(
                      fontSize: 9,
                      color: BigDoggTheme.lightTextSecondary)),
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

  // ── Tab 2: Facturen ──────────────────────────────────────
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
                  t('Geen facturen in $_year',
                      'No invoices in $_year'),
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
    final buckets =
        (a['buckets'] as Map?)?.cast<String, dynamic>() ?? {};
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
              '$count · ${_euros(total)}',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: BigDoggTheme.teal800),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            t('Bedragen incl. BTW', 'Amounts incl. VAT'),
            style: const TextStyle(
                fontSize: 10,
                color: BigDoggTheme.lightTextSecondary,
                fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 10),
          Row(
            children: order.map((key) {
              final b = (buckets[key] as Map?)?.cast<String, dynamic>() ??
                  {};
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
                              color: BigDoggTheme.teal800),
                          overflow: TextOverflow.ellipsis),
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
    final clientName =
        (inv['client_name'] ?? inv['client_company'] ?? '—').toString();
    final issue = (inv['invoice_date'] ?? '').toString();
    final status = (inv['status'] ?? '').toString().toLowerCase();
    final paid = status == 'paid';
    final totalIncl = inv['total_incl_btw'];
    final totalEx = inv['subtotal_ex_btw'];
    final btwAmt = inv['btw_amount'];
    final id = (inv['id'] ?? '').toString();
    final expanded = _expandedInvoices.contains(id);
    final lines = (inv['lines'] as List?) ?? [];

    return Container(
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Column(children: [
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(num,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: BigDoggTheme.teal800)),
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
                                      : _statusLabel(status)),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: paid
                                    ? BigDoggTheme.success
                                    : BigDoggTheme.gold600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(clientName,
                          style: const TextStyle(
                              fontSize: 12,
                              color:
                                  BigDoggTheme.lightTextPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(issue,
                          style: const TextStyle(
                              fontSize: 11,
                              color: BigDoggTheme.lightTextSecondary)),
                      const SizedBox(height: 3),
                      Text(
                        '${_euros(totalEx)} ${t("excl. BTW", "excl. VAT")} · BTW ${_euros(btwAmt)}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: BigDoggTheme.lightTextSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 110,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_euros(totalIncl),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: BigDoggTheme.teal800),
                          overflow: TextOverflow.ellipsis),
                      Text(
                        t('(incl. BTW)', '(incl. VAT)'),
                        style: const TextStyle(
                            fontSize: 9,
                            color: BigDoggTheme.lightTextSecondary,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: id.isEmpty
                            ? null
                            : () => _downloadInvoicePdf(id, num),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: BigDoggTheme.teal700.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.download,
                                    size: 12,
                                    color: BigDoggTheme.teal700),
                                SizedBox(width: 3),
                                Text('PDF',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: BigDoggTheme.teal700,
                                        fontWeight: FontWeight.w700)),
                              ]),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: BigDoggTheme.lightTextSecondary,
                ),
              ],
            ),
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
                    const SizedBox(width: 6),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_euros(lineTotal),
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: BigDoggTheme.teal700)),
                          Text(t('excl. BTW', 'excl. VAT'),
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: BigDoggTheme.lightTextSecondary)),
                        ]),
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
      ]),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'sent':
        return t('Open', 'Open');
      case 'overdue':
        return t('Vervallen', 'Overdue');
      case 'paid':
        return t('Betaald', 'Paid');
      case 'draft':
        return t('Concept', 'Draft');
    }
    return s;
  }

  // ── Tab 3: Kosten ────────────────────────────────────────
  Widget _expensesTab() {
    if (_expenses.isEmpty) {
      return _emptyState(
          t('Geen kosten in $_year', 'No expenses in $_year'),
          Icons.shopping_bag_outlined);
    }

    // Compute category subtotals from the actual rendered list — the
    // boekhouder sees the same source data as the table they're looking
    // at. Sorted descending, falls through to "general" for blanks.
    final byCategory = <String, double>{};
    for (final e in _expenses) {
      final cat =
          (e['category']?.toString().trim().isEmpty ?? true)
              ? 'general'
              : e['category'].toString().trim();
      byCategory[cat] =
          (byCategory[cat] ?? 0.0) + _asDouble(e['amount_ex_btw']);
    }
    final subtotals = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalEx =
        byCategory.values.fold<double>(0.0, (s, v) => s + v);

    return RefreshIndicator(
      onRefresh: () => _loadYear(_year),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          ..._expenses.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _expenseTile(e),
              )),
          const SizedBox(height: 8),
          _sectionTitle(
              t('Subtotalen per categorie', 'Subtotals per category')),
          _categorySubtotalsTable(subtotals, totalEx),
        ],
      ),
    );
  }

  Widget _expenseTile(Map<String, dynamic> e) {
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(desc,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: BigDoggTheme.teal800),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                // Meta row — Wrap protects against overflow on small
                // viewports and long category names.
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(date,
                        style: const TextStyle(
                            fontSize: 11,
                            color: BigDoggTheme.lightTextSecondary)),
                    if (category.isNotEmpty)
                      Text('· $category',
                          style: const TextStyle(
                              fontSize: 11,
                              color:
                                  BigDoggTheme.lightTextSecondary)),
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
                              color: BigDoggTheme
                                  .lightTextSecondary)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_euros(amountEx)} ${t("excl. BTW", "excl. VAT")} · BTW ${_euros(btw)}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: BigDoggTheme.lightTextSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_euros(amountIncl),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: BigDoggTheme.error),
                    overflow: TextOverflow.ellipsis),
                Text(t('(incl. BTW)', '(incl. VAT)'),
                    style: const TextStyle(
                        fontSize: 9,
                        color: BigDoggTheme.lightTextSecondary,
                        fontWeight: FontWeight.w600)),
                if (receipt.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _openReceipt(receipt),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: BigDoggTheme.teal700.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.attach_file,
                                size: 12,
                                color: BigDoggTheme.teal700),
                            const SizedBox(width: 3),
                            Text(t('Bon', 'Receipt'),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: BigDoggTheme.teal700,
                                    fontWeight: FontWeight.w600)),
                          ]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categorySubtotalsTable(
      List<MapEntry<String, double>> subtotals, double total) {
    return Container(
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Column(
        children: [
          ...subtotals.map((kv) {
            final pct = total > 0 ? (kv.value / total * 100) : 0.0;
            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: subtotals.first.key == kv.key
                    ? null
                    : const Border(
                        top: BorderSide(
                            color: BigDoggTheme.lightBorder)),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(kv.key,
                      style: const TextStyle(
                          fontSize: 13,
                          color: BigDoggTheme.lightTextPrimary)),
                ),
                Text('${pct.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontSize: 11,
                        color: BigDoggTheme.lightTextSecondary)),
                const SizedBox(width: 12),
                Text(_euros(kv.value),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: BigDoggTheme.error)),
              ]),
            );
          }),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: BigDoggTheme.lightBg,
              border: const Border(
                  top: BorderSide(
                      color: BigDoggTheme.teal800, width: 1.5)),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(10)),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  t('Totaal kosten (excl. BTW)',
                      'Total expenses (excl. VAT)'),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: BigDoggTheme.teal800),
                ),
              ),
              Text(_euros(total),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: BigDoggTheme.teal800)),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Tab 4: Investeringen ─────────────────────────────────
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
                child: Text(
                    t('Afschrijving dit jaar',
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
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _investmentTile(m),
            );
          }),
        ],
      ),
    );
  }

  Widget _investmentTile(Map<String, dynamic> m) {
    final id = (m['id'] ?? '').toString();
    final desc = (m['description'] ?? '—').toString();
    final purchase = (m['purchase_date'] ?? '').toString();
    final years = m['depreciation_years'];
    final amount = m['amount'];
    final annual = m['annual_depreciation'];
    final schedule = (m['schedule'] as List?) ?? [];
    final expanded = _expandedInvestments.contains(id);

    return Container(
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
                              color: BigDoggTheme.teal800),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_euros(amount),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: BigDoggTheme.teal800)),
                        Text(
                            t('aanschafwaarde', 'purchase value'),
                            style: const TextStyle(
                                fontSize: 9,
                                color: BigDoggTheme
                                    .lightTextSecondary)),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      expanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 18,
                      color: BigDoggTheme.lightTextSecondary,
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 2,
                    children: [
                      _miniMeta(
                          t('Aangeschaft', 'Purchased'), purchase),
                      _miniMeta(
                          t('Periode', 'Period'),
                          '$years ${t("jaar", "yrs")}'),
                      _miniMeta(
                          t('Methode', 'Method'),
                          t('Lineair', 'Straight-line')),
                      _miniMeta(
                          t('Jaarlijks', 'Annual'),
                          _euros(annual)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: _depCell(
                            label: t('Dit jaar', 'This year'),
                            value: _euros(
                                m['this_year_depreciation']),
                            color: BigDoggTheme.gold600)),
                    Expanded(
                        child: _depCell(
                            label: t('Cumulatief',
                                'Cumulative'),
                            value: _euros(
                                m['cumulative_depreciation']),
                            color: BigDoggTheme.error)),
                    Expanded(
                        child: _depCell(
                            label:
                                t('Restwaarde', 'Book value'),
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
  }

  Widget _miniMeta(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ',
            style: const TextStyle(
                fontSize: 11,
                color: BigDoggTheme.lightTextSecondary)),
        Text(value,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: BigDoggTheme.lightTextPrimary)),
      ],
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
                    bottom:
                        BorderSide(color: BigDoggTheme.lightBorder)),
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
                            color:
                                BigDoggTheme.lightTextSecondary)),
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

  // ── Tab 5: Uren ──────────────────────────────────────────
  Widget _hoursTab() {
    final h = _hours ?? {};
    final total = _asDouble(h['total_hours']);
    final manual = _asDouble(h['manual_hours']);
    final invoice = _asDouble(h['invoice_hours']);
    final ratio = _asDouble(h['urencriterium_ratio']);
    final criterium = (h['urencriterium'] is num)
        ? (h['urencriterium'] as num).toInt()
        : _urencriterium;
    final criteriumMet = total >= criterium;
    final summary = (h['project_summary'] as List?) ?? [];
    final monthly = (h['monthly'] as List?) ?? [];
    final hasNoProjectHours = summary.any((p) {
      final m = (p as Map).cast<String, dynamic>();
      return m['project_id'] == null &&
          (m['hours'] as num? ?? 0) > 0;
    });

    return RefreshIndicator(
      onRefresh: () => _loadYear(_year),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (hasNoProjectHours) _noProjectWarning(),
          _criteriumCard(
              total, criterium, ratio, criteriumMet, manual, invoice),
          const SizedBox(height: 12),
          _sectionTitle(t('Per maand', 'Per month')),
          _monthlyHoursTable(monthly),
          const SizedBox(height: 12),
          _sectionTitle(
              t('Uren per project', 'Hours per project')),
          if (summary.isEmpty)
            _emptyHint(
                t('Geen uren geregistreerd in $_year.',
                    'No hours recorded in $_year.'),
                Icons.schedule_outlined)
          else
            _projectsSummaryTable(summary),
        ],
      ),
    );
  }

  Widget _criteriumCard(double total, int criterium, double ratio,
      bool met, double manual, double invoice) {
    return Container(
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
            Icon(
              met ? Icons.check_circle : Icons.schedule_outlined,
              size: 16,
              color: met
                  ? BigDoggTheme.success
                  : BigDoggTheme.teal700,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                  t('Urencriterium', 'Hours criterion'),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: BigDoggTheme.teal800)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: met
                    ? BigDoggTheme.success.withOpacity(0.15)
                    : BigDoggTheme.gold500.withOpacity(0.18),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                met
                    ? t('Gehaald ✓', 'Met ✓')
                    : t('Niet gehaald ✗', 'Not met ✗'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: met
                      ? BigDoggTheme.success
                      : BigDoggTheme.gold600,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: ratio,
              backgroundColor: BigDoggTheme.lightBorder,
              valueColor: AlwaysStoppedAnimation(
                  met
                      ? BigDoggTheme.success
                      : BigDoggTheme.gold500),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${total.toStringAsFixed(1)} ${t("van", "of")} ${criterium.toString()} ${t("uur", "hours")} (${(ratio * 100).clamp(0, 100).toStringAsFixed(0)}%)',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: BigDoggTheme.teal800),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: _hoursBreakdownCell(
                  t('Handmatig', 'Manual'), manual),
            ),
            Expanded(
              child: _hoursBreakdownCell(
                  t('Vanuit facturen', 'From invoices'), invoice),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _hoursBreakdownCell(String label, double hours) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: BigDoggTheme.lightTextSecondary)),
        Text('${hours.toStringAsFixed(1)} ${t("u", "h")}',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: BigDoggTheme.lightTextPrimary)),
      ],
    );
  }

  Widget _monthlyHoursTable(List<dynamic> monthly) {
    if (monthly.isEmpty) {
      return _emptyHint(
          t('Geen maandverdeling beschikbaar.',
              'No monthly breakdown available.'),
          Icons.calendar_month_outlined);
    }
    return Container(
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Column(children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: BigDoggTheme.lightBg,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Row(children: [
            const _QCell('', flex: 2),
            _QCell(t('Handmatig', 'Manual'),
                flex: 3, align: TextAlign.right),
            _QCell(t('Facturen', 'Invoices'),
                flex: 3, align: TextAlign.right),
            _QCell(t('Totaal', 'Total'),
                flex: 3, align: TextAlign.right),
          ]),
        ),
        ...monthly.map((row) {
          final m = (row as Map).cast<String, dynamic>();
          final month =
              (m['month'] is num) ? (m['month'] as num).toInt() : 0;
          final manual = _asDouble(m['manual_hours']);
          final invoice = _asDouble(m['invoice_hours']);
          final total = _asDouble(m['total_hours']);
          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                  top: BorderSide(color: BigDoggTheme.lightBorder)),
            ),
            child: Row(children: [
              Expanded(
                flex: 2,
                child: Text(_monthName(month),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BigDoggTheme.teal800)),
              ),
              Expanded(
                flex: 3,
                child: Text(
                    manual == 0
                        ? '—'
                        : '${manual.toStringAsFixed(1)} ${t("u", "h")}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12)),
              ),
              Expanded(
                flex: 3,
                child: Text(
                    invoice == 0
                        ? '—'
                        : '${invoice.toStringAsFixed(1)} ${t("u", "h")}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12)),
              ),
              Expanded(
                flex: 3,
                child: Text(
                    total == 0
                        ? '—'
                        : '${total.toStringAsFixed(1)} ${t("u", "h")}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: BigDoggTheme.teal800)),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _projectsSummaryTable(List<dynamic> summary) {
    return Container(
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
                      size: 14, color: Color(0xFFD97706)),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(m['hours'] as num? ?? 0).toStringAsFixed(1)} ${t("u", "h")}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: BigDoggTheme.teal800),
              ),
            ]),
          );
        }).toList(),
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
                'Let op: een deel van de uren is niet aan een project gekoppeld. Deze tellen mogelijk niet mee voor het urencriterium.',
                "Heads up: some hours aren't assigned to a project. They may not count toward the hours-criterion claim.",
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

  // ── Tab 6: BTW ───────────────────────────────────────────
  Widget _btwTab() {
    final b = _btwBreakdown;
    final o = _overview ?? {};
    if (b == null) {
      return _emptyState(
          t('Geen aangifte-gegevens beschikbaar.',
              'No VAT return data available.'),
          Icons.description_outlined);
    }
    return RefreshIndicator(
      onRefresh: () => _loadYear(_year),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _btwAangifteCard(b),
          const SizedBox(height: 16),
          _sectionTitle(t('Per kwartaal', 'Per quarter')),
          _btwQuartersOverviewTable(b),
          const SizedBox(height: 16),
          _sectionTitle(t('KOR-status', 'KOR status')),
          _korCard(o),
        ],
      ),
    );
  }

  Widget _btwAangifteCard(Map<String, dynamic> b) {
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          decoration: const BoxDecoration(
            color: BigDoggTheme.lightBg,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('BTW aangifte', 'VAT return'),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: BigDoggTheme.teal800),
                  ),
                  Text(
                    t('Format Belastingdienst',
                        'Belastingdienst format'),
                    style: const TextStyle(
                        fontSize: 10,
                        color: BigDoggTheme.lightTextSecondary,
                        fontStyle: FontStyle.italic),
                  ),
                ],
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
              horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: BigDoggTheme.lightBg,
            border: const Border(
                top: BorderSide(
                    color: BigDoggTheme.teal800, width: 1.5)),
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12)),
          ),
          child: Row(children: [
            const SizedBox(width: 30),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      t('Saldo — te betalen aan Belastingdienst',
                          'Balance — payable to tax authority'),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: BigDoggTheme.teal800)),
                  Text(
                      '${t("BTW geïnd", "VAT collected")} ${_euros(owed)}  −  ${t("voorbelasting", "input VAT")} ${_euros(voorbel)}',
                      style: const TextStyle(
                          fontSize: 10,
                          color:
                              BigDoggTheme.lightTextSecondary)),
                ],
              ),
            ),
            Text(
              _euros(payable),
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: BigDoggTheme.gold600),
            ),
          ]),
        ),
      ]),
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
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border:
            Border(top: BorderSide(color: BigDoggTheme.lightBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(width: 4),
          SizedBox(
            width: 75,
            child: Text(ex != null ? _euros(ex) : '',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 12,
                    color: BigDoggTheme.lightTextSecondary)),
          ),
          SizedBox(
            width: 75,
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
        ],
      ),
    );
  }

  /// Compact quarter-by-quarter overview table for the BTW tab. Helps
  /// the boekhouder spot which periods still need filing.
  Widget _btwQuartersOverviewTable(Map<String, dynamic> b) {
    final quarters =
        (b['quarters'] as Map?)?.cast<String, dynamic>() ?? {};
    final year = (b['year'] as Map?)?.cast<String, dynamic>() ?? {};
    final rows = <Widget>[];
    for (var q = 1; q <= 4; q++) {
      final src =
          (quarters[q.toString()] as Map?)?.cast<String, dynamic>() ?? {};
      rows.add(_btwSummaryRow('Q$q', src));
    }
    rows.add(_btwSummaryRow(t('Jaar', 'Year'), year, isTotal: true));
    return Container(
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Column(children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: BigDoggTheme.lightBg,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Row(children: [
            const _QCell('', flex: 2),
            _QCell(t('BTW geïnd', 'VAT collected'),
                flex: 3, align: TextAlign.right),
            _QCell(t('Voorbelasting', 'Input VAT'),
                flex: 3, align: TextAlign.right),
            _QCell(t('Saldo', 'Balance'),
                flex: 3, align: TextAlign.right),
          ]),
        ),
        ...rows,
      ]),
    );
  }

  Widget _btwSummaryRow(String label, Map<String, dynamic> src,
      {bool isTotal = false}) {
    final owed = src['btw_owed'];
    final vrb = src['voorbelasting'];
    final pay = src['btw_payable'];
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isTotal ? BigDoggTheme.lightBg : null,
        border: Border(
          top: BorderSide(
              color: isTotal
                  ? BigDoggTheme.teal800
                  : BigDoggTheme.lightBorder,
              width: isTotal ? 1.5 : 1),
        ),
      ),
      child: Row(children: [
        Expanded(
          flex: 2,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isTotal ? FontWeight.w800 : FontWeight.w700,
                  color: BigDoggTheme.teal800)),
        ),
        Expanded(
          flex: 3,
          child: Text(_euros(owed),
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isTotal ? FontWeight.w800 : FontWeight.w500)),
        ),
        Expanded(
          flex: 3,
          child: Text('−${_euros(vrb)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 12,
                  color: BigDoggTheme.success,
                  fontWeight:
                      isTotal ? FontWeight.w800 : FontWeight.w500)),
        ),
        Expanded(
          flex: 3,
          child: Text(_euros(pay),
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isTotal ? FontWeight.w900 : FontWeight.w700,
                  color: BigDoggTheme.gold600)),
        ),
      ]),
    );
  }

  Widget _korCard(Map<String, dynamic> o) {
    final ratio = _asDouble(o['kor_ratio']);
    final revenue = _asDouble(o['revenue_ex']);
    final threshold = _asDouble(o['kor_threshold']);
    final pct = (ratio * 100).clamp(0, 100).toStringAsFixed(1);
    final overThreshold = revenue >= threshold;
    return Container(
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
            Icon(
                overThreshold
                    ? Icons.warning_amber_rounded
                    : Icons.shield_outlined,
                size: 16,
                color: overThreshold
                    ? BigDoggTheme.gold600
                    : BigDoggTheme.teal700),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                  t('KOR (Kleineondernemersregeling)',
                      'KOR (Small Business Scheme)'),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: BigDoggTheme.teal800)),
            ),
            Text('$pct%',
                style: const TextStyle(
                    fontSize: 13,
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
              valueColor: AlwaysStoppedAnimation(overThreshold
                  ? BigDoggTheme.gold500
                  : BigDoggTheme.success),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_euros(revenue)} ${t("van drempel", "of threshold")} ${_euros(threshold)} ${t("(excl. BTW)", "(excl. VAT)")}',
            style: const TextStyle(
                fontSize: 11,
                color: BigDoggTheme.lightTextSecondary),
          ),
          if (overThreshold) ...[
            const SizedBox(height: 8),
            Text(
              t(
                  '⚠ Omzet boven KOR-drempel — klant is BTW-plichtig.',
                  '⚠ Revenue above KOR threshold — client is VAT-liable.'),
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: BigDoggTheme.gold600),
            ),
          ],
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
                  color: color),
              overflow: TextOverflow.ellipsis),
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
                  border:
                      Border.all(color: BigDoggTheme.lightBorder),
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
                      style:
                          const TextStyle(fontSize: 15, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BigDoggTheme.teal800,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
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

class _QCell extends StatelessWidget {
  final String text;
  final int flex;
  final TextAlign align;
  const _QCell(this.text,
      {this.flex = 1, this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Text(
          text,
          textAlign: align,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: BigDoggTheme.lightTextSecondary,
          ),
        ),
      );
}

class _SCell extends StatelessWidget {
  final String text;
  final int flex;
  final TextAlign align;
  const _SCell(this.text,
      {this.flex = 1, this.align = TextAlign.left});

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
