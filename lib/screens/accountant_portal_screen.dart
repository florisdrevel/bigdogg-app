import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/accountants_service.dart';
import '../theme.dart';

/// Token-gated read-only portal at `/accountant/portal/:token`.
/// No login. No account. Just the data.
///
/// Three tabs: Overzicht / Facturen / Kosten. Per-invoice PDF download
/// opens the backend pdf endpoint in a new tab / external app.
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
  bool _loading = true;
  bool _valid = false;
  String? _error;
  Map<String, dynamic> _meta = {};
  Map<String, dynamic>? _overview;
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _expenses = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final metaResult = await AccountantsService.portalMeta(widget.token);
    if (!mounted) return;
    if (metaResult['ok'] != true) {
      setState(() {
        _loading = false;
        _valid = false;
        _error = metaResult['error']?.toString() ?? 'lookup_failed';
      });
      return;
    }
    _meta = (metaResult['meta'] as Map?)?.cast<String, dynamic>() ?? {};

    final results = await Future.wait([
      AccountantsService.portalOverview(widget.token),
      AccountantsService.portalInvoices(widget.token),
      AccountantsService.portalExpenses(widget.token),
    ]);
    if (!mounted) return;
    setState(() {
      _overview = results[0] as Map<String, dynamic>?;
      _invoices = results[1] as List<Map<String, dynamic>>;
      _expenses = results[2] as List<Map<String, dynamic>>;
      _valid = true;
      _loading = false;
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
      if (diff < 0) return 'Verlopen';
      if (diff == 0) return 'Verloopt vandaag';
      if (diff == 1) return 'Verloopt morgen';
      return 'Verloopt over $diff dagen';
    } catch (_) {
      return '';
    }
  }

  Future<void> _downloadInvoicePdf(String invoiceId, String invoiceNumber) async {
    final url = AccountantsService.portalInvoicePdfUrl(
        widget.token, invoiceId);
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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

  Future<void> _downloadReceipt(String receiptUrl) async {
    try {
      await launchUrl(Uri.parse(receiptUrl),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: receiptUrl));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        duration: Duration(seconds: 4),
        content: Text('Kon bonnetje niet openen — link gekopieerd.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: BigDoggTheme.lightBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_valid) {
      return _invalidScreen();
    }
    return _portalScreen();
  }

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

  Widget _portalScreen() {
    final ownerName =
        (_meta['owner_name'] ?? '').toString().trim().isEmpty
            ? 'BigDogg-gebruiker'
            : (_meta['owner_name']).toString();
    final businessName = (_meta['business_name'] ?? '').toString();
    final kvk = (_meta['kvk_number'] ?? '').toString();
    final btw = (_meta['btw_number'] ?? '').toString();
    final daysLeft = _daysLeft();

    return Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: BigDoggTheme.teal800,
            foregroundColor: Colors.white,
            expandedHeight: 156,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 56),
              title: const Text(
                'Accountantsportaal',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
              background: Container(
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 56),
                decoration: const BoxDecoration(color: BigDoggTheme.teal800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ownerName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: BigDoggTheme.gold500,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (businessName.isNotEmpty &&
                        businessName != ownerName) ...[
                      const SizedBox(height: 2),
                      Text(businessName,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFFF5F3EF))),
                    ],
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      children: [
                        if (kvk.isNotEmpty)
                          Text('KvK $kvk',
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFFC9A96E))),
                        if (btw.isNotEmpty)
                          Text('BTW $btw',
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFFC9A96E))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: BigDoggTheme.lightSurface,
                child: Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        controller: _tabs,
                        labelColor: BigDoggTheme.teal800,
                        unselectedLabelColor:
                            BigDoggTheme.lightTextSecondary,
                        indicatorColor: BigDoggTheme.gold500,
                        labelStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                        tabs: const [
                          Tab(text: 'Overzicht'),
                          Tab(text: 'Facturen'),
                          Tab(text: 'Kosten'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            if (daysLeft.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                color: BigDoggTheme.gold500.withOpacity(0.18),
                child: Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 14, color: BigDoggTheme.teal800),
                    const SizedBox(width: 6),
                    Text(
                      daysLeft,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: BigDoggTheme.teal800),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _overviewTab(),
                  _invoicesTab(),
                  _expensesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _overviewTab() {
    final o = _overview ?? {};
    final year = o['year']?.toString() ?? DateTime.now().year.toString();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Jaar $year',
              style: const TextStyle(
                  fontSize: 13,
                  color: BigDoggTheme.lightTextSecondary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _statCard(
              label: 'Omzet (excl. BTW)',
              value: _euros(o['revenue_excl']),
              color: BigDoggTheme.success,
              icon: Icons.trending_up),
          _statCard(
              label: 'Kosten (excl. BTW)',
              value: _euros(o['expense_excl']),
              color: BigDoggTheme.error,
              icon: Icons.trending_down),
          _statCard(
              label: 'Winst (excl. BTW)',
              value: _euros(o['profit_excl']),
              color: BigDoggTheme.teal800,
              icon: Icons.account_balance_wallet_outlined),
          const SizedBox(height: 8),
          const Text('BTW',
              style: TextStyle(
                  fontSize: 13,
                  color: BigDoggTheme.lightTextSecondary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _statCard(
              label: 'Geïnd op verkopen',
              value: _euros(o['btw_collected']),
              color: BigDoggTheme.teal700,
              icon: Icons.arrow_downward),
          _statCard(
              label: 'Betaald op kosten',
              value: _euros(o['btw_paid']),
              color: BigDoggTheme.teal700,
              icon: Icons.arrow_upward),
          _statCard(
              label: 'Af te dragen aan Belastingdienst',
              value: _euros(o['btw_payable']),
              color: BigDoggTheme.gold600,
              icon: Icons.balance),
          const SizedBox(height: 8),
          const Text('Aantallen',
              style: TextStyle(
                  fontSize: 13,
                  color: BigDoggTheme.lightTextSecondary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
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
          ]),
        ],
      ),
    );
  }

  Widget _invoicesTab() {
    if (_invoices.isEmpty) {
      return _emptyState(
          'Nog geen facturen', Icons.receipt_long_outlined);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _invoices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          final inv = _invoices[i];
          final num = (inv['invoice_number'] ?? '').toString();
          final clientName = (inv['client_name'] ??
                  inv['client_company'] ??
                  '—')
              .toString();
          final issue = (inv['issue_date'] ?? '').toString();
          final status = (inv['status'] ?? '').toString().toLowerCase();
          final paid = status == 'paid';
          final total = inv['total_incl_btw'];
          final id = (inv['id'] ?? '').toString();
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
                          paid ? 'Betaald' : (status.isEmpty ? 'Open' : status),
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
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
            ]),
          );
        },
      ),
    );
  }

  Widget _expensesTab() {
    if (_expenses.isEmpty) {
      return _emptyState(
          'Nog geen kosten', Icons.shopping_bag_outlined);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _expenses.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          final e = _expenses[i];
          final vendor = (e['vendor'] ?? '').toString();
          final desc = (e['description'] ?? '').toString();
          final date = (e['expense_date'] ?? '').toString();
          final amount = e['amount_incl_btw'];
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
                    Text(
                      vendor.isNotEmpty ? vendor : (desc.isEmpty ? '—' : desc),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: BigDoggTheme.teal800),
                    ),
                    if (vendor.isNotEmpty && desc.isNotEmpty)
                      Text(desc,
                          style: const TextStyle(
                              fontSize: 12,
                              color: BigDoggTheme.lightTextPrimary)),
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
                                color: BigDoggTheme.lightTextSecondary)),
                      ],
                    ]),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_euros(amount),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: BigDoggTheme.error)),
                  if (receipt.isNotEmpty)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: BigDoggTheme.teal700,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _downloadReceipt(receipt),
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

  Widget _statCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: BigDoggTheme.lightTextPrimary)),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }

  Widget _countTile({required String label, required String value}) {
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
  }

  Widget _emptyState(String text, IconData icon) {
    return Center(
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
  }
}
