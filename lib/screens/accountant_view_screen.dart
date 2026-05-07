import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/accountants_service.dart';
import '../theme.dart';

String _euros(dynamic v) {
  final n = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
  final sign = n < 0 ? '-' : '';
  final abs = n.abs();
  final whole = abs.truncate();
  final cents = ((abs - whole) * 100).round().toString().padLeft(2, '0');
  final wholeStr = whole.toString();
  final groups = <String>[];
  for (var i = wholeStr.length; i > 0; i -= 3) {
    groups.insert(0, wholeStr.substring(i - 3 < 0 ? 0 : i - 3, i));
  }
  return '$sign€ ${groups.join('.')},$cents';
}

/// Read-only accountant view of a single BigDogg-user's administration.
/// Three tabs: Overzicht (revenue / expense / VAT summary), Facturen,
/// Kosten. The accountant cannot edit anything — list rendering only.
class AccountantViewScreen extends StatefulWidget {
  final String clientUserId;
  final String clientDisplayName;
  const AccountantViewScreen({
    super.key,
    required this.clientUserId,
    required this.clientDisplayName,
  });

  @override
  State<AccountantViewScreen> createState() => _AccountantViewScreenState();
}

class _AccountantViewScreenState extends State<AccountantViewScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Map<String, dynamic>? _overview;
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _expenses = [];
  bool _loading = true;

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
    final results = await Future.wait([
      AccountantsService.clientOverview(widget.clientUserId),
      AccountantsService.clientInvoices(widget.clientUserId),
      AccountantsService.clientExpenses(widget.clientUserId),
    ]);
    if (!mounted) return;
    setState(() {
      _overview = results[0] as Map<String, dynamic>?;
      _invoices = results[1] as List<Map<String, dynamic>>;
      _expenses = results[2] as List<Map<String, dynamic>>;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      appBar: AppBar(
        backgroundColor: BigDoggTheme.teal800,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.clientDisplayName.isEmpty
                  ? 'BigDogg-gebruiker'
                  : widget.clientDisplayName,
              style: const TextStyle(fontSize: 16),
            ),
            const Text(
              'Alleen-lezen',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/accountant'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Vernieuwen',
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: BigDoggTheme.gold500,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overzicht'),
            Tab(text: 'Facturen'),
            Tab(text: 'Kosten'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabs, children: [
              _overviewTab(),
              _invoicesTab(),
              _expensesTab(),
            ]),
    );
  }

  Widget _statCard(String label, String value,
      {Color? color, IconData? icon, String? sub}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color ?? BigDoggTheme.teal700),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: BigDoggTheme.lightTextSecondary)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color ?? BigDoggTheme.teal800,
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 2),
          Text(sub,
              style: const TextStyle(
                  fontSize: 11, color: BigDoggTheme.lightTextHint)),
        ],
      ]),
    );
  }

  Widget _overviewTab() {
    final o = _overview;
    if (o == null) {
      return const Center(child: Text('Geen overzicht beschikbaar'));
    }
    final year = o['year'];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Boekjaar $year',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: BigDoggTheme.teal800)),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: [
              _statCard('Omzet (excl. BTW)',
                  _euros(o['revenue_excl'] ?? 0),
                  icon: Icons.trending_up, color: BigDoggTheme.success,
                  sub: '${o['paid_count'] ?? 0} van ${o['invoice_count'] ?? 0} betaald'),
              _statCard('Kosten (excl. BTW)',
                  _euros(o['expense_excl'] ?? 0),
                  icon: Icons.shopping_cart_outlined,
                  sub: '${o['expense_count'] ?? 0} kostenposten'),
              _statCard('Winst (excl. BTW)',
                  _euros(o['profit_excl'] ?? 0),
                  icon: Icons.account_balance_wallet_outlined,
                  color: BigDoggTheme.teal800),
              _statCard('BTW te betalen',
                  _euros(o['btw_payable'] ?? 0),
                  icon: Icons.gavel_outlined,
                  color: ((o['btw_payable'] ?? 0) as num) > 0
                      ? BigDoggTheme.warning
                      : BigDoggTheme.success),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BigDoggTheme.lightSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BigDoggTheme.lightBorder),
            ),
            child: Column(children: [
              _kvRow('Omzet incl. BTW', _euros(o['revenue_incl'] ?? 0)),
              _kvRow('BTW geïncasseerd',
                  _euros(o['btw_collected'] ?? 0)),
              _kvRow('BTW betaald', _euros(o['btw_paid'] ?? 0)),
              _kvRow('Kosten incl. BTW',
                  _euros(o['expense_incl'] ?? 0)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _kvRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(
              child: Text(k,
                  style: const TextStyle(
                      fontSize: 13,
                      color: BigDoggTheme.lightTextSecondary))),
          Text(v,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: BigDoggTheme.lightTextPrimary)),
        ]),
      );

  Widget _invoicesTab() {
    if (_invoices.isEmpty) {
      return const Center(child: Text('Geen facturen in dit boekjaar'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _invoices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          final inv = _invoices[i];
          final status = (inv['status'] ?? '').toString().toLowerCase();
          Color statusColor = BigDoggTheme.lightTextSecondary;
          String statusLabel = status;
          if (status == 'paid') {
            statusColor = BigDoggTheme.success;
            statusLabel = 'betaald';
          } else if (status == 'sent') {
            statusColor = BigDoggTheme.info;
            statusLabel = 'verstuurd';
          } else if (status == 'overdue') {
            statusColor = BigDoggTheme.error;
            statusLabel = 'te laat';
          } else if (status == 'draft') {
            statusLabel = 'concept';
          }
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
                  Expanded(
                    child: Text(
                      inv['invoice_number']?.toString() ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: BigDoggTheme.teal800),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(statusLabel,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  ((inv['client_company'] ?? '').toString().isNotEmpty
                      ? inv['client_company']
                      : (inv['client_name'] ?? '')).toString(),
                  style: const TextStyle(
                      fontSize: 13, color: BigDoggTheme.lightTextPrimary),
                ),
                const SizedBox(height: 2),
                Row(children: [
                  Text(
                    'Datum: ${inv['issue_date'] ?? ''}',
                    style: const TextStyle(
                        fontSize: 11, color: BigDoggTheme.lightTextSecondary),
                  ),
                  const Spacer(),
                  Text(
                    _euros(inv['total_incl_btw'] ?? 0),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: BigDoggTheme.teal800),
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _expensesTab() {
    if (_expenses.isEmpty) {
      return const Center(child: Text('Geen kosten in dit boekjaar'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _expenses.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          final ex = _expenses[i];
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
                  Expanded(
                    child: Text(
                      (ex['vendor'] ?? '').toString(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: BigDoggTheme.teal800),
                    ),
                  ),
                  Text(
                    _euros(ex['amount_incl_btw'] ?? 0),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: BigDoggTheme.teal800),
                  ),
                ]),
                const SizedBox(height: 2),
                Text(
                  (ex['description'] ?? '').toString(),
                  style: const TextStyle(
                      fontSize: 12, color: BigDoggTheme.lightTextPrimary),
                ),
                const SizedBox(height: 2),
                Row(children: [
                  Text(
                    (ex['category'] ?? '').toString(),
                    style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: BigDoggTheme.lightTextSecondary),
                  ),
                  const Spacer(),
                  Text(
                    (ex['expense_date'] ?? '').toString(),
                    style: const TextStyle(
                        fontSize: 11, color: BigDoggTheme.lightTextSecondary),
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }
}
