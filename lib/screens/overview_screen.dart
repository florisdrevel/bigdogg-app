import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/overview_service.dart';
import '../services/invoices_service.dart';
import '../services/api_config.dart';
import '../services/offline_queue.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../services/subscription_service.dart';
import '../services/local_storage_service.dart';
import '../widgets/subscription_web_widget.dart';
import '../widgets/offline_chrome.dart';
import '../services/pdf_opener.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Invoice Detail Sheet
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
          Text(label, style: const TextStyle(fontSize: 13, color: BigDoggTheme.lightTextSecondary)),
          Text(value, style: TextStyle(fontSize: 13,
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
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          Row(
            children: [
              Expanded(child: Text(invoice['invoice_number'] ?? '',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: BigDoggTheme.teal800, fontFamily: 'PlusJakartaSans'))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(_statusLabel(status), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _statusColor(status))),
              ),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 4),
          Divider(color: Colors.grey[200]),
          const SizedBox(height: 8),
          _row(isNl ? 'Klant' : 'Client', clientName),
          _row(isNl ? 'Datum' : 'Date', invoice['invoice_date'] ?? ''),
          const Divider(height: 24),
          _row(isNl ? 'Subtotaal ex BTW' : 'Subtotal ex VAT',
              '\u20ac${subtotal is num ? subtotal.toStringAsFixed(2) : subtotal}'),
          _row('BTW / VAT', '\u20ac${btw is num ? btw.toStringAsFixed(2) : btw}'),
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
                Text(isNl ? 'Totaal incl BTW' : 'Total incl VAT',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: BigDoggTheme.teal800)),
                Text('\u20ac${total is num ? total.toStringAsFixed(2) : total}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: BigDoggTheme.teal800)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(isNl ? 'Sluiten' : 'Close', style: const TextStyle(color: BigDoggTheme.teal800)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quarter Detail Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _QuarterDetailSheet extends StatefulWidget {
  final int quarter;
  final int year;
  final bool isNl;

  const _QuarterDetailSheet({required this.quarter, required this.year, required this.isNl});

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
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    final result = await OverviewService.getQuarterDetail(quarter: widget.quarter, year: widget.year);
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

  Color _statusColor(String s) {
    switch (s) {
      case 'paid': return BigDoggTheme.success;
      case 'sent': return BigDoggTheme.info;
      case 'overdue': return BigDoggTheme.error;
      default: return BigDoggTheme.lightTextSecondary;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'paid': return widget.isNl ? 'Betaald' : 'Paid';
      case 'sent': return widget.isNl ? 'Verstuurd' : 'Sent';
      case 'overdue': return widget.isNl ? 'Verlopen' : 'Overdue';
      default: return widget.isNl ? 'Concept' : 'Draft';
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showInvoiceDetail(Map<String, dynamic> inv) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => _InvoiceDetailSheet(invoice: inv, isNl: widget.isNl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNl = widget.isNl;
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Text('Q${widget.quarter} ${widget.year}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: BigDoggTheme.teal800, fontFamily: 'PlusJakartaSans')),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Container(
            color: BigDoggTheme.teal800,
            child: TabBar(
              controller: _tab,
              indicatorColor: BigDoggTheme.gold500, indicatorWeight: 3,
              labelColor: Colors.white, unselectedLabelColor: BigDoggTheme.teal400,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'PlusJakartaSans'),
              tabs: [
                Tab(text: isNl ? 'Facturen (${_invoices.length})' : 'Invoices (${_invoices.length})'),
                Tab(text: isNl ? 'Kosten (${_expenses.length})' : 'Expenses (${_expenses.length})'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(controller: _tab, children: [
                    _invoices.isEmpty
                        ? _empty(isNl ? 'Geen facturen dit kwartaal' : 'No invoices this quarter', Icons.receipt_long_outlined)
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _invoices.length,
                            itemBuilder: (_, i) {
                              final inv = _invoices[i];
                              final status = inv['status'] ?? 'draft';
                              final clientName = inv['clients']?['contact_name'] ?? inv['client_name'] ?? (isNl ? 'Verwijderde klant' : 'Deleted client');
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(color: BigDoggTheme.lightSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: BigDoggTheme.lightBorder)),
                                child: Row(
                                  children: [
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Row(children: [
                                        Text(inv['invoice_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                                          child: Text(_statusLabel(status), style: TextStyle(fontSize: 10, color: _statusColor(status), fontWeight: FontWeight.w600)),
                                        ),
                                      ]),
                                      const SizedBox(height: 2),
                                      Text(clientName, style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextSecondary)),
                                      Text(inv['invoice_date'] ?? '', style: const TextStyle(fontSize: 11, color: BigDoggTheme.lightTextHint)),
                                    ])),
                                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                      Text('\u20ac${inv['total_incl_btw'] ?? '0'}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: BigDoggTheme.teal800)),
                                      if (inv['pdf_url'] != null)
                                        TextButton(
                                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28)),
                                          onPressed: () => _openUrl(inv['pdf_url'] as String),
                                          child: Text(isNl ? 'Zie bestand' : 'See file',
                                              style: const TextStyle(fontSize: 11, color: BigDoggTheme.teal700)),
                                        )
                                      else
                                        TextButton(
                                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28)),
                                          onPressed: () => _showInvoiceDetail(inv),
                                          child: Text(isNl ? 'Bekijk' : 'View',
                                              style: const TextStyle(fontSize: 11, color: BigDoggTheme.teal700)),
                                        ),
                                    ]),
                                  ],
                                ),
                              );
                            }),
                    _expenses.isEmpty
                        ? _empty(isNl ? 'Geen kosten dit kwartaal' : 'No expenses this quarter', Icons.receipt_outlined)
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _expenses.length,
                            itemBuilder: (_, i) {
                              final exp = _expenses[i];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(color: BigDoggTheme.lightSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: BigDoggTheme.lightBorder)),
                                child: Row(
                                  children: [
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(exp['description'] ?? (isNl ? 'Geen omschrijving' : 'No description'),
                                          style: const TextStyle(fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text(exp['category'] ?? '', style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextSecondary)),
                                      Text(exp['expense_date'] ?? '', style: const TextStyle(fontSize: 11, color: BigDoggTheme.lightTextHint)),
                                    ])),
                                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                      Text('\u20ac${exp['total_incl_btw'] ?? exp['amount'] ?? '0'}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: BigDoggTheme.teal800)),
                                      if (exp['receipt_url'] != null)
                                        TextButton(
                                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28)),
                                          onPressed: () => _openUrl(exp['receipt_url'] as String),
                                          child: Text(isNl ? 'Zie bestand' : 'See file',
                                              style: const TextStyle(fontSize: 11, color: BigDoggTheme.teal700)),
                                        ),
                                    ]),
                                  ],
                                ),
                              );
                            }),
                  ]),
          ),
        ],
      ),
    );
  }

  Widget _empty(String msg, IconData icon) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(icon, size: 56, color: BigDoggTheme.lightTextHint),
    const SizedBox(height: 12),
    Text(msg, style: const TextStyle(fontSize: 15, color: BigDoggTheme.lightTextSecondary)),
  ]));
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

  // Hours
  Map<String, dynamic>? _hoursData;
  bool _loadingHours = true;
  bool _hoursExpanded = false;

  // Kilometerregistratie (per-trip business-mileage log)
  Map<String, dynamic>? _tripsData;
  bool _loadingTrips = true;
  bool _tripsExpanded = false;

  // KOR checker (collapsible)
  bool _korExpanded = false;

  int get _minYear => DateTime.now().year - 25;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // Background-refresh + offline state for the main "dashboard" cache
  // key (driven by _loadQuarterly). The screen also loads annual/hours
  // but those aren't part of the spec's "dashboard summary" snapshot.
  bool _refreshingDashboard = false;
  bool _offlineDashboard = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _bootstrapDashboardFromCache();
    _loadQuarterly();
    _loadAnnual();
    _loadHours();
    _loadTrips();
  }

  void _bootstrapDashboardFromCache() {
    final cached = LocalStorageService.get('dashboard');
    if (cached is Map<String, dynamic>) {
      _quarterly = cached;
      _loadingQuarterly = false;
    }
    // Bootstrap the hours + km cards from cache too, so the whole Overview
    // paints in one frame instead of those cards popping in later, after their
    // own network calls return. They refresh silently in the background.
    final hours = LocalStorageService.get('hours');
    if (hours is Map) {
      _hoursData = Map<String, dynamic>.from(hours);
      _loadingHours = false;
    }
    final trips = LocalStorageService.get('trips');
    if (trips is Map) {
      _tripsData = Map<String, dynamic>.from(trips);
      _loadingTrips = false;
    }
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  Future<void> _loadQuarterly() async {
    final hasCache = _quarterly != null;
    setState(() {
      if (!hasCache) _loadingQuarterly = true;
      _refreshingDashboard = hasCache;
    });
    final result = await OverviewService.getQuarterlyOverview();
    if (!mounted) return;
    if (result['success'] == true) {
      final fresh = result['overview'];
      setState(() {
        _quarterly = fresh is Map<String, dynamic>
            ? fresh
            : Map<String, dynamic>.from(fresh as Map);
        _loadingQuarterly = false;
        _refreshingDashboard = false;
        _offlineDashboard = false;
      });
      await LocalStorageService.save('dashboard', _quarterly);
      await LocalStorageService.saveLastSync('dashboard', DateTime.now());
    } else {
      setState(() {
        _loadingQuarterly = false;
        _refreshingDashboard = false;
        _offlineDashboard = true;
      });
    }
  }

  Future<void> _loadAnnual() async {
    setState(() => _loadingAnnual = true);
    final result = await OverviewService.getAnnualOverview(year: _selectedYear);
    setState(() {
      _loadingAnnual = false;
      if (result['success']) _annual = result['overview'];
    });
  }

  Future<void> _loadHours() async {
    // Only show the loading state on a cold start (no cache). With cache the
    // card is already on screen with last-known values; refresh silently.
    if (_hoursData == null) setState(() => _loadingHours = true);
    try {
      final token = await _getToken();
      final r = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/hours/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      if (r.statusCode == 200) {
        final data = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
        setState(() { _hoursData = data; _loadingHours = false; });
        await LocalStorageService.save('hours', data);
      } else {
        setState(() => _loadingHours = false);
      }
    } catch (_) { if (mounted) setState(() => _loadingHours = false); }
  }

  Future<void> _addHours(double hours, String date, String description) async {
    final token = await _getToken();
    final result = await OfflineQueue.postOrEnqueue(
      url: '${ApiConfig.baseUrl}/api/v1/hours/',
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: {'hours': hours, 'date': date, 'description': description},
      label: 'Uren: ${hours}h $date',
    );
    if (result['offline'] == true && mounted) {
      final isNl = context.read<AppProvider>().language == 'nl';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: BigDoggTheme.warning,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: Text(isNl
            ? 'Geen verbinding — uren worden later verstuurd.'
            : 'Offline — hours will be sent later.'),
      ));
    }
    _loadHours();
  }

  Future<void> _deleteHoursEntry(String id) async {
    final token = await _getToken();
    final result = await OfflineQueue.deleteOrEnqueue(
      url: '${ApiConfig.baseUrl}/api/v1/hours/$id',
      headers: {'Authorization': 'Bearer $token'},
      label: 'Uren verwijderen: $id',
    );
    if (result['offline'] == true && mounted) {
      final isNl = context.read<AppProvider>().language == 'nl';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: BigDoggTheme.warning,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: Text(isNl
            ? 'Geen verbinding — wordt verwijderd zodra je online bent.'
            : 'Offline — will be deleted once you are back online.'),
      ));
      return;
    }
    _loadHours();
  }

  // ── Kilometerregistratie ────────────────────────────────────────────────
  Future<void> _loadTrips() async {
    // Cache-aware like _loadHours: only spin on a cold start, refresh silently
    // when the card is already showing cached values.
    if (_tripsData == null) setState(() => _loadingTrips = true);
    try {
      final token = await _getToken();
      final r = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/trips/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      if (r.statusCode == 200) {
        final data = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
        setState(() { _tripsData = data; _loadingTrips = false; });
        await LocalStorageService.save('trips', data);
      } else {
        setState(() => _loadingTrips = false);
      }
    } catch (_) { if (mounted) setState(() => _loadingTrips = false); }
  }

  Future<void> _addTrip(Map<String, dynamic> body) async {
    final token = await _getToken();
    final result = await OfflineQueue.postOrEnqueue(
      url: '${ApiConfig.baseUrl}/api/v1/trips/',
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: body,
      label: 'Rit: ${body['km']}km ${body['trip_date']}',
    );
    if (result['offline'] == true && mounted) {
      final isNl = context.read<AppProvider>().language == 'nl';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: BigDoggTheme.warning,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: Text(isNl
            ? 'Geen verbinding — rit wordt later verstuurd.'
            : 'Offline — trip will be sent later.'),
      ));
    }
    _loadTrips();
  }

  Future<void> _deleteTrip(String id) async {
    final token = await _getToken();
    final result = await OfflineQueue.deleteOrEnqueue(
      url: '${ApiConfig.baseUrl}/api/v1/trips/$id',
      headers: {'Authorization': 'Bearer $token'},
      label: 'Rit verwijderen: $id',
    );
    if (result['offline'] == true && mounted) {
      final isNl = context.read<AppProvider>().language == 'nl';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: BigDoggTheme.warning,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: Text(isNl
            ? 'Geen verbinding — wordt verwijderd zodra je online bent.'
            : 'Offline — will be deleted once you are back online.'),
      ));
      return;
    }
    _loadTrips();
  }

  void _showAddTripDialog(bool isNl) {
    final fromCtrl = TextEditingController();
    final toCtrl = TextEditingController();
    final purposeCtrl = TextEditingController();
    final kmCtrl = TextEditingController();
    String date = DateTime.now().toIso8601String().substring(0, 10);
    bool isBusiness = true;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(isNl ? 'Rit registreren' : 'Log trip'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx, initialDate: DateTime.parse(date),
                      firstDate: DateTime(2000), lastDate: DateTime.now(),
                    );
                    if (picked != null) setSt(() => date = picked.toIso8601String().substring(0, 10));
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: isNl ? 'Datum' : 'Date'),
                    child: Text(date),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fromCtrl,
                  decoration: InputDecoration(labelText: isNl ? 'Vertrekadres' : 'From address'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: toCtrl,
                  decoration: InputDecoration(labelText: isNl ? 'Bestemming' : 'Destination'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: purposeCtrl,
                  decoration: InputDecoration(labelText: isNl ? 'Doel van de rit' : 'Purpose'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: kmCtrl,
                  decoration: InputDecoration(labelText: isNl ? 'Kilometers' : 'Kilometres'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isBusiness,
                  onChanged: (v) => setSt(() => isBusiness = v),
                  title: Text(isBusiness
                      ? (isNl ? 'Zakelijk' : 'Business')
                      : (isNl ? 'Privé' : 'Private')),
                  subtitle: Text(
                    isNl ? 'Alleen zakelijke km tellen mee voor de aftrek' : 'Only business km count toward the deduction',
                    style: const TextStyle(fontSize: 11),
                  ),
                  activeColor: BigDoggTheme.teal800,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isNl ? 'Annuleren' : 'Cancel')),
            ElevatedButton(
              onPressed: () {
                final km = double.tryParse(kmCtrl.text.replaceAll(',', '.'));
                if (km == null || km <= 0) return;
                if (fromCtrl.text.trim().isEmpty ||
                    toCtrl.text.trim().isEmpty ||
                    purposeCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                _addTrip({
                  'trip_date': date,
                  'from_address': fromCtrl.text.trim(),
                  'to_address': toCtrl.text.trim(),
                  'purpose': purposeCtrl.text.trim(),
                  'is_business': isBusiness,
                  'km': km,
                });
              },
              child: Text(isNl ? 'Opslaan' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripsCard(bool isNl) {
    if (_loadingTrips) return const SizedBox.shrink();

    final businessKm = (_tripsData?['total_business_km'] as num? ?? 0).toDouble();
    final quarterKm = (_tripsData?['quarter_business_km'] as num? ?? 0).toDouble();
    final deduction = (_tripsData?['km_deduction_eur'] as num? ?? 0).toDouble();
    final rate = (_tripsData?['km_rate'] as num? ?? 0.23).toDouble();
    final entries = (_tripsData?['entries'] as List? ?? []).take(8).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: BigDoggTheme.teal800,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: GestureDetector(
              onTap: () => setState(() => _tripsExpanded = !_tripsExpanded),
              child: Row(
                children: [
                  const Icon(Icons.directions_car_outlined, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(isNl ? 'Kilometerregistratie' : 'Mileage log',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  Icon(_tripsExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () { setState(() => _tripsExpanded = true); _showAddTripDialog(isNl); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: BigDoggTheme.gold500.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: BigDoggTheme.gold500.withOpacity(0.5)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.add, size: 14, color: BigDoggTheme.gold500),
                        const SizedBox(width: 4),
                        Text(isNl ? 'Rit toevoegen' : 'Log trip',
                            style: const TextStyle(fontSize: 11, color: BigDoggTheme.gold500, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Collapsed: quarter km + year deduction summary
          if (!_tripsExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isNl ? 'Zakelijk dit kwartaal' : 'Business this quarter', style: const TextStyle(fontSize: 11, color: BigDoggTheme.lightTextSecondary)),
                  Text('${quarterKm.toStringAsFixed(0)} km', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: BigDoggTheme.teal800)),
                ])),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isNl ? 'Aftrek dit jaar' : 'Deduction this year', style: const TextStyle(fontSize: 11, color: BigDoggTheme.lightTextSecondary)),
                  Text(_eur0(deduction), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: BigDoggTheme.teal800)),
                ])),
              ]),
            ),

          if (_tripsExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(isNl ? 'Zakelijk dit jaar' : 'Business this year', style: const TextStyle(fontSize: 11, color: BigDoggTheme.lightTextSecondary)),
                      Text('${businessKm.toStringAsFixed(0)} km', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: BigDoggTheme.teal800)),
                    ])),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(isNl ? 'Aftrek (× €${rate.toStringAsFixed(2)})' : 'Deduction (× €${rate.toStringAsFixed(2)})', style: const TextStyle(fontSize: 11, color: BigDoggTheme.lightTextSecondary)),
                      Text(_eur0(deduction), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: BigDoggTheme.teal800)),
                    ])),
                  ]),
                  const SizedBox(height: 12),
                  if (entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(isNl ? 'Nog geen ritten geregistreerd.' : 'No trips logged yet.',
                          style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextHint)),
                    )
                  else
                    ...entries.map((e) {
                      final isB = e['is_business'] == true;
                      final km = (e['km'] as num? ?? 0).toDouble();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 64,
                              child: Text(e['trip_date']?.toString() ?? '',
                                  style: const TextStyle(fontSize: 11, color: BigDoggTheme.lightTextHint)),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${e['from_address'] ?? ''} → ${e['to_address'] ?? ''}',
                                    style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextPrimary),
                                    overflow: TextOverflow.ellipsis),
                                Text(
                                  '${e['purpose'] ?? ''}${isB ? '' : (isNl ? ' · privé' : ' · private')}',
                                  style: TextStyle(fontSize: 11, color: isB ? BigDoggTheme.lightTextSecondary : BigDoggTheme.lightTextHint),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ]),
                            ),
                            const SizedBox(width: 6),
                            Text('${km.toStringAsFixed(0)} km',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                    color: isB ? BigDoggTheme.teal800 : BigDoggTheme.lightTextHint)),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _deleteTrip(e['id'].toString()),
                              child: const Icon(Icons.close, size: 14, color: BigDoggTheme.lightTextHint),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showAddHoursDialog(bool isNl) {
    final hoursCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String date = DateTime.now().toIso8601String().substring(0, 10);

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(isNl ? 'Uren registreren' : 'Log hours'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: hoursCtrl,
                decoration: InputDecoration(labelText: isNl ? 'Aantal uren' : 'Hours'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx, initialDate: DateTime.now(),
                    firstDate: DateTime(2000), lastDate: DateTime.now(),
                  );
                  if (picked != null) setSt(() => date = picked.toIso8601String().substring(0, 10));
                },
                child: InputDecorator(
                  decoration: InputDecoration(labelText: isNl ? 'Datum' : 'Date'),
                  child: Text(date),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(labelText: isNl ? 'Omschrijving (optioneel)' : 'Description (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isNl ? 'Annuleren' : 'Cancel')),
            ElevatedButton(
              onPressed: () {
                final h = double.tryParse(hoursCtrl.text);
                if (h == null || h <= 0) return;
                Navigator.pop(ctx);
                _addHours(h, date, descCtrl.text.trim());
              },
              child: Text(isNl ? 'Opslaan' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadBtwReport(bool isNl, {int? quarter, int? year}) async {
    final token = await InvoicesService.getToken();
    final lang = isNl ? 'nl' : 'en';
    String url = '${ApiConfig.baseUrl}/api/v1/reports/btw/pdf?token=$token&lang=$lang';
    if (quarter != null && year != null) url += '&quarter=$quarter&year=$year';
    final fname = quarter != null && year != null
        ? 'bigdogg-btw-Q$quarter-$year.pdf'
        : 'bigdogg-btw.pdf';
    await openPdfInApp(context, url: url, filename: fname, isNl: isNl);
  }

  void _onDownloadAnnualReportTapped(bool isNl, int year) async {
    if (!mounted) return;

    final subResult = await SubscriptionService.getStatus();
    final status = subResult['success'] == true
        ? (subResult['subscription']?['status'] ?? 'expired')
        : 'expired';
    final isPaid = status == 'active';

    if (!mounted) return;
    if (!isPaid) {
      _showPaywallDialog(isNl);
      return;
    }

    final token = await InvoicesService.getToken();
    final lang = isNl ? 'nl' : 'en';
    final url = '${ApiConfig.baseUrl}/api/v1/reports/annual/pdf?token=$token&year=$year&lang=$lang';
    await openPdfInApp(context, url: url, filename: 'bigdogg-jaarrapport-$year.pdf', isNl: isNl);
  }

  void _showPaywallDialog(bool isNl) {
    showSubscriptionWebSheet(context, isNl);
  }

  Widget _yearPicker(bool isNl) {
    final currentYear = DateTime.now().year;
    final years = List.generate(currentYear - _minYear + 1, (i) => currentYear - i);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left, color: _selectedYear > _minYear ? Colors.white : Colors.white30),
          onPressed: _selectedYear > _minYear ? () { setState(() => _selectedYear--); _loadAnnual(); } : null,
        ),
        DropdownButton<int>(
          value: _selectedYear, dropdownColor: BigDoggTheme.teal800, iconEnabledColor: Colors.white70,
          underline: const SizedBox.shrink(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18, fontFamily: 'PlusJakartaSans'),
          items: years.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
          onChanged: (y) { if (y != null) { setState(() => _selectedYear = y); _loadAnnual(); } },
        ),
        IconButton(
          icon: Icon(Icons.chevron_right, color: _selectedYear < currentYear ? Colors.white : Colors.white30),
          onPressed: _selectedYear < currentYear ? () { setState(() => _selectedYear++); _loadAnnual(); } : null,
        ),
      ],
    );
  }

  void _openQuarterDetail(int quarterNum, bool isNl) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
        builder: (_, __) => _QuarterDetailSheet(quarter: quarterNum, year: _selectedYear, isNl: isNl),
      ),
    );
  }

  // ── Hours card ─────────────────────────────────────────────────────────────
  Widget _buildHoursCard(bool isNl) {
    if (_loadingHours) return const SizedBox.shrink();

    final totalYear = (_hoursData?['total_year'] as num? ?? 0).toDouble();
    final totalQuarter = (_hoursData?['total_quarter'] as num? ?? 0).toDouble();
    final progress = (_hoursData?['urencriterium_progress'] as num? ?? 0).toDouble();
    final manualYear = (_hoursData?['manual_year'] as num? ?? 0).toDouble();
    final invoiceYear = (_hoursData?['invoice_year'] as num? ?? 0).toDouble();
    const target = 1225;
    final entries = (_hoursData?['entries'] as List? ?? []).take(5).toList();
    final invEntries = (_hoursData?['invoice_hours_breakdown'] as List? ?? []).take(5).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: BigDoggTheme.teal800,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: GestureDetector(
              onTap: () => setState(() => _hoursExpanded = !_hoursExpanded),
              child: Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(isNl ? 'Urenregistratie' : 'Hours tracker',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                ),
                Icon(_hoursExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () { setState(() => _hoursExpanded = true); _showAddHoursDialog(isNl); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: BigDoggTheme.gold500.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: BigDoggTheme.gold500.withOpacity(0.5)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.add, size: 14, color: BigDoggTheme.gold500),
                      const SizedBox(width: 4),
                      Text(isNl ? 'Uren toevoegen' : 'Log hours',
                          style: const TextStyle(fontSize: 11, color: BigDoggTheme.gold500, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ],
            ),
            ),
          ),

          // Collapsed: just show totals summary
          if (!_hoursExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isNl ? 'Dit kwartaal' : 'This quarter', style: const TextStyle(fontSize: 11, color: BigDoggTheme.lightTextSecondary)),
                  Text('${totalQuarter.toStringAsFixed(1)} u', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: BigDoggTheme.teal800)),
                ])),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isNl ? 'Dit jaar' : 'This year', style: const TextStyle(fontSize: 11, color: BigDoggTheme.lightTextSecondary)),
                  Text('${totalYear.toStringAsFixed(1)} u', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: BigDoggTheme.teal800)),
                ])),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isNl ? 'Criterium' : 'Criterion', style: const TextStyle(fontSize: 11, color: BigDoggTheme.lightTextSecondary)),
                  Text('${progress.toStringAsFixed(0)}%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: progress >= 100 ? BigDoggTheme.success : BigDoggTheme.teal800)),
                ])),
              ]),
            ),

          if (_hoursExpanded)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats row
                Row(
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(isNl ? 'Dit kwartaal' : 'This quarter',
                          style: const TextStyle(fontSize: 11, color: BigDoggTheme.lightTextSecondary)),
                      Text('${totalQuarter.toStringAsFixed(1)} u',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: BigDoggTheme.teal800)),
                    ])),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(isNl ? 'Dit jaar' : 'This year',
                          style: const TextStyle(fontSize: 11, color: BigDoggTheme.lightTextSecondary)),
                      Text('${totalYear.toStringAsFixed(1)} u',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: BigDoggTheme.teal800)),
                    ])),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(isNl ? 'Urencriterium' : 'Hour criterion',
                          style: const TextStyle(fontSize: 11, color: BigDoggTheme.lightTextSecondary)),
                      Text('$target u', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: BigDoggTheme.teal800)),
                    ])),
                  ],
                ),
                const SizedBox(height: 8),
                if (invoiceYear > 0 || manualYear > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: BigDoggTheme.lightBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: BigDoggTheme.lightBorder),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline, size: 12, color: BigDoggTheme.lightTextSecondary),
                      const SizedBox(width: 6),
                      Expanded(child: Text(
                        '${isNl ? 'Handmatig' : 'Manual'}: ${manualYear.toStringAsFixed(1)}u  ·  ${isNl ? 'Facturen' : 'Invoices'}: ${invoiceYear.toStringAsFixed(1)}u',
                        style: const TextStyle(fontSize: 11, color: BigDoggTheme.lightTextSecondary),
                      )),
                    ]),
                  ),
                const SizedBox(height: 12),

                // Progress bar
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(isNl ? 'Voortgang urencriterium' : 'Hour criterion progress',
                        style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextSecondary)),
                    Text('${progress.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                            color: progress >= 100 ? BigDoggTheme.success : BigDoggTheme.teal800)),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (progress / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: BigDoggTheme.lightBorder,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 100 ? BigDoggTheme.success : BigDoggTheme.teal800),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isNl
                        ? '${totalYear.toStringAsFixed(0)} / $target uur — ${(target - totalYear).clamp(0, target).toStringAsFixed(0)} uur te gaan'
                        : '${totalYear.toStringAsFixed(0)} / $target hours — ${(target - totalYear).clamp(0, target).toStringAsFixed(0)} hours to go',
                    style: const TextStyle(fontSize: 11, color: BigDoggTheme.lightTextSecondary),
                  ),
                ]),

                // Recent entries
                if (entries.isNotEmpty || invEntries.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Text(isNl ? 'Recente registraties' : 'Recent entries',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BigDoggTheme.lightTextSecondary)),
                  const SizedBox(height: 6),
                  ...entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Text(e['date'] ?? '', style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextHint)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          e['description']?.toString().isNotEmpty == true ? e['description'] : (isNl ? 'Geen omschrijving' : 'No description'),
                          style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextPrimary),
                          overflow: TextOverflow.ellipsis,
                        )),
                        Text('${(e['hours'] as num).toStringAsFixed(1)} u',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BigDoggTheme.teal800)),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _deleteHoursEntry(e['id']),
                          child: const Icon(Icons.close, size: 14, color: BigDoggTheme.lightTextHint),
                        ),
                      ],
                    ),
                  )).toList(),
                  if (invEntries.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(isNl ? 'Vanuit facturen' : 'From invoices',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BigDoggTheme.lightTextSecondary)),
                    const SizedBox(height: 6),
                    ...invEntries.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Text(e['date'] ?? '', style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextHint)),
                        const SizedBox(width: 6),
                        const Icon(Icons.receipt_long_outlined, size: 11, color: BigDoggTheme.teal700),
                        const SizedBox(width: 4),
                        Expanded(child: Text(
                          '${e["invoice_number"] ?? ""} · ${e["description"] ?? ""}',
                          style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextPrimary),
                          overflow: TextOverflow.ellipsis,
                        )),
                        Text('${(e['hours'] as num).toStringAsFixed(1)} u',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BigDoggTheme.teal800)),
                      ]),
                    )).toList(),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNl = context.watch<AppProvider>().language == 'nl';

    final hasCache = LocalStorageService.getLastSync('dashboard') != null;
    if (_offlineDashboard && _quarterly == null && !hasCache && !_loadingQuarterly) {
      return OfflineEmptyState(isNl: isNl);
    }

    return Stack(
      children: [
        Column(
          children: [
            if (_offlineDashboard)
              OfflineBanner(
                lastSync: LocalStorageService.getLastSync('dashboard'),
                isNl: isNl,
              ),
            Container(
              color: BigDoggTheme.teal800,
              child: TabBar(
                controller: _tabController,
                indicatorColor: BigDoggTheme.gold500,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: BigDoggTheme.teal400,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFamily: 'PlusJakartaSans'),
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
        ),
        TopRightRefreshDot(visible: _refreshingDashboard),
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
            decoration: BoxDecoration(color: BigDoggTheme.teal800, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(q['period'], style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 4),
              Text('${q['start_date']} \u2014 ${q['end_date']}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 16),

          // Hours card
          _buildHoursCard(isNl),

          // Kilometer log card (mirrors the hours card)
          _buildTripsCard(isNl),

          _sectionTitle(isNl ? 'Omzet' : 'Revenue'),
          _overviewCard([
            _overviewRow(isNl ? 'Omzet ex BTW' : 'Revenue ex VAT', '\u20ac${q['revenue_ex_btw']}'),
            _overviewRow(isNl ? 'BTW ontvangen' : 'VAT received', '\u20ac${q['revenue_btw']}'),
            _overviewRow(isNl ? 'Totaal incl BTW' : 'Total incl VAT', '\u20ac${q['revenue_total']}', bold: true),
            const Divider(),
            _overviewRow(isNl ? 'Betaald ontvangen' : 'Received', '\u20ac${q['paid_revenue']}', color: BigDoggTheme.success),
            _overviewRow(isNl ? 'Nog openstaand' : 'Outstanding', '\u20ac${q['outstanding']}', color: BigDoggTheme.warning),
          ]),
          const SizedBox(height: 16),
          _sectionTitle(isNl ? 'Kosten' : 'Expenses'),
          _overviewCard([
            _overviewRow(isNl ? 'Kosten ex BTW' : 'Expenses ex VAT', '\u20ac${q['expenses_ex_btw']}'),
            _overviewRow(isNl ? 'BTW betaald' : 'VAT paid', '\u20ac${q['expenses_btw']}'),
            _overviewRow(isNl ? 'Totaal incl BTW' : 'Total incl VAT', '\u20ac${q['expenses_total']}', bold: true),
          ]),
          const SizedBox(height: 16),
          _sectionTitle('BTW / VAT'),
          _overviewCard([
            _overviewRow(isNl ? 'BTW ontvangen' : 'VAT received', '\u20ac${q['revenue_btw']}'),
            _overviewRow(isNl ? 'BTW betaald op kosten' : 'VAT paid on expenses', '\u20ac${q['expenses_btw']}'),
            const Divider(),
            _overviewRow(isNl ? 'Te betalen BTW' : 'VAT to pay', '\u20ac${q['btw_to_pay']}',
                bold: true, large: true,
                color: (q['btw_to_pay'] as num) > 0 ? BigDoggTheme.error : BigDoggTheme.success),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _downloadBtwReport(isNl),
              icon: const Icon(Icons.download_outlined, color: Colors.white),
              label: Text(isNl ? 'Download BTW Aangifte PDF' : 'Download VAT Report PDF',
                  style: const TextStyle(color: Colors.white, fontSize: 15)),
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
              color: BigDoggTheme.warningBg, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BigDoggTheme.warning.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, color: BigDoggTheme.warning),
              const SizedBox(width: 12),
              Expanded(child: Text(
                isNl ? 'Vergeet niet je BTW-aangifte in te dienen bij de Belastingdienst.'
                    : 'Don\'t forget to submit your VAT return to the Tax Authority.',
                style: const TextStyle(color: Color(0xFF92400E), fontSize: 13),
              )),
            ]),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: BigDoggTheme.teal800, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isNl ? 'Jaaroverzicht' : 'Annual overview', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(isNl ? 'Netto winst' : 'Net profit', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                  Text('\u20ac${a['net_profit_indicative']}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                ])),
                _yearPicker(isNl),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle(isNl ? 'Per kwartaal' : 'Per quarter'),
          ...quarters.map((q) => _quarterCard(q, isNl, _selectedYear)),
          const SizedBox(height: 16),
          _sectionTitle(isNl ? 'Totaal $_selectedYear' : 'Total $_selectedYear'),
          _overviewCard([
            _overviewRow(isNl ? 'Totale omzet ex BTW' : 'Total revenue ex VAT', '\u20ac${a['total_revenue_ex_btw']}', bold: true),
            _overviewRow(isNl ? 'Totale kosten ex BTW' : 'Total expenses ex VAT', '\u20ac${a['total_expenses_ex_btw']}'),
            const Divider(),
            _overviewRow(isNl ? 'Netto winst' : 'Net profit', '\u20ac${a['net_profit_indicative']}', bold: true, large: true),
            _overviewRow(isNl ? 'Totale BTW te betalen' : 'Total VAT to pay', '\u20ac${a['total_btw_to_pay']}', color: BigDoggTheme.error),
          ]),
          const SizedBox(height: 16),
          _buildTaxReserveCard(isNl, a),
          _buildKorChecker(isNl, a),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _onDownloadAnnualReportTapped(isNl, _selectedYear),
              icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white, size: 20),
              label: Text(isNl ? 'Download Jaarrapport $_selectedYear' : 'Download Annual Report $_selectedYear',
                  style: const TextStyle(color: Colors.white, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: BigDoggTheme.gold500,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.workspace_premium_outlined, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(isNl ? 'Alleen beschikbaar voor betaalde gebruikers' : 'Available on paid plan only',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ]),
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
          color: BigDoggTheme.lightSurface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BigDoggTheme.lightBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Q$quarterNum $year', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: BigDoggTheme.teal800)),
            const Spacer(),
            GestureDetector(
              onTap: () => _downloadBtwReport(isNl, quarter: quarterNum, year: year),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(border: Border.all(color: BigDoggTheme.teal700), borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.download_outlined, size: 13, color: BigDoggTheme.teal700),
                  const SizedBox(width: 4),
                  Text(isNl ? 'BTW PDF' : 'VAT PDF',
                      style: const TextStyle(fontSize: 11, color: BigDoggTheme.teal700, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: BigDoggTheme.lightTextSecondary),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _miniStat(isNl ? 'Omzet' : 'Revenue', '\u20ac${q['revenue_ex_btw']}')),
            Expanded(child: _miniStat(isNl ? 'Kosten' : 'Expenses', '\u20ac${q['expenses_ex_btw']}')),
            Expanded(child: _miniStat('BTW / VAT', '\u20ac${q['btw_to_pay']}')),
          ]),
          const SizedBox(height: 6),
          Text(isNl ? 'Tik om facturen & kosten te zien' : 'Tap to see invoices & expenses',
              style: const TextStyle(fontSize: 11, color: BigDoggTheme.lightTextHint)),
        ]),
      ),
    );
  }

  Widget _miniStat(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 11, color: BigDoggTheme.lightTextSecondary)),
    Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: BigDoggTheme.teal800)),
  ]);

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: BigDoggTheme.lightTextPrimary)),
  );

  Widget _overviewCard(List<Widget> children) => Container(
    decoration: BoxDecoration(color: BigDoggTheme.lightSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: BigDoggTheme.lightBorder)),
    padding: const EdgeInsets.all(16),
    child: Column(children: children),
  );

  Widget _overviewRow(String label, String value, {bool bold = false, bool large = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: BigDoggTheme.lightTextSecondary, fontSize: large ? 15 : 14)),
      Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          fontSize: large ? 15 : 14, color: color ?? BigDoggTheme.lightTextPrimary)),
    ]),
  );

  // Group thousands with dots (Dutch style), whole euros: 15278 -> "€ 15.278".
  String _eur0(num v) =>
      '€ ${v.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}';

  // ── Reserveer voor de belasting (conservative income-tax guideline) ──────
  // Presented as guidance, never as an assessment. Hidden when there is no
  // profit to reserve against (reserve == 0).
  Widget _buildTaxReserveCard(bool isNl, Map<String, dynamic> a) {
    final tr = a['tax_reserve'];
    if (tr is! Map) return const SizedBox.shrink();
    final reserve = (tr['reserve'] as num?)?.toDouble() ?? 0;
    final winst = (tr['winst_onderneming'] as num?)?.toDouble() ?? 0;
    // Nothing meaningful to show before there's any profit at all.
    if (winst <= 0 && reserve <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BigDoggTheme.gold500.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BigDoggTheme.gold500.withOpacity(0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.savings_outlined, size: 18, color: BigDoggTheme.gold600),
                const SizedBox(width: 8),
                Text(
                  isNl ? 'Reserveer voor de belasting' : 'Set aside for income tax',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14, color: BigDoggTheme.teal800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              reserve > 0
                  ? (isNl
                      ? 'Reserveer minimaal ~${_eur0(reserve)} voor de inkomstenbelasting.'
                      : 'Set aside at least ~${_eur0(reserve)} for income tax.')
                  : (isNl
                      ? 'Je hoeft waarschijnlijk niets opzij te zetten voor de inkomstenbelasting.'
                      : 'You likely don\'t need to set anything aside for income tax.'),
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 19, color: BigDoggTheme.teal800),
            ),
            const SizedBox(height: 6),
            Text(
              isNl
                  ? 'Dit is een richtlijn, geen belastingadvies — gebaseerd op je winst, de ondernemersaftrek en de standaard heffingskortingen. Heb je ook loon uit dienstbetrekking? Dan moet je waarschijnlijk meer reserveren.'
                  : 'This is a guideline, not tax advice — based on your profit, the entrepreneur deductions and the standard tax credits. Also have income from employment? Then you should likely set aside more.',
              style: const TextStyle(
                  fontSize: 12, height: 1.45, color: BigDoggTheme.lightTextSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // ── KOR checker ───────────────────────────────────────────
  // KOR = kleineondernemersregeling. Under €20,000 revenue you may opt out
  // of charging BTW. Whether that is smart depends on whether your net BTW
  // burden is positive (you pay) or negative (you reclaim).
  Widget _buildKorChecker(bool isNl, Map<String, dynamic> a) {
    const double korThreshold = 20000.0;
    final revenue = (double.tryParse(a['total_revenue_ex_btw'].toString()) ?? 0);
    final netBtw = (double.tryParse(a['total_btw_to_pay'].toString()) ?? 0);
    // Sign convention: positive = you owe BTW to Belastingdienst.
    final eligible = revenue < korThreshold;
    final saves = eligible && netBtw > 0;
    final costs = eligible && netBtw < 0;
    final amountAbs = netBtw.abs();

    Color bg;
    Color border;
    Color accent;
    String headline;
    String body;

    if (!eligible) {
      bg = BigDoggTheme.lightSurface;
      border = BigDoggTheme.lightBorder;
      accent = BigDoggTheme.lightTextSecondary;
      headline = isNl
          ? 'Niet in aanmerking voor de KOR'
          : 'Not eligible for KOR';
      body = isNl
          ? 'Je omzet ligt boven €20.000 — je komt niet in aanmerking voor de KOR.'
          : 'Your revenue is over €20,000 — you do not qualify for the KOR.';
    } else if (saves) {
      bg = BigDoggTheme.successBg;
      border = BigDoggTheme.success.withOpacity(0.4);
      accent = BigDoggTheme.success;
      headline = isNl ? 'KOR kan je geld besparen' : 'KOR could save you money';
      body = isNl
          ? 'De KOR kan je ~€${amountAbs.toStringAsFixed(0)} per jaar besparen.'
          : 'The KOR could save you ~€${amountAbs.toStringAsFixed(0)} per year.';
    } else if (costs) {
      bg = BigDoggTheme.warningBg;
      border = BigDoggTheme.warning.withOpacity(0.5);
      accent = const Color(0xFF92400E);
      headline = isNl ? 'KOR is niet slim voor jou' : 'KOR is not smart for you';
      body = isNl
          ? 'De KOR zou je €${amountAbs.toStringAsFixed(0)} per jaar kosten. Niet slim voor jouw situatie.'
          : 'The KOR would cost you €${amountAbs.toStringAsFixed(0)} per year. Not smart for your situation.';
    } else {
      // Net BTW exactly zero: technically eligible but neutral impact.
      bg = BigDoggTheme.lightSurface;
      border = BigDoggTheme.lightBorder;
      accent = BigDoggTheme.teal800;
      headline = isNl ? 'KOR: weinig effect' : 'KOR: little effect';
      body = isNl
          ? 'Je BTW-saldo is rond de €0 — de KOR maakt voor jou nu weinig verschil.'
          : 'Your VAT balance is around €0 — the KOR would make little difference right now.';
    }

    final disclaimer = isNl
        ? 'Twijfel je? Vraag het een boekhouder. BigDogg geeft geen fiscaal advies.'
        : 'Not sure? Ask an accountant. BigDogg does not provide tax advice.';

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (always visible, tap to toggle)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _korExpanded = !_korExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.calculate_outlined, color: accent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isNl ? 'KOR checker' : 'KOR checker',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: BigDoggTheme.teal800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          headline,
                          style: TextStyle(
                              fontSize: 12,
                              color: accent,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _korExpanded ? Icons.expand_less : Icons.expand_more,
                    color: BigDoggTheme.lightTextSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_korExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(body,
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: BigDoggTheme.lightTextPrimary)),
                  const SizedBox(height: 10),
                  Text(
                    isNl
                        ? 'Omzet ex BTW: €${revenue.toStringAsFixed(0)}  ·  Netto BTW: €${netBtw.toStringAsFixed(0)}'
                        : 'Revenue ex VAT: €${revenue.toStringAsFixed(0)}  ·  Net VAT: €${netBtw.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: BigDoggTheme.lightTextSecondary),
                  ),
                  const SizedBox(height: 10),
                  Text(disclaimer,
                      style: const TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: BigDoggTheme.lightTextSecondary)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}