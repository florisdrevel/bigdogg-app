import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/accountants_service.dart';
import '../theme.dart';

/// Token-gated read-only portal at `/accountant/portal/:token`. No login.
/// Five tabs: Overzicht / Facturen / Kosten / Investering / Uren.
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
  Map<String, dynamic> _meta = {};
  List<int> _years = [];
  int _year = DateTime.now().year;
  Map<String, dynamic>? _overview;
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _expenses = [];
  Map<String, dynamic>? _investments;
  Map<String, dynamic>? _hours;
  final Set<String> _expandedInvoices = {};

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
    ]);
    if (!mounted) return;
    setState(() {
      _overview    = results[0] as Map<String, dynamic>?;
      _invoices    = results[1] as List<Map<String, dynamic>>;
      _expenses    = results[2] as List<Map<String, dynamic>>;
      _investments = results[3] as Map<String, dynamic>?;
      _hours       = results[4] as Map<String, dynamic>?;
      _expandedInvoices.clear();
      _yearLoading = false;
    });
  }

  String _humanizeError(String code) {
    switch (code) {
      case 'link_not_found':
      case 'not_found':
        return 'Deze toegangslink bestaat niet (meer).';
      case 'link_expired':
      case 'expired':
        return 'Deze link is verlopen — vraag de eigenaar om een nieuwe.';
      case 'link_revoked':
      case 'revoked':
      case 'already_used':
        return 'De eigenaar heeft deze toegang ingetrokken.';
      default:
        return 'Er ging iets mis: $code';
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

  String _daysLeft() {
    final expRaw = _meta['expires_at']?.toString();
    if (expRaw == null || expRaw.isEmpty) return '';
    try {
      final exp = DateTime.parse(expRaw);
      final diff = exp.difference(DateTime.now()).inDays;
      if (diff < 0) return 'Toegang verlopen';
      if (diff == 0) return 'Toegang vervalt vandaag';
      if (diff == 1) return 'Toegang vervalt morgen';
      return 'Toegang vervalt over $diff dagen';
    } catch (_) {
      return '';
    }
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
        content: Text(
            'Kon PDF $invoiceNumber niet openen — link gekopieerd, plak in browser.'),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        duration: Duration(seconds: 4),
        content: Text('Kon bonnetje niet openen — link gekopieerd.'),
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

    return Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
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
            ? 'BigDogg-gebruiker'
            : (_meta['owner_name']).toString();
    final kvk = (_meta['kvk_number'] ?? '').toString();
    final btw = (_meta['btw_number'] ?? '').toString();
    final daysLeft = _daysLeft();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
      decoration: const BoxDecoration(color: BigDoggTheme.teal800),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BigDogg · Accountantsportaal',
            style: TextStyle(
              color: Color(0xFFC9A96E),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
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
          if (daysLeft.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.access_time,
                  size: 12, color: Color(0xFFC9A96E)),
              const SizedBox(width: 4),
              Text(
                daysLeft,
                style: const TextStyle(
                    color: Color(0xFFC9A96E),
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ],
        ],
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
        tabs: const [
          Tab(text: 'Overzicht'),
          Tab(text: 'Facturen'),
          Tab(text: 'Kosten'),
          Tab(text: 'Investeringen'),
          Tab(text: 'Uren'),
        ],
      ),
    );
  }

  // ── Tabs ──────────────────────────────────────────────────
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
                'Geen facturen of kosten geboekt in $_year.',
                Icons.inbox_outlined)
          else ...[
            _kpiGrid(o),
            const SizedBox(height: 16),
            _korMeter(o),
            const SizedBox(height: 16),
            _sectionTitle('Per kwartaal'),
            _quartersTable(o),
            const SizedBox(height: 16),
            _sectionTitle('Kosten per categorie'),
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
      _KpiData('Omzet (excl. BTW)', _euros(o['revenue_ex']),
          BigDoggTheme.success, Icons.trending_up),
      _KpiData('Kosten (excl. BTW)', _euros(o['expense_ex']),
          BigDoggTheme.error, Icons.trending_down),
      _KpiData('Winst (excl. BTW)', _euros(o['profit_ex']),
          BigDoggTheme.teal800, Icons.account_balance_wallet_outlined),
      _KpiData('BTW af te dragen', _euros(o['btw_payable']),
          BigDoggTheme.gold600, Icons.balance),
      _KpiData('BTW geïnd', _euros(o['btw_collected']),
          BigDoggTheme.teal700, Icons.arrow_downward),
      _KpiData('BTW betaald', _euros(o['btw_paid']),
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
          .map((t) => Container(
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
                      Icon(t.icon, size: 14, color: t.color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(t.label,
                            style: const TextStyle(
                                fontSize: 11,
                                color: BigDoggTheme.lightTextSecondary,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(t.value,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: t.color)),
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
            const Expanded(
              child: Text('KOR-drempel',
                  style: TextStyle(
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
            '${_euros(revenue)} van ${_euros(threshold)}',
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
            decoration: BoxDecoration(
              color: BigDoggTheme.lightBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(children: const [
              _QCell('Kw.', flex: 1),
              _QCell('Omzet', flex: 3, align: TextAlign.right),
              _QCell('BTW in', flex: 2, align: TextAlign.right),
              _QCell('BTW uit', flex: 2, align: TextAlign.right),
              _QCell('Af te dragen', flex: 3, align: TextAlign.right),
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
        ],
      ),
    );
  }

  Widget _categoriesList(Map<String, dynamic> o) {
    final cats = (o['categories'] as List?) ?? [];
    if (cats.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BigDoggTheme.lightSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: BigDoggTheme.lightBorder),
        ),
        child: const Text('Geen kosten geboekt.',
            style: TextStyle(
                fontSize: 12,
                color: BigDoggTheme.lightTextSecondary)),
      );
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
                      top:
                          BorderSide(color: BigDoggTheme.lightBorder),
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
              label: 'Facturen',
              value: o['invoice_count']?.toString() ?? '0')),
      const SizedBox(width: 8),
      Expanded(
          child: _countTile(
              label: 'Betaald',
              value: o['paid_count']?.toString() ?? '0')),
      const SizedBox(width: 8),
      Expanded(
          child: _countTile(
              label: 'Kosten',
              value: o['expense_count']?.toString() ?? '0')),
    ]);
  }

  Widget _invoicesTab() {
    if (_invoices.isEmpty) {
      return _emptyState(
          'Geen facturen in $_year', Icons.receipt_long_outlined);
    }
    return RefreshIndicator(
      onRefresh: () => _loadYear(_year),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _invoices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) => _invoiceTile(_invoices[i]),
      ),
    );
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
    final total = inv['total_incl_btw'];
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
                                ? 'Betaald'
                                : (status.isEmpty ? 'Open' : status),
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
                    Text(_euros(total),
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: BigDoggTheme.teal800)),
                    const SizedBox(height: 4),
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
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(
                'Geen factuurregels gevonden.',
                style: TextStyle(
                    fontSize: 11,
                    color: BigDoggTheme.lightTextSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _expensesTab() {
    if (_expenses.isEmpty) {
      return _emptyState(
          'Geen kosten in $_year', Icons.shopping_bag_outlined);
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
                        'excl. ${_euros(amountEx)} · BTW ${_euros(btw)}',
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
                      label: const Text('Bon',
                          style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _investmentsTab() {
    final data = _investments;
    final items = (data?['investments'] as List?) ?? [];
    if (items.isEmpty) {
      return _emptyState('Geen investeringen geregistreerd',
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
              const Expanded(
                child: Text('Afschrijving dit jaar',
                    style: TextStyle(
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
            final desc = (m['description'] ?? '—').toString();
            final purchase = (m['purchase_date'] ?? '').toString();
            final years = m['depreciation_years'];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BigDoggTheme.lightSurface,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: BigDoggTheme.lightBorder),
              ),
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
                  ]),
                  const SizedBox(height: 2),
                  Text(
                      'Aangeschaft $purchase · $years jaar afschrijving',
                      style: const TextStyle(
                          fontSize: 11,
                          color: BigDoggTheme.lightTextSecondary)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: _depCell(
                            label: 'Dit jaar',
                            value: _euros(m['this_year_depreciation']),
                            color: BigDoggTheme.gold600)),
                    Expanded(
                        child: _depCell(
                            label: 'Cumulatief',
                            value: _euros(m['cumulative_depreciation']),
                            color: BigDoggTheme.error)),
                    Expanded(
                        child: _depCell(
                            label: 'Restwaarde',
                            value: _euros(m['book_value']),
                            color: BigDoggTheme.success)),
                  ]),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _hoursTab() {
    final h = _hours;
    final total = h?['total_hours'];
    final ratio = (h?['urencriterium_ratio'] is num)
        ? (h!['urencriterium_ratio'] as num).toDouble()
        : 0.0;
    final urencriterium = h?['urencriterium'] ?? 1225;
    final summary = (h?['project_summary'] as List?) ?? [];
    return RefreshIndicator(
      onRefresh: () => _loadYear(_year),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
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
                  const Expanded(
                    child: Text('Urencriterium',
                        style: TextStyle(
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
                  '${total ?? 0} van $urencriterium uur',
                  style: const TextStyle(
                      fontSize: 12,
                      color: BigDoggTheme.lightTextSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionTitle('Uren per project'),
          if (summary.isEmpty)
            _emptyHint('Geen uren geregistreerd in $_year.',
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
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: summary.first == p
                          ? null
                          : const Border(
                              top: BorderSide(
                                  color:
                                      BigDoggTheme.lightBorder),
                            ),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          (m['project_name'] ?? '—').toString(),
                          style: const TextStyle(
                              fontSize: 13,
                              color: BigDoggTheme.lightTextPrimary),
                        ),
                      ),
                      Text(
                        '${m['hours']} u',
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

  // ── shared bits ───────────────────────────────────────────
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
                        child: const Text('Naar BigDogg'),
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
