import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/invoices_service.dart';
import '../services/clients_service.dart';
import '../services/products_service.dart';
import '../services/quotes_service.dart';
import '../services/local_storage_service.dart';
import '../services/connectivity_service.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../services/api_config.dart';
import 'invoice_detail_screen.dart';
import 'prompt_invoice_screen.dart';
import 'prompt_quote_screen.dart';
import 'quote_detail_screen.dart';
import '../widgets/subscription_web_widget.dart';
import '../widgets/offline_chrome.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final AppProvider _appProvider;

  // ─── Invoices state ──────────────────────────────────────
  List<dynamic> _invoices = [];
  bool _loading = true;
  // Background-refresh indicator (top-right 16px dot) — set while
  // _refreshInvoices is in flight on a screen that already has data.
  bool _refreshing = false;
  // True when last refresh failed AND we have cached data to show. Drives
  // the slim "Offline — gegevens van HH:mm" banner.
  bool _offlineMode = false;
  // Auto-retry every 30s when offline AND no cache (empty state shown).
  Timer? _retryTimer;

  String? _filterStatus;
  int? _filterQuarter;
  int? _filterMonth;
  int _filterYear = DateTime.now().year;
  String _sortBy = 'date_desc';

  // Overdue (>14d) banner — dismissed-per-invoice persisted in SharedPreferences
  static const String _overduePrefsKey = 'dismissed_overdue_invoices';
  Set<String> _dismissedOverdue = {};

  // ─── Quotes state ────────────────────────────────────────
  List<dynamic> _quotes = [];
  bool _loadingQuotes = true;
  String? _quoteFilterStatus;
  String _quoteSortBy = 'date_desc';

  /// Returns the current quarter number (1–4) based on today's date.
  static int get _currentQuarter {
    final month = DateTime.now().month;
    return ((month - 1) ~/ 3) + 1;
  }

  static int get _currentYear => DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _appProvider = context.read<AppProvider>();
    // Honor any sub-tab the walkthrough requested before this screen mounted.
    final initialSubTab = _appProvider.invoicesSubTab.clamp(0, 1);
    _tabController = TabController(
        length: 2, vsync: this, initialIndex: initialSubTab);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _appProvider.addListener(_onAppProviderChange);
    _filterQuarter = _currentQuarter;
    _filterYear = _currentYear;
    _bootstrapInvoicesFromCache();
    _loadInvoices();
    _loadDismissedOverdue();
    _loadQuotes();
  }

  /// Synchronous read from the Hive cache so the list paints on the
  /// first frame instead of after a network round-trip.
  void _bootstrapInvoicesFromCache() {
    final cached = LocalStorageService.get('invoices');
    if (cached is List && cached.isNotEmpty) {
      _invoices = cached;
      _loading = false;
    }
  }

  int _lastDataVersion = 0;

  void _onAppProviderChange() {
    if (!mounted) return;
    final desired = _appProvider.invoicesSubTab.clamp(0, 1);
    if (_tabController.index != desired) {
      _tabController.animateTo(desired);
    }
    // When a notification lands, AppProvider bumps dataVersion. We
    // treat that as a signal to re-fetch invoices + quotes so anything
    // newly paid / accepted / declined is visible without pull-to-refresh.
    final v = _appProvider.dataVersion;
    if (v != _lastDataVersion) {
      _lastDataVersion = v;
      _loadInvoices();
      _loadQuotes();
    }
  }

  @override
  void dispose() {
    _appProvider.removeListener(_onAppProviderChange);
    _tabController.dispose();
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDismissedOverdue() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_overduePrefsKey) ?? const [];
    if (!mounted) return;
    setState(() => _dismissedOverdue = list.toSet());
  }

  Future<void> _persistDismissedOverdue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_overduePrefsKey, _dismissedOverdue.toList());
  }

  List<dynamic> get _overdueInvoices {
    final cutoff = DateTime.now().subtract(const Duration(days: 14));
    return _invoices.where((inv) {
      if (inv['status'] != 'sent') return false;
      final dateStr = inv['invoice_date'] as String?;
      if (dateStr == null) return false;
      final d = DateTime.tryParse(dateStr);
      if (d == null) return false;
      if (d.isAfter(cutoff)) return false;
      final id = inv['id']?.toString();
      if (id == null) return false;
      return !_dismissedOverdue.contains(id);
    }).toList();
  }

  void _dismissOverdueBanner() {
    final ids = _overdueInvoices
        .map((inv) => inv['id']?.toString())
        .whereType<String>()
        .toList();
    setState(() => _dismissedOverdue.addAll(ids));
    _persistDismissedOverdue();
  }

  Widget _buildOverdueBanner(bool isNl) {
    final overdue = _overdueInvoices;
    if (overdue.isEmpty) return const SizedBox.shrink();
    final count = overdue.length;
    final label = isNl
        ? 'Je hebt $count factuur(en) die al meer dan 14 dagen openstaan.'
        : 'You have $count invoice(s) outstanding for more than 14 days.';
    return Container(
      width: double.infinity,
      color: const Color(0xFFFEF3C7),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFF92400E), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
          ),
          GestureDetector(
            onTap: _dismissOverdueBanner,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close,
                  color: const Color(0xFF92400E).withOpacity(0.7),
                  size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadInvoices() async {
    // Spec: never show a full-screen spinner if cache exists. So we
    // only flip _loading=true when the list is empty (cold start with
    // no Hive entry); otherwise we show the top-right refresh dot.
    final hasCache = _invoices.isNotEmpty;
    setState(() {
      if (!hasCache) _loading = true;
      _refreshing = hasCache;
    });
    final result = await InvoicesService.getInvoices();
    if (!mounted) return;
    if (result['success'] == true) {
      final fresh = (result['invoices'] as List?) ?? const [];
      setState(() {
        _invoices = fresh;
        _loading = false;
        _refreshing = false;
        _offlineMode = false;
      });
      // Persist for the next cold start + reset the retry timer.
      await LocalStorageService.save('invoices', fresh);
      await LocalStorageService.saveLastSync('invoices', DateTime.now());
      _retryTimer?.cancel();
    } else {
      setState(() {
        _loading = false;
        _refreshing = false;
        _offlineMode = true;
      });
      // If we have nothing to show, keep trying every 30s in the
      // background so the user gets data the moment the wifi comes back.
      if (_invoices.isEmpty) {
        _retryTimer?.cancel();
        _retryTimer = Timer(const Duration(seconds: 30), () {
          if (mounted) _loadInvoices();
        });
      }
    }
  }

  Future<void> _loadQuotes() async {
    setState(() => _loadingQuotes = true);
    final result = await QuotesService.getQuotes();
    if (!mounted) return;
    setState(() {
      _loadingQuotes = false;
      if (result['success']) _quotes = result['quotes'];
    });
  }

  void _navigateToInvoice(String invoiceId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceDetailScreen(invoiceId: invoiceId),
      ),
    ).then((_) => _loadInvoices());
  }

  void _navigateToQuote(String quoteId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuoteDetailScreen(quoteId: quoteId),
      ),
    ).then((_) {
      _loadQuotes();
      // The convert action may have produced a new invoice, so refresh too.
      _loadInvoices();
    });
  }

  List<dynamic> get _filteredInvoices {
    List<dynamic> list = List.from(_invoices);

    if (_filterStatus != null) {
      list = list.where((inv) => inv['status'] == _filterStatus).toList();
    }

    if (_filterMonth != null) {
      list = list.where((inv) {
        final date = inv['invoice_date'] as String?;
        if (date == null) return false;
        final parts = date.split('-');
        final year = int.tryParse(parts[0]) ?? 0;
        final month = int.tryParse(parts[1]) ?? 0;
        return year == _filterYear && month == _filterMonth;
      }).toList();
    } else if (_filterQuarter != null) {
      final months = {
        1: [1, 2, 3],
        2: [4, 5, 6],
        3: [7, 8, 9],
        4: [10, 11, 12],
      }[_filterQuarter]!;
      list = list.where((inv) {
        final date = inv['invoice_date'] as String?;
        if (date == null) return false;
        final parts = date.split('-');
        final year = int.tryParse(parts[0]) ?? 0;
        final month = int.tryParse(parts[1]) ?? 0;
        return year == _filterYear && months.contains(month);
      }).toList();
    }

    list.sort((a, b) {
      switch (_sortBy) {
        case 'amount_asc':
          return (double.tryParse(a['total_incl_btw'].toString()) ?? 0)
              .compareTo(double.tryParse(b['total_incl_btw'].toString()) ?? 0);
        case 'amount_desc':
          return (double.tryParse(b['total_incl_btw'].toString()) ?? 0)
              .compareTo(double.tryParse(a['total_incl_btw'].toString()) ?? 0);
        case 'date_asc':
          return (a['invoice_date'] ?? '').compareTo(b['invoice_date'] ?? '');
        case 'date_desc':
        default:
          return (b['invoice_date'] ?? '').compareTo(a['invoice_date'] ?? '');
      }
    });

    return list;
  }

  List<dynamic> get _filteredQuotes {
    List<dynamic> list = List.from(_quotes);
    if (_quoteFilterStatus != null) {
      list = list.where((q) => q['status'] == _quoteFilterStatus).toList();
    }
    list.sort((a, b) {
      switch (_quoteSortBy) {
        case 'amount_asc':
          return (double.tryParse(a['total_incl_btw'].toString()) ?? 0)
              .compareTo(double.tryParse(b['total_incl_btw'].toString()) ?? 0);
        case 'amount_desc':
          return (double.tryParse(b['total_incl_btw'].toString()) ?? 0)
              .compareTo(double.tryParse(a['total_incl_btw'].toString()) ?? 0);
        case 'date_asc':
          return (a['quote_date'] ?? '').compareTo(b['quote_date'] ?? '');
        case 'date_desc':
        default:
          return (b['quote_date'] ?? '').compareTo(a['quote_date'] ?? '');
      }
    });
    return list;
  }

  bool get _hasActiveFilters =>
      _filterStatus != null ||
      _filterMonth != null ||
      _filterQuarter != _currentQuarter ||
      _filterYear != _currentYear ||
      _sortBy != 'date_desc';

  /// Display name for a client. `??` alone isn't enough because the
  /// onboarding form leaves company_name as an empty string when the
  /// client is a private individual — pick the first non-blank value.
  String _clientLabel(Map c) {
    final company = (c['company_name'] ?? '').toString().trim();
    if (company.isNotEmpty) return company;
    final contact = (c['contact_name'] ?? '').toString().trim();
    if (contact.isNotEmpty) return contact;
    final email = (c['email'] ?? '').toString().trim();
    if (email.isNotEmpty) return email;
    return '?';
  }

  String _periodLabel(bool isNl) {
    if (_filterMonth != null) {
      final months = isNl
          ? ['Januari', 'Februari', 'Maart', 'April', 'Mei', 'Juni',
              'Juli', 'Augustus', 'September', 'Oktober', 'November', 'December']
          : ['January', 'February', 'March', 'April', 'May', 'June',
              'July', 'August', 'September', 'October', 'November', 'December'];
      return '${months[_filterMonth! - 1]} $_filterYear';
    }
    if (_filterQuarter != null) {
      return 'Q$_filterQuarter $_filterYear';
    }
    return isNl ? 'Alle facturen' : 'All invoices';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return BigDoggTheme.success;
      case 'sent':
        return BigDoggTheme.info;
      case 'overdue':
        return BigDoggTheme.error;
      default:
        return BigDoggTheme.lightTextSecondary;
    }
  }

  String _statusLabel(String status, bool isNl) {
    switch (status) {
      case 'paid':
        return isNl ? 'Betaald' : 'Paid';
      case 'sent':
        return isNl ? 'Verstuurd' : 'Sent';
      case 'overdue':
        return isNl ? 'Verlopen' : 'Overdue';
      default:
        return isNl ? 'Concept' : 'Draft';
    }
  }

  Color _quoteStatusColor(String s) {
    switch (s) {
      case 'sent':
        return BigDoggTheme.info;
      case 'accepted':
        return BigDoggTheme.success;
      case 'declined':
        return BigDoggTheme.error;
      case 'converted':
        return const Color(0xFF7C3AED); // purple
      default:
        return BigDoggTheme.lightTextSecondary; // grey for draft
    }
  }

  String _quoteStatusLabel(String s, bool isNl) {
    switch (s) {
      case 'sent':
        return isNl ? 'Verstuurd' : 'Sent';
      case 'accepted':
        return isNl ? 'Geaccepteerd' : 'Accepted';
      case 'declined':
        return isNl ? 'Afgewezen' : 'Declined';
      case 'converted':
        return isNl ? 'Omgezet' : 'Converted';
      default:
        return isNl ? 'Concept' : 'Draft';
    }
  }

  void _showFilterSheet(bool isNl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: BigDoggTheme.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isNl ? 'Filteren & sorteren' : 'Filter & sort',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: BigDoggTheme.teal800),
                      ),
                      const SizedBox(height: 16),
                      Text(isNl ? 'Status' : 'Status',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: BigDoggTheme.lightTextSecondary)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _filterChip(isNl ? 'Alle' : 'All',
                              _filterStatus == null, () {
                            setSheetState(() => _filterStatus = null);
                            setState(() => _filterStatus = null);
                          }),
                          _filterChip(isNl ? 'Betaald' : 'Paid',
                              _filterStatus == 'paid', () {
                            setSheetState(() => _filterStatus = 'paid');
                            setState(() => _filterStatus = 'paid');
                          }),
                          _filterChip(isNl ? 'Verstuurd' : 'Sent',
                              _filterStatus == 'sent', () {
                            setSheetState(() => _filterStatus = 'sent');
                            setState(() => _filterStatus = 'sent');
                          }),
                          _filterChip(isNl ? 'Verlopen' : 'Overdue',
                              _filterStatus == 'overdue', () {
                            setSheetState(() => _filterStatus = 'overdue');
                            setState(() => _filterStatus = 'overdue');
                          }),
                          _filterChip(isNl ? 'Concept' : 'Draft',
                              _filterStatus == 'draft', () {
                            setSheetState(() => _filterStatus = 'draft');
                            setState(() => _filterStatus = 'draft');
                          }),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(isNl ? 'Kwartaal' : 'Quarter',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: BigDoggTheme.lightTextSecondary)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _filterChip(
                              isNl ? 'Alle' : 'All',
                              _filterQuarter == null && _filterMonth == null,
                              () {
                                setSheetState(() {
                                  _filterQuarter = null;
                                  _filterMonth = null;
                                });
                                setState(() {
                                  _filterQuarter = null;
                                  _filterMonth = null;
                                });
                              }),
                          ...List.generate(
                              4,
                              (i) => _filterChip(
                                  'Q${i + 1}', _filterQuarter == i + 1, () {
                                setSheetState(() {
                                  _filterQuarter = i + 1;
                                  _filterMonth = null;
                                });
                                setState(() {
                                  _filterQuarter = i + 1;
                                  _filterMonth = null;
                                });
                              })),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(isNl ? 'Maand' : 'Month',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: BigDoggTheme.lightTextSecondary)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: List.generate(12, (i) {
                          final months = isNl
                              ? [
                                  'Jan', 'Feb', 'Mrt', 'Apr', 'Mei', 'Jun',
                                  'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dec'
                                ]
                              : [
                                  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                                ];
                          return _filterChip(months[i], _filterMonth == i + 1,
                              () {
                            setSheetState(() {
                              _filterMonth = i + 1;
                              _filterQuarter = null;
                            });
                            setState(() {
                              _filterMonth = i + 1;
                              _filterQuarter = null;
                            });
                          });
                        }),
                      ),
                      const SizedBox(height: 16),
                      Text(isNl ? 'Jaar' : 'Year',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: BigDoggTheme.lightTextSecondary)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: List.generate(3, (i) {
                          final year = _currentYear - (2 - i);
                          return _filterChip(
                            year.toString(),
                            _filterYear == year,
                            () {
                              setSheetState(() => _filterYear = year);
                              setState(() => _filterYear = year);
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      Text(isNl ? 'Sorteren' : 'Sort by',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: BigDoggTheme.lightTextSecondary)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _filterChip(isNl ? 'Datum ↓' : 'Date ↓',
                              _sortBy == 'date_desc', () {
                            setSheetState(() => _sortBy = 'date_desc');
                            setState(() => _sortBy = 'date_desc');
                          }),
                          _filterChip(isNl ? 'Datum ↑' : 'Date ↑',
                              _sortBy == 'date_asc', () {
                            setSheetState(() => _sortBy = 'date_asc');
                            setState(() => _sortBy = 'date_asc');
                          }),
                          _filterChip(isNl ? 'Bedrag ↓' : 'Amount ↓',
                              _sortBy == 'amount_desc', () {
                            setSheetState(() => _sortBy = 'amount_desc');
                            setState(() => _sortBy = 'amount_desc');
                          }),
                          _filterChip(isNl ? 'Bedrag ↑' : 'Amount ↑',
                              _sortBy == 'amount_asc', () {
                            setSheetState(() => _sortBy = 'amount_asc');
                            setState(() => _sortBy = 'amount_asc');
                          }),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _filterStatus = null;
                              _filterQuarter = _currentQuarter;
                              _filterMonth = null;
                              _filterYear = _currentYear;
                              _sortBy = 'date_desc';
                            });
                            Navigator.pop(context);
                          },
                          child: Text(isNl ? 'Filters wissen' : 'Clear filters',
                              style:
                                  const TextStyle(color: BigDoggTheme.error)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuoteFilterSheet(bool isNl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  alignment: Alignment.center,
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: BigDoggTheme.lightBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isNl ? 'Filteren & sorteren' : 'Filter & sort',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: BigDoggTheme.teal800),
                ),
                const SizedBox(height: 16),
                Text(isNl ? 'Status' : 'Status',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: BigDoggTheme.lightTextSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _filterChip(isNl ? 'Alle' : 'All',
                        _quoteFilterStatus == null, () {
                      setSheetState(() => _quoteFilterStatus = null);
                      setState(() => _quoteFilterStatus = null);
                    }),
                    for (final s in const [
                      'draft',
                      'sent',
                      'accepted',
                      'declined',
                      'converted'
                    ])
                      _filterChip(_quoteStatusLabel(s, isNl),
                          _quoteFilterStatus == s, () {
                        setSheetState(() => _quoteFilterStatus = s);
                        setState(() => _quoteFilterStatus = s);
                      }),
                  ],
                ),
                const SizedBox(height: 16),
                Text(isNl ? 'Sorteren' : 'Sort by',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: BigDoggTheme.lightTextSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _filterChip(isNl ? 'Datum ↓' : 'Date ↓',
                        _quoteSortBy == 'date_desc', () {
                      setSheetState(() => _quoteSortBy = 'date_desc');
                      setState(() => _quoteSortBy = 'date_desc');
                    }),
                    _filterChip(isNl ? 'Datum ↑' : 'Date ↑',
                        _quoteSortBy == 'date_asc', () {
                      setSheetState(() => _quoteSortBy = 'date_asc');
                      setState(() => _quoteSortBy = 'date_asc');
                    }),
                    _filterChip(isNl ? 'Bedrag ↓' : 'Amount ↓',
                        _quoteSortBy == 'amount_desc', () {
                      setSheetState(() => _quoteSortBy = 'amount_desc');
                      setState(() => _quoteSortBy = 'amount_desc');
                    }),
                    _filterChip(isNl ? 'Bedrag ↑' : 'Amount ↑',
                        _quoteSortBy == 'amount_asc', () {
                      setSheetState(() => _quoteSortBy = 'amount_asc');
                      setState(() => _quoteSortBy = 'amount_asc');
                    }),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? BigDoggTheme.teal800 : BigDoggTheme.lightBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color:
                  selected ? BigDoggTheme.teal800 : BigDoggTheme.lightBorder),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : BigDoggTheme.lightTextSecondary)),
      ),
    );
  }


  Future<List<dynamic>> _fetchProjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final r = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/projects/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (r.statusCode == 200) return jsonDecode(r.body)['projects'] ?? [];
    } catch (_) {}
    return [];
  }

  void _showCreateInvoice(bool isNl) async {
    final clientsResult = await ClientsService.getClients();
    final productsResult = await ProductsService.getProducts();
    final projects = await _fetchProjects();
    if (!clientsResult['success'] || !productsResult['success']) return;
    final clients = clientsResult['clients'] as List;
    final products = productsResult['products'] as List;
    if (!mounted) return;

    String? selectedClientId;
    String? selectedProjectId;
    List<Map<String, dynamic>> lines = [];
    // High-risk-flow guard: disables the submit button + shows a
    // spinner inside it while the create request is in flight.
    bool saving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isNl ? 'Nieuwe factuur' : 'New Invoice'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedClientId,
                  decoration:
                      InputDecoration(labelText: isNl ? 'Klant' : 'Client'),
                  items: clients
                      .map((c) => DropdownMenuItem<String>(
                            value: c['id'] as String,
                            child: Text(_clientLabel(c)),
                          ))
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedClientId = val),
                ),
                if (projects.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: selectedProjectId,
                    decoration: InputDecoration(
                        labelText: isNl ? 'Project (optioneel)' : 'Project (optional)'),
                    items: [
                      DropdownMenuItem<String?>(
                          value: null,
                          child: Text(isNl ? 'Geen project' : 'No project')),
                      ...projects.map((p) => DropdownMenuItem<String?>(
                            value: p['id'] as String,
                            child: Row(children: [
                              Container(
                                width: 10, height: 10,
                                decoration: BoxDecoration(
                                  color: Color(int.parse((p['color'] ?? '#1B3A4B').replaceFirst('#', '0xFF'))),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(p['name'] ?? ''),
                            ]),
                          )),
                    ],
                    onChanged: (val) => setDialogState(() => selectedProjectId = val),
                  ),
                ],
                const SizedBox(height: 16),
                Text(isNl ? 'Regels' : 'Lines',
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...lines.asMap().entries.map((entry) {
                  final i = entry.key;
                  final line = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(line['description'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500)),
                                Text(
                                    '${line['quantity']}x €${line['unit_price_ex_btw']} (${line['btw_rate']}% BTW)',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: BigDoggTheme
                                            .lightTextSecondary)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                                Icons.remove_circle_outline,
                                color: BigDoggTheme.error),
                            onPressed: () => setDialogState(
                                () => lines.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () =>
                      _showAddLine(context, products, isNl, (line) {
                    setDialogState(() => lines.add(line));
                  }),
                  icon: const Icon(Icons.add),
                  label: Text(isNl ? 'Regel toevoegen' : 'Add line'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isNl ? 'Annuleren' : 'Cancel')),
            ElevatedButton(
              onPressed: (selectedClientId == null || lines.isEmpty || saving)
                  ? null
                  : () async {
                      // High-risk strict flow per spec: keep the form
                      // open until the API confirms. Disable the button
                      // and show a spinner inside it while the request
                      // is in flight.
                      setDialogState(() => saving = true);
                      final result = await InvoicesService.createInvoice(
                          clientId: selectedClientId!, lines: lines,
                          projectId: selectedProjectId);
                      if (!mounted) return;
                      if (result['offline'] == true) {
                        // Queued — close + tell the user.
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          backgroundColor: BigDoggTheme.warning,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 4),
                          content: Text(isNl
                              ? 'Geen verbinding — factuur wordt later aangemaakt.'
                              : 'Offline — invoice will be created later.'),
                        ));
                        return;
                      }
                      if (result['success'] == true) {
                        Navigator.pop(context);
                        await _loadInvoices();
                        final invoiceId = result['invoice']['id'];
                        _navigateToInvoice(invoiceId);
                        return;
                      }
                      // Hard failure: keep the form open with all
                      // input intact, re-enable the button, show error.
                      setDialogState(() => saving = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        backgroundColor: BigDoggTheme.error,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 5),
                        content: Text(isNl
                            ? 'Opslaan mislukt. Controleer je verbinding en probeer opnieuw.'
                            : 'Save failed. Check your connection and try again.'),
                      ));
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isNl ? 'Aanmaken' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateQuote(bool isNl) async {
    final clientsResult = await ClientsService.getClients();
    final productsResult = await ProductsService.getProducts();
    final projects = await _fetchProjects();
    if (!clientsResult['success'] || !productsResult['success']) return;
    final clients = clientsResult['clients'] as List;
    final products = productsResult['products'] as List;
    if (!mounted) return;

    String? selectedClientId;
    String? selectedProjectId;
    List<Map<String, dynamic>> lines = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isNl ? 'Nieuwe offerte' : 'New Quote'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedClientId,
                  decoration:
                      InputDecoration(labelText: isNl ? 'Klant' : 'Client'),
                  items: clients
                      .map((c) => DropdownMenuItem<String>(
                            value: c['id'] as String,
                            child: Text(_clientLabel(c)),
                          ))
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedClientId = val),
                ),
                if (projects.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: selectedProjectId,
                    decoration: InputDecoration(
                        labelText: isNl ? 'Project (optioneel)' : 'Project (optional)'),
                    items: [
                      DropdownMenuItem<String?>(
                          value: null,
                          child: Text(isNl ? 'Geen project' : 'No project')),
                      ...projects.map((p) => DropdownMenuItem<String?>(
                            value: p['id'] as String,
                            child: Row(children: [
                              Container(
                                width: 10, height: 10,
                                decoration: BoxDecoration(
                                  color: Color(int.parse((p['color'] ?? '#1B3A4B').replaceFirst('#', '0xFF'))),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(p['name'] ?? ''),
                            ]),
                          )),
                    ],
                    onChanged: (val) =>
                        setDialogState(() => selectedProjectId = val),
                  ),
                ],
                const SizedBox(height: 16),
                Text(isNl ? 'Regels' : 'Lines',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...lines.asMap().entries.map((entry) {
                  final i = entry.key;
                  final line = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(line['description'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500)),
                                Text(
                                  '${line['quantity']}x €${line['unit_price_ex_btw']} (${line['btw_rate']}% BTW)',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color:
                                          BigDoggTheme.lightTextSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: BigDoggTheme.error),
                            onPressed: () =>
                                setDialogState(() => lines.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () =>
                      _showAddLine(context, products, isNl, (line) {
                    setDialogState(() => lines.add(line));
                  }),
                  icon: const Icon(Icons.add),
                  label: Text(isNl ? 'Regel toevoegen' : 'Add line'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isNl ? 'Annuleren' : 'Cancel')),
            ElevatedButton(
              onPressed: selectedClientId == null || lines.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(context);
                      final result = await QuotesService.createQuote(
                        clientId: selectedClientId!,
                        lines: lines,
                        projectId: selectedProjectId,
                      );
                      if (result['success'] && mounted) {
                        await _loadQuotes();
                        final qid = result['quote']['id'];
                        _navigateToQuote(qid);
                      }
                    },
              child: Text(isNl ? 'Aanmaken' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddLine(BuildContext context, List products, bool isNl,
      Function(Map<String, dynamic>) onAdd) {
    String? selectedProductId;
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController();
    final descController = TextEditingController();
    int btwRate = 21;
    String unit = 'fixed';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isNl ? 'Regel toevoegen' : 'Add Line'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedProductId,
                  decoration: InputDecoration(
                      labelText: isNl
                          ? 'Product (optioneel)'
                          : 'Product (optional)'),
                  items: [
                    DropdownMenuItem(
                        value: null,
                        child: Text(
                            isNl ? 'Aangepaste regel' : 'Custom line')),
                    ...products.map((p) => DropdownMenuItem<String>(
                          value: p['id'] as String,
                          child: Text(p['name']),
                        )),
                  ],
                  onChanged: (val) {
                    setDialogState(() {
                      selectedProductId = val;
                      if (val != null) {
                        final p =
                            products.firstWhere((p) => p['id'] == val);
                        descController.text = p['name'];
                        priceController.text =
                            p['unit_price'].toString();
                        btwRate = p['btw_rate'];
                        unit = p['unit'] ?? 'fixed';
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: descController,
                    decoration: InputDecoration(
                        labelText:
                            isNl ? 'Omschrijving' : 'Description')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: TextField(
                            controller: qtyController,
                            decoration: InputDecoration(
                                labelText: isNl ? 'Aantal' : 'Qty'),
                            keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: TextField(
                            controller: priceController,
                            decoration: InputDecoration(
                                labelText: isNl
                                    ? 'Prijs ex BTW'
                                    : 'Price ex BTW'),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true))),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: btwRate,
                  decoration:
                      const InputDecoration(labelText: 'BTW'),
                  items: const [
                    DropdownMenuItem(value: 21, child: Text('21%')),
                    DropdownMenuItem(value: 9, child: Text('9%')),
                    DropdownMenuItem(value: 0, child: Text('0%')),
                  ],
                  onChanged: (val) =>
                      setDialogState(() => btwRate = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isNl ? 'Annuleren' : 'Cancel')),
            ElevatedButton(
              onPressed: () {
                if (descController.text.isEmpty ||
                    priceController.text.isEmpty) return;
                final qty = double.tryParse(
                    qtyController.text.trim().replaceAll(',', '.'));
                final price = double.tryParse(
                    priceController.text.trim().replaceAll(',', '.'));
                if (qty == null || price == null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isNl
                        ? 'Vul geldige cijfers in'
                        : 'Enter valid numbers'),
                  ));
                  return;
                }
                Navigator.pop(context);
                onAdd({
                  'description': descController.text,
                  'quantity': qty,
                  'unit': unit,
                  'unit_price_ex_btw': price,
                  'btw_rate': btwRate,
                  // Carry the product id when the line came from the
                  // dropdown. Backend uses this for the hours calc so
                  // editing the description doesn't break the link.
                  if (selectedProductId != null)
                    'product_id': selectedProductId,
                });
              },
              child: Text(isNl ? 'Toevoegen' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Tab bodies ─────────────────────────────────────────────
  Widget _buildInvoicesTab(bool isNl, List<dynamic> filtered) {
    return Column(
      children: [
        _buildOverdueBanner(isNl),
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(color: BigDoggTheme.teal800),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                _periodLabel(isNl),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const Spacer(),
              if (_filterQuarter != null || _filterMonth != null)
                GestureDetector(
                  onTap: () => setState(() {
                    _filterQuarter = null;
                    _filterMonth = null;
                  }),
                  child: Text(
                    isNl ? 'Zie alle' : 'See all',
                    style: const TextStyle(
                      color: BigDoggTheme.gold500,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: BigDoggTheme.lightSurface,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${filtered.length} ${isNl ? 'facturen' : 'invoices'}',
                  style: const TextStyle(
                      color: BigDoggTheme.lightTextSecondary,
                      fontSize: 13),
                ),
              ),
              GestureDetector(
                onTap: () => _showFilterSheet(isNl),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _hasActiveFilters
                        ? BigDoggTheme.teal800
                        : BigDoggTheme.lightBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _hasActiveFilters
                          ? BigDoggTheme.teal800
                          : BigDoggTheme.lightBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune,
                          size: 14,
                          color: _hasActiveFilters
                              ? Colors.white
                              : BigDoggTheme.lightTextSecondary),
                      const SizedBox(width: 4),
                      Text(
                        isNl ? 'Filter' : 'Filter',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _hasActiveFilters
                                ? Colors.white
                                : BigDoggTheme.lightTextSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.receipt_long_outlined,
                              size: 64,
                              color: BigDoggTheme.lightTextHint),
                          const SizedBox(height: 16),
                          Text(
                            _hasActiveFilters
                                ? (isNl
                                    ? 'Geen resultaten voor deze filter'
                                    : 'No results for this filter')
                                : (isNl
                                    ? 'Nog geen facturen dit kwartaal'
                                    : 'No invoices this quarter yet'),
                            style: const TextStyle(
                                fontSize: 18,
                                color: BigDoggTheme.lightTextSecondary),
                          ),
                          const SizedBox(height: 8),
                          if (_hasActiveFilters)
                            TextButton(
                              onPressed: () => setState(() {
                                _filterStatus = null;
                                _filterQuarter = _currentQuarter;
                                _filterMonth = null;
                                _filterYear = _currentYear;
                                _sortBy = 'date_desc';
                              }),
                              child: Text(isNl
                                  ? 'Filters wissen'
                                  : 'Clear filters'),
                            )
                          else
                            Text(
                              isNl
                                  ? 'Tik + om je eerste factuur aan te maken'
                                  : 'Tap + to create your first invoice',
                              style: const TextStyle(
                                  color: BigDoggTheme.lightTextHint),
                            ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final inv = filtered[index];
                        final status = inv['status'] ?? 'draft';
                        final clientName =
                            inv['clients']?['contact_name'] ??
                                inv['client_name'] ??
                                (isNl
                                    ? 'Verwijderde klant'
                                    : 'Deleted client');
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: BigDoggTheme.lightSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: BigDoggTheme.lightBorder),
                          ),
                          child: ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                            onTap: () => _navigateToInvoice(inv['id']),
                            title: Row(
                              children: [
                                Text(inv['invoice_number'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _statusColor(status)
                                        .withOpacity(0.1),
                                    borderRadius:
                                        BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _statusLabel(status, isNl),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: _statusColor(status),
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(clientName,
                                    style: const TextStyle(
                                        color: BigDoggTheme
                                            .lightTextSecondary)),
                                Text(inv['invoice_date'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: BigDoggTheme
                                            .lightTextHint)),
                              ],
                            ),
                            trailing: Text(
                                '€${inv['total_incl_btw']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: BigDoggTheme.teal800)),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildQuotesTab(bool isNl, List<dynamic> filtered) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: BigDoggTheme.lightSurface,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${filtered.length} ${isNl ? 'offertes' : 'quotes'}',
                  style: const TextStyle(
                      color: BigDoggTheme.lightTextSecondary,
                      fontSize: 13),
                ),
              ),
              GestureDetector(
                onTap: () => _showQuoteFilterSheet(isNl),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (_quoteFilterStatus != null ||
                            _quoteSortBy != 'date_desc')
                        ? BigDoggTheme.teal800
                        : BigDoggTheme.lightBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (_quoteFilterStatus != null ||
                              _quoteSortBy != 'date_desc')
                          ? BigDoggTheme.teal800
                          : BigDoggTheme.lightBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune,
                          size: 14,
                          color: (_quoteFilterStatus != null ||
                                  _quoteSortBy != 'date_desc')
                              ? Colors.white
                              : BigDoggTheme.lightTextSecondary),
                      const SizedBox(width: 4),
                      Text(
                        isNl ? 'Filter' : 'Filter',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: (_quoteFilterStatus != null ||
                                    _quoteSortBy != 'date_desc')
                                ? Colors.white
                                : BigDoggTheme.lightTextSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loadingQuotes
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.description_outlined,
                              size: 64,
                              color: BigDoggTheme.lightTextHint),
                          const SizedBox(height: 16),
                          Text(
                            isNl ? 'Nog geen offertes' : 'No quotes yet',
                            style: const TextStyle(
                                fontSize: 18,
                                color: BigDoggTheme.lightTextSecondary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isNl
                                ? 'Tik + om je eerste offerte aan te maken'
                                : 'Tap + to create your first quote',
                            style: const TextStyle(
                                color: BigDoggTheme.lightTextHint),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final q = filtered[index];
                        final status = (q['status'] ?? 'draft').toString();
                        final clientName = q['clients']?['contact_name'] ??
                            q['client_name'] ??
                            (isNl ? 'Verwijderde klant' : 'Deleted client');
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: BigDoggTheme.lightSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: BigDoggTheme.lightBorder),
                          ),
                          child: Column(
                            children: [
                              ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                onTap: () =>
                                    _navigateToQuote(q['id'].toString()),
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        q['quote_number']?.toString() ?? '',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _quoteStatusColor(status)
                                            .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _quoteStatusLabel(status, isNl),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: _quoteStatusColor(status),
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(clientName,
                                        style: const TextStyle(
                                            color: BigDoggTheme
                                                .lightTextSecondary)),
                                    Text(q['quote_date'] ?? '',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: BigDoggTheme
                                                .lightTextHint)),
                                  ],
                                ),
                                trailing: Text(
                                    '€${q['total_incl_btw']}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: BigDoggTheme.teal800)),
                              ),
                              if (status == 'accepted')
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 0, 16, 12),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        final r = await QuotesService
                                            .convertToInvoice(
                                                q['id'].toString());
                                        if (!mounted) return;
                                        if (r['success']) {
                                          await _loadQuotes();
                                          await _loadInvoices();
                                          final invoiceId =
                                              r['invoice_id'] as String?;
                                          if (invoiceId != null) {
                                            _navigateToInvoice(invoiceId);
                                          }
                                        } else {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                            content: Text(
                                                r['message']?.toString() ??
                                                    (isNl
                                                        ? 'Omzetten mislukt'
                                                        : 'Conversion failed')),
                                          ));
                                        }
                                      },
                                      icon: const Icon(
                                          Icons.swap_horiz_rounded),
                                      label: Text(isNl
                                          ? 'Omzetten naar factuur'
                                          : 'Convert to invoice'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            BigDoggTheme.gold500,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNl = context.watch<AppProvider>().language == 'nl';
    final quotesEnabled = context.watch<AppProvider>().quotesEnabled;
    final isReadOnly = context.watch<AppProvider>().isAppReadOnly;
    final filteredInvoices = _filteredInvoices;
    final filteredQuotes = _filteredQuotes;
    // When quotes are toggled off, the tab bar isn't rendered, so the
    // tab controller index is moot — force isQuotesTab to false so the
    // FAB layout falls back to the invoices-only setup.
    final isQuotesTab = quotesEnabled && _tabController.index == 1;

    // Empty + offline + nothing in Hive = no signal at all. Show the
    // dedicated empty state instead of the normal list chrome.
    final hasCache = LocalStorageService.getLastSync('invoices') != null;
    if (_offlineMode && _invoices.isEmpty && !hasCache && !_loading) {
      return OfflineEmptyState(isNl: isNl);
    }

    return Stack(
      children: [
        Column(
          children: [
            if (_offlineMode)
              OfflineBanner(
                lastSync: LocalStorageService.getLastSync('invoices'),
                isNl: isNl,
              ),
            // ── Tab bar (only when quotes are enabled) ─────────
            if (quotesEnabled)
              Container(
                color: BigDoggTheme.lightSurface,
                child: TabBar(
                  controller: _tabController,
                  labelColor: BigDoggTheme.teal800,
                  unselectedLabelColor: BigDoggTheme.lightTextSecondary,
                  indicatorColor: BigDoggTheme.teal800,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontFamily: 'PlusJakartaSans'),
                  unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontFamily: 'PlusJakartaSans'),
                  tabs: [
                    Tab(text: isNl ? 'Facturen' : 'Invoices'),
                    Tab(text: isNl ? 'Offertes' : 'Quotes'),
                  ],
                ),
              ),
            // ── Body ───────────────────────────────────────────
            Expanded(
              child: quotesEnabled
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _buildInvoicesTab(isNl, filteredInvoices),
                        _buildQuotesTab(isNl, filteredQuotes),
                      ],
                    )
                  : _buildInvoicesTab(isNl, filteredInvoices),
            ),
          ],
        ),

        // ── FABs (only on Invoices tab — quotes get a single + below) ───
        if (!isQuotesTab) ...[
          Positioned(
            bottom: 88,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'ai_fab',
              onPressed: isReadOnly
                  ? () => showSubscriptionWebSheet(context, isNl)
                  : () async {
                      if (!ConnectivityService.instance.isConnectedNow) {
                        await showOfflineGateDialog(context, isNl);
                        return;
                      }
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const PromptInvoiceScreen())).then((result) {
                        if (result is String) {
                          _loadInvoices();
                          _navigateToInvoice(result);
                        } else if (result == true) {
                          _loadInvoices();
                        }
                      });
                    },
              backgroundColor: BigDoggTheme.teal800,
              elevation: 2,
              child: const Icon(Icons.smart_toy_outlined,
                  color: Colors.white),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'create_fab',
              onPressed: isReadOnly
                  ? () => showSubscriptionWebSheet(context, isNl)
                  : () async {
                      if (!ConnectivityService.instance.isConnectedNow) {
                        await showOfflineGateDialog(context, isNl);
                        return;
                      }
                      _showCreateInvoice(isNl);
                    },
              child: const Icon(Icons.add),
            ),
          ),
        ],
        if (isQuotesTab) ...[
          Positioned(
            bottom: 88,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'ai_quote_fab',
              onPressed: isReadOnly
                  ? () => showSubscriptionWebSheet(context, isNl)
                  : () async {
                      if (!ConnectivityService.instance.isConnectedNow) {
                        await showOfflineGateDialog(context, isNl);
                        return;
                      }
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const PromptQuoteScreen())).then((result) {
                        if (result is String) {
                          _loadQuotes();
                          _navigateToQuote(result);
                        } else if (result == true) {
                          _loadQuotes();
                        }
                      });
                    },
              backgroundColor: BigDoggTheme.teal800,
              elevation: 2,
              child: const Icon(Icons.smart_toy_outlined,
                  color: Colors.white),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'create_quote_fab',
              onPressed: isReadOnly
                  ? () => showSubscriptionWebSheet(context, isNl)
                  : () async {
                      if (!ConnectivityService.instance.isConnectedNow) {
                        await showOfflineGateDialog(context, isNl);
                        return;
                      }
                      _showCreateQuote(isNl);
                    },
              child: const Icon(Icons.add),
            ),
          ),
        ],
        // Subtle "we're checking for new data" dot. Hidden when no
        // refresh in flight.
        TopRightRefreshDot(visible: _refreshing),
      ],
    );
  }
}
