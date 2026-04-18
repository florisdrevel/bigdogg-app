import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/overview_service.dart';
import '../services/invoices_service.dart';
import '../services/api_config.dart';
import '../providers/app_provider.dart';
import '../theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Invoice Detail Sheet — shows invoice data inline when no PDF is available
// ─────────────────────────────────────────────────────────────────────────────

class _InvoiceDetailSheet extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final bool isNl;

  const _InvoiceDetailSheet({required this.invoice, required this.isNl});

  String _statusLabel(String status) {
    switch (status) {
      case 'paid': return isNl ? 'Betaald' : 'Paid';
      case 'sent': return isNl ? 'Verstuurd' : 'Sent';
      case 'overdue': return isNl ? 'Verlopen' : 'Overdue';
      default: return isNl ? 'Concept' : 'Draft';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid': return BigDoggTheme.success;
      case 'sent': return BigDoggTheme.info;
      case 'overdue': return BigDoggTheme.error;
      default: return BigDoggTheme.lightTextSecondary;
    }
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: BigDoggTheme.lightTextSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color ?? BigDoggTheme.lightTextPrimary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = invoice['status'] ?? 'draft';
    final clientName = invoice['clients']?['contact_name'] ??
        invoice['client_name'] ??
        (isNl ? 'Verwijderde klant' : 'Deleted client');
    final subtotal = invoice['subtotal_ex_btw'] ?? 0.0;
    final btw = invoice['btw_amount'] ?? 0.0;
    final total = invoice['total_incl_btw'] ?? 0.0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  invoice['invoice_number'] ?? '',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: BigDoggTheme.teal800,
                      fontFamily: 'PlusJakartaSans'),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _statusColor(status)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Divider(color: Colors.grey[200]),
          const SizedBox(height: 8),
          // Details
          _row(isNl ? 'Klant' : 'Client', clientName),
          _row(isNl ? 'Datum' : 'Date', invoice['invoice_date'] ?? ''),
          const Divider(height: 24),
          _row(isNl ? 'Subtotaal ex BTW' : 'Subtotal ex VAT',
              '\u20ac${subtotal is num ? subtotal.toStringAsFixed(2) : subtotal}'),
          _row(isNl ? 'BTW' : 'VAT',
              '\u20ac${btw is num ? btw.toStringAsFixed(2) : btw}'),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: BigDoggTheme.teal800.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: BigDoggTheme.teal800.withOpacity(0.15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isNl ? 'Totaal incl BTW' : 'Total incl VAT',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: BigDoggTheme.teal800),
                ),
                Text(
                  '\u20ac${total is num ? total.toStringAsFixed(2) : total}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: BigDoggTheme.teal800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: BigDoggTheme.teal800),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(isNl ? 'Sluiten' : 'Close',
                  style: const TextStyle(color: BigDoggTheme.teal800)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quarter Detail Sheet — shows invoices + expenses that make up a quarter
// ─────────────────────────────────────────────────────────────────────────────

class _QuarterDetailSheet extends StatefulWidget {
  final int quarter;
  final int year;
  final bool isNl;

  const _QuarterDetailSheet({
    required this.quarter,
    required this.year,
    required this.isNl,
  });

  @override
  State<_QuarterDetailSheet> createState() => _QuarterDetailSheetState();
}

class _QuarterDetailSheetState extends State<_QuarterDetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<dynamic> _invoices = [];
  List<dynamic> _expenses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await OverviewService.getQuarterDetail(
      quarter: widget.quarter,
      year: widget.year,
    );
    if (mounted) {
      setState(() {
        _loading = false;
        if (result['success']) {
          _invoices = result['invoices'] ?? [];
          _expenses = result['expenses'] ?? [];
        }
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid': return BigDoggTheme.success;
      case 'sent': return BigDoggTheme.info;
      case 'overdue': return BigDoggTheme.error;
      default: return BigDoggTheme.lightTextSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid': return widget.isNl ? 'Betaald' : 'Paid';
      case 'sent': return widget.isNl ? 'Verstuurd' : 'Sent';
      case 'overdue': return widget.isNl ? 'Verlopen' : 'Overdue';
      default: return widget.isNl ? 'Concept' : 'Draft';
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showInvoiceDetail(Map<String, dynamic> inv) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _InvoiceDetailSheet(
        invoice: inv,
        isNl: widget.isNl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNl = widget.isNl;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Text(
                  'Q${widget.quarter} ${widget.year}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: BigDoggTheme.teal800,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Tabs
          Container(
            color: BigDoggTheme.teal800,
            child: TabBar(
              controller: _tab,
              indicatorColor: BigDoggTheme.gold500,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: BigDoggTheme.teal400,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontFamily: 'PlusJakartaSans'),
              tabs: [
                Tab(
                    text: isNl
                        ? 'Facturen (${_invoices.length})'
                        : 'Invoices (${_invoices.length})'),
                Tab(
                    text: isNl
                        ? 'Kosten (${_expenses.length})'
                        : 'Expenses (${_expenses.length})'),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tab,
                    children: [
                      // ── Invoices tab ──────────────────────────
                      _invoices.isEmpty
                          ? _emptyState(
                              isNl
                                  ? 'Geen facturen dit kwartaal'
                                  : 'No invoices this quarter',
                              Icons.receipt_long_outlined)
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _invoices.length,
                              itemBuilder: (context, i) {
                                final inv = _invoices[i];
                                final status = inv['status'] ?? 'draft';
                                final clientName =
                                    inv['clients']?['contact_name'] ??
                                        inv['client_name'] ??
                                        (isNl
                                            ? 'Verwijderde klant'
                                            : 'Deleted client');
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: BigDoggTheme.lightSurface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: BigDoggTheme.lightBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  inv['invoice_number'] ?? '',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: _statusColor(status)
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(5),
                                                  ),
                                                  child: Text(
                                                    _statusLabel(status),
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        color:
                                                            _statusColor(status),
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(clientName,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: BigDoggTheme
                                                        .lightTextSecondary)),
                                            Text(inv['invoice_date'] ?? '',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: BigDoggTheme
                                                        .lightTextHint)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '\u20ac${inv['total_incl_btw'] ?? '0'}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: BigDoggTheme.teal800),
                                          ),
                                          // Show "See file" for pdf_url, "View" for imported
                                          if (inv['pdf_url'] != null)
                                            TextButton(
                                              style: TextButton.styleFrom(
                                                padding: EdgeInsets.zero,
                                                minimumSize: const Size(0, 28),
                                              ),
                                              onPressed: () => _openUrl(
                                                  inv['pdf_url'] as String),
                                              child: Text(
                                                isNl ? 'Zie bestand' : 'See file',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: BigDoggTheme.teal700),
                                              ),
                                            )
                                          else
                                            TextButton(
                                              style: TextButton.styleFrom(
                                                padding: EdgeInsets.zero,
                                                minimumSize: const Size(0, 28),
                                              ),
                                              onPressed: () =>
                                                  _showInvoiceDetail(inv),
                                              child: Text(
                                                isNl ? 'Bekijk' : 'View',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: BigDoggTheme.teal700),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                      // ── Expenses tab ──────────────────────────
                      _expenses.isEmpty
                          ? _emptyState(
                              isNl
                                  ? 'Geen kosten dit kwartaal'
                                  : 'No expenses this quarter',
                              Icons.receipt_outlined)
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _expenses.length,
                              itemBuilder: (context, i) {
                                final exp = _expenses[i];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: BigDoggTheme.lightSurface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: BigDoggTheme.lightBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              exp['description'] ??
                                                  (isNl
                                                      ? 'Geen omschrijving'
                                                      : 'No description'),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              exp['category'] ?? '',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: BigDoggTheme
                                                      .lightTextSecondary),
                                            ),
                                            Text(
                                              exp['expense_date'] ?? '',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      BigDoggTheme.lightTextHint),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '\u20ac${exp['total_incl_btw'] ?? exp['amount'] ?? '0'}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: BigDoggTheme.teal800),
                                          ),
                                          if (exp['receipt_url'] != null)
                                            TextButton(
                                              style: TextButton.styleFrom(
                                                padding: EdgeInsets.zero,
                                                minimumSize: const Size(0, 28),
                                              ),
                                              onPressed: () => _openUrl(
                                                  exp['receipt_url'] as String),
                                              child: Text(
                                                isNl ? 'Zie bestand' : 'See file',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: BigDoggTheme.teal700),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: BigDoggTheme.lightTextHint),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(
                  fontSize: 15, color: BigDoggTheme.lightTextSecondary)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main OverviewScreen
// ─────────────────────────────────────────────────────────────────────────────

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
  int _selectedYear = DateTime.now().year;

  int get _minYear => DateTime.now().year - 25;

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

  Future<void> _downloadBtwReport(bool isNl,
      {int? quarter, int? year}) async {
    final token = await InvoicesService.getToken();
    final lang = isNl ? 'nl' : 'en';
    String url =
        '${ApiConfig.baseUrl}/api/v1/reports/btw/pdf?token=$token&lang=$lang';
    if (quarter != null && year != null) {
      url += '&quarter=$quarter&year=$year';
    }
    final uri = Uri.parse(url);
    try {
      await _launchUrl(uri);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isNl
              ? 'Kan rapport niet openen'
              : 'Could not open report'),
          backgroundColor: BigDoggTheme.error,
        ));
      }
    }
  }

  Future<void> _launchUrl(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _onDownloadAnnualReportTapped(bool isNl, int year) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: BigDoggTheme.teal800.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.picture_as_pdf_outlined,
                    size: 34, color: BigDoggTheme.teal800),
              ),
              const SizedBox(height: 20),
              Text(
                isNl ? 'Rapport wordt geopend' : 'Opening report',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: BigDoggTheme.teal800,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isNl
                    ? 'Je jaarrapport $year wordt geopend als PDF in een nieuw tabblad.'
                    : 'Your $year annual report is opening as a PDF in a new tab.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BigDoggTheme.teal800,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    isNl ? 'Sluiten' : 'Close',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'PlusJakartaSans'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final token = await InvoicesService.getToken();
    final lang = isNl ? 'nl' : 'en';
    final url =
        '${ApiConfig.baseUrl}/api/v1/reports/annual/pdf?token=$token&year=$year&lang=$lang';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: BigDoggTheme.teal800.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded,
                  size: 36, color: BigDoggTheme.teal800),
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
                  fontSize: 14, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 16),
            _paywallFeatureRow(Icons.analytics_outlined,
                isNl ? 'Jaarlijkse financiële rapporten' : 'Annual financial reports'),
            _paywallFeatureRow(Icons.upload_file_outlined,
                isNl ? 'Facturen & kosten importeren' : 'Import invoices & expenses'),
            _paywallFeatureRow(Icons.picture_as_pdf_outlined,
                isNl ? 'PDF exports voor alle kwartalen' : 'PDF exports for all quarters'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BigDoggTheme.gold500,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  isNl ? 'Upgraden naar betaald' : 'Upgrade to paid',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'PlusJakartaSans'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isNl ? 'Niet nu' : 'Not now',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14)),
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
          Text(text,
              style: const TextStyle(
                  fontSize: 14, color: BigDoggTheme.lightTextPrimary)),
        ],
      ),
    );
  }

  Widget _yearPicker(bool isNl) {
    final currentYear = DateTime.now().year;
    final years =
        List.generate(currentYear - _minYear + 1, (i) => currentYear - i);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left,
              color: _selectedYear > _minYear ? Colors.white : Colors.white30),
          onPressed: _selectedYear > _minYear
              ? () {
                  setState(() => _selectedYear--);
                  _loadAnnual();
                }
              : null,
        ),
        DropdownButton<int>(
          value: _selectedYear,
          dropdownColor: BigDoggTheme.teal800,
          iconEnabledColor: Colors.white70,
          underline: const SizedBox.shrink(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            fontFamily: 'PlusJakartaSans',
          ),
          items: years
              .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
              .toList(),
          onChanged: (y) {
            if (y != null) {
              setState(() => _selectedYear = y);
              _loadAnnual();
            }
          },
        ),
        IconButton(
          icon: Icon(Icons.chevron_right,
              color:
                  _selectedYear < currentYear ? Colors.white : Colors.white30),
          onPressed: _selectedYear < currentYear
              ? () {
                  setState(() => _selectedYear++);
                  _loadAnnual();
                }
              : null,
        ),
      ],
    );
  }

  void _openQuarterDetail(int quarterNum, bool isNl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, _) => _QuarterDetailSheet(
          quarter: quarterNum,
          year: _selectedYear,
          isNl: isNl,
        ),
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
            labelStyle: const TextStyle(
                fontWeight: FontWeight.w600, fontFamily: 'PlusJakartaSans'),
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
    if (_loadingQuarterly)
      return const Center(child: CircularProgressIndicator());
    if (_quarterly == null)
      return Center(child: Text(isNl ? 'Laden mislukt' : 'Failed to load'));

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
                Text(q['period'],
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                Text('${q['start_date']} \u2014 ${q['end_date']}',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle(isNl ? 'Omzet' : 'Revenue'),
          _overviewCard([
            _overviewRow(isNl ? 'Omzet ex BTW' : 'Revenue ex VAT',
                '\u20ac${q['revenue_ex_btw']}'),
            _overviewRow(isNl ? 'BTW ontvangen' : 'VAT received',
                '\u20ac${q['revenue_btw']}'),
            _overviewRow(isNl ? 'Totaal incl BTW' : 'Total incl VAT',
                '\u20ac${q['revenue_total']}',
                bold: true),
            const Divider(),
            _overviewRow(isNl ? 'Betaald ontvangen' : 'Received',
                '\u20ac${q['paid_revenue']}',
                color: BigDoggTheme.success),
            _overviewRow(isNl ? 'Nog openstaand' : 'Outstanding',
                '\u20ac${q['outstanding']}',
                color: BigDoggTheme.warning),
          ]),
          const SizedBox(height: 16),
          _sectionTitle(isNl ? 'Kosten' : 'Expenses'),
          _overviewCard([
            _overviewRow(isNl ? 'Kosten ex BTW' : 'Expenses ex VAT',
                '\u20ac${q['expenses_ex_btw']}'),
            _overviewRow(
                isNl ? 'BTW betaald' : 'VAT paid', '\u20ac${q['expenses_btw']}'),
            _overviewRow(isNl ? 'Totaal incl BTW' : 'Total incl VAT',
                '\u20ac${q['expenses_total']}',
                bold: true),
          ]),
          const SizedBox(height: 16),
          _sectionTitle('BTW / VAT'),
          _overviewCard([
            _overviewRow(isNl ? 'BTW ontvangen' : 'VAT received',
                '\u20ac${q['revenue_btw']}'),
            _overviewRow(
                isNl ? 'BTW betaald op kosten' : 'VAT paid on expenses',
                '\u20ac${q['expenses_btw']}'),
            const Divider(),
            _overviewRow(
              isNl ? 'Te betalen BTW' : 'VAT to pay',
              '\u20ac${q['btw_to_pay']}',
              bold: true,
              large: true,
              color: (q['btw_to_pay'] as num) > 0
                  ? BigDoggTheme.error
                  : BigDoggTheme.success,
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BigDoggTheme.warningBg,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: BigDoggTheme.warning.withOpacity(0.3)),
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
                    style: const TextStyle(
                        color: Color(0xFF92400E), fontSize: 13),
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
    if (_loadingAnnual)
      return const Center(child: CircularProgressIndicator());
    if (_annual == null)
      return Center(child: Text(isNl ? 'Laden mislukt' : 'Failed to load'));

    final a = _annual!;
    final quarters = a['quarters'] as List;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      Text(
                        isNl ? 'Jaaroverzicht' : 'Annual overview',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isNl ? 'Netto winst' : 'Net profit',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11),
                      ),
                      Text(
                        '\u20ac${a['net_profit_indicative']}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20),
                      ),
                    ],
                  ),
                ),
                _yearPicker(isNl),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle(isNl ? 'Per kwartaal' : 'Per quarter'),
          ...quarters.map((q) => _quarterCard(q, isNl, _selectedYear)),
          const SizedBox(height: 16),
          _sectionTitle(
              isNl ? 'Totaal $_selectedYear' : 'Total $_selectedYear'),
          _overviewCard([
            _overviewRow(
                isNl ? 'Totale omzet ex BTW' : 'Total revenue ex VAT',
                '\u20ac${a['total_revenue_ex_btw']}',
                bold: true),
            _overviewRow(
                isNl ? 'Totale kosten ex BTW' : 'Total expenses ex VAT',
                '\u20ac${a['total_expenses_ex_btw']}'),
            const Divider(),
            _overviewRow(isNl ? 'Netto winst' : 'Net profit',
                '\u20ac${a['net_profit_indicative']}',
                bold: true, large: true),
            _overviewRow(
                isNl ? 'Totale BTW te betalen' : 'Total VAT to pay',
                '\u20ac${a['total_btw_to_pay']}',
                color: BigDoggTheme.error),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  _onDownloadAnnualReportTapped(isNl, _selectedYear),
              icon: const Icon(Icons.picture_as_pdf_outlined,
                  color: Colors.white, size: 20),
              label: Text(
                isNl
                    ? 'Download Jaarrapport $_selectedYear'
                    : 'Download Annual Report $_selectedYear',
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: BigDoggTheme.gold500,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.workspace_premium_outlined,
                  size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                isNl
                    ? 'Alleen beschikbaar voor betaalde gebruikers'
                    : 'Available on paid plan only',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quarterCard(Map q, bool isNl, int year) {
    final quarterNum = q['quarter'] as int;
    return GestureDetector(
      onTap: () => _openQuarterDetail(quarterNum, isNl),
      child: Container(
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
                Text(
                  'Q$quarterNum $year',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: BigDoggTheme.teal800),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () =>
                      _downloadBtwReport(isNl, quarter: quarterNum, year: year),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      border: Border.all(color: BigDoggTheme.teal700),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.download_outlined,
                            size: 13, color: BigDoggTheme.teal700),
                        const SizedBox(width: 4),
                        Text(
                          isNl ? 'BTW PDF' : 'VAT PDF',
                          style: const TextStyle(
                              fontSize: 11,
                              color: BigDoggTheme.teal700,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right,
                    size: 18, color: BigDoggTheme.lightTextSecondary),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: _miniStat(isNl ? 'Omzet' : 'Revenue',
                        '\u20ac${q['revenue_ex_btw']}')),
                Expanded(
                    child: _miniStat(isNl ? 'Kosten' : 'Expenses',
                        '\u20ac${q['expenses_ex_btw']}')),
                Expanded(
                    child: _miniStat(
                        'BTW / VAT', '\u20ac${q['btw_to_pay']}')),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isNl
                  ? 'Tik om facturen & kosten te zien'
                  : 'Tap to see invoices & expenses',
              style: const TextStyle(
                  fontSize: 11, color: BigDoggTheme.lightTextHint),
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
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: BigDoggTheme.lightTextSecondary)),
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