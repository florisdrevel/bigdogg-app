import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/web_io.dart';
import '../services/expenses_service.dart';
import '../services/api_config.dart';
import '../providers/app_provider.dart';
import '../theme.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final AppProvider _appProvider;

  List<dynamic> _expenses = [];
  bool _loading = true;
  bool _parsing = false;

  List<dynamic> _investments = [];
  bool _loadingInvestments = true;

  // ─── Quarter / month filter (mirrors invoices_screen) ───────
  int? _filterQuarter;
  int? _filterMonth;
  String _sortBy = 'date_desc';

  static int get _currentQuarter {
    final month = DateTime.now().month;
    return ((month - 1) ~/ 3) + 1;
  }

  static int get _currentYear => DateTime.now().year;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  bool _isMobile() {
    if (!kIsWeb) return true;
    final ua = getUserAgent().toLowerCase();
    return ua.contains('mobile') || ua.contains('android') ||
        ua.contains('iphone') || ua.contains('ipad');
  }

  @override
  void initState() {
    super.initState();
    _appProvider = context.read<AppProvider>();
    final initialSubTab = _appProvider.expensesSubTab.clamp(0, 1);
    _tabController = TabController(
        length: 2, vsync: this, initialIndex: initialSubTab);
    _appProvider.addListener(_onAppProviderChange);
    _filterQuarter = _currentQuarter;
    _loadExpenses();
    _loadInvestments();
  }

  int _lastDataVersion = 0;

  void _onAppProviderChange() {
    if (!mounted) return;
    final desired = _appProvider.expensesSubTab.clamp(0, 1);
    if (_tabController.index != desired) {
      _tabController.animateTo(desired);
    }
    // Reload when a notification triggers a global data bump (e.g.
    // bank-tx-matched-as-expense should reflect immediately).
    final v = _appProvider.dataVersion;
    if (v != _lastDataVersion) {
      _lastDataVersion = v;
      _loadExpenses();
      _loadInvestments();
    }
  }

  @override
  void dispose() {
    _appProvider.removeListener(_onAppProviderChange);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    setState(() => _loading = true);
    final result = await ExpensesService.getExpenses();
    setState(() {
      _loading = false;
      if (result['success']) _expenses = result['expenses'];
    });
  }

  Future<void> _loadInvestments() async {
    setState(() => _loadingInvestments = true);
    try {
      final token = await _getToken();
      final r = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/investments/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (r.statusCode == 200) {
        setState(() {
          _investments = jsonDecode(r.body)['investments'] ?? [];
          _loadingInvestments = false;
        });
      } else {
        setState(() => _loadingInvestments = false);
      }
    } catch (_) {
      setState(() => _loadingInvestments = false);
    }
  }

  Future<List<dynamic>> _fetchProjects() async {
    try {
      final token = await _getToken();
      final r = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/projects/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (r.statusCode == 200) return jsonDecode(r.body)['projects'] ?? [];
    } catch (_) {}
    return [];
  }

  Future<void> _deleteExpense(String id) async {
    final isNl = context.read<AppProvider>().language == 'nl';
    final result = await ExpensesService.deleteExpense(id);
    if (result['offline'] == true && mounted) {
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
    _loadExpenses();
  }

  Future<void> _deleteInvestment(String id) async {
    final token = await _getToken();
    await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/investments/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _loadInvestments();
  }

  // ─── Filtering / sorting ────────────────────────────────────
  List<dynamic> get _filteredExpenses {
    List<dynamic> list = List.from(_expenses);

    if (_filterMonth != null) {
      list = list.where((e) {
        final d = e['expense_date'] as String?;
        if (d == null) return false;
        final parts = d.split('-');
        if (parts.length < 2) return false;
        final y = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        return y == _currentYear && m == _filterMonth;
      }).toList();
    } else if (_filterQuarter != null) {
      final months = {
        1: [1, 2, 3],
        2: [4, 5, 6],
        3: [7, 8, 9],
        4: [10, 11, 12],
      }[_filterQuarter]!;
      list = list.where((e) {
        final d = e['expense_date'] as String?;
        if (d == null) return false;
        final parts = d.split('-');
        if (parts.length < 2) return false;
        final y = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        return y == _currentYear && months.contains(m);
      }).toList();
    }

    list.sort((a, b) {
      switch (_sortBy) {
        case 'amount_asc':
          return (double.tryParse((a['amount_ex_btw'] ?? 0).toString()) ?? 0)
              .compareTo(double.tryParse((b['amount_ex_btw'] ?? 0).toString()) ?? 0);
        case 'amount_desc':
          return (double.tryParse((b['amount_ex_btw'] ?? 0).toString()) ?? 0)
              .compareTo(double.tryParse((a['amount_ex_btw'] ?? 0).toString()) ?? 0);
        case 'date_asc':
          return (a['expense_date'] ?? '').compareTo(b['expense_date'] ?? '');
        case 'date_desc':
        default:
          return (b['expense_date'] ?? '').compareTo(a['expense_date'] ?? '');
      }
    });

    return list;
  }

  bool get _hasActiveFilters =>
      _filterMonth != null ||
      _filterQuarter != _currentQuarter ||
      _sortBy != 'date_desc';

  String _periodLabel(bool isNl) {
    if (_filterMonth != null) {
      final months = isNl
          ? ['Januari', 'Februari', 'Maart', 'April', 'Mei', 'Juni',
              'Juli', 'Augustus', 'September', 'Oktober', 'November', 'December']
          : ['January', 'February', 'March', 'April', 'May', 'June',
              'July', 'August', 'September', 'October', 'November', 'December'];
      return '${months[_filterMonth! - 1]} $_currentYear';
    }
    if (_filterQuarter != null) {
      return 'Q$_filterQuarter $_currentYear';
    }
    return isNl ? 'Alle kosten' : 'All expenses';
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
                              _filterQuarter = _currentQuarter;
                              _filterMonth = null;
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

  Future<void> _pickAndParseReceipt(bool isNl, {bool camera = false}) async {
    Uint8List? bytes;
    String? fileName;

    if (kIsWeb) {
      final picked = await pickFiles(
        camera: camera,
        accept: camera
            ? 'image/*'
            : 'image/*,application/pdf,.pdf,.heic,.heif,*/*',
      );
      if (picked != null && picked.isNotEmpty) {
        bytes = picked.first.bytes;
        fileName = picked.first.name;
      }
    } else {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked != null) {
        bytes = await picked.readAsBytes();
        fileName = picked.name;
      }
    }

    if (bytes == null) return;
    setState(() => _parsing = true);
    final parsed = await ExpensesService.parseReceipt(
        fileBytes: bytes!, fileName: fileName ?? 'receipt.jpg');
    setState(() => _parsing = false);
    if (!mounted) return;
    if (parsed['success']) {
      _showAddExpense(isNl,
          prefill: parsed, receiptBytes: bytes, receiptFileName: fileName);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(isNl ? 'Kon bon niet lezen' : 'Could not read receipt'),
        backgroundColor: BigDoggTheme.error,
      ));
    }
  }

  void _showAddExpense(bool isNl,
      {Map<String, dynamic>? prefill,
      Uint8List? receiptBytes,
      String? receiptFileName}) async {
    final projects = await _fetchProjects();

    if (!mounted) return;

    final descCtrl =
        TextEditingController(text: prefill?['description'] ?? '');
    final amtCtrl = TextEditingController(
        text: prefill?['amount_ex_btw'] != null
            ? (prefill!['amount_ex_btw'] as num).toStringAsFixed(2)
            : '');
    int btwRate = prefill?['btw_rate'] ?? 21;
    String category = prefill?['category'] ?? 'general';
    String? projectId;
    Uint8List? recBytes = receiptBytes;
    String? recName = receiptFileName;
    bool uploading = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(isNl ? 'Uitgave toevoegen' : 'Add Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (prefill != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: BigDoggTheme.successBg,
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.auto_awesome,
                          size: 14, color: BigDoggTheme.success),
                      const SizedBox(width: 6),
                      Text(
                          isNl
                              ? 'Automatisch ingevuld via bon'
                              : 'Auto-filled from receipt',
                          style: const TextStyle(
                              fontSize: 12,
                              color: BigDoggTheme.success,
                              fontWeight: FontWeight.w500)),
                    ]),
                  ),
                TextField(
                    controller: descCtrl,
                    decoration: InputDecoration(
                        labelText:
                            isNl ? 'Omschrijving' : 'Description')),
                const SizedBox(height: 12),
                TextField(
                    controller: amtCtrl,
                    decoration: InputDecoration(
                        labelText: isNl
                            ? 'Bedrag ex BTW (€)'
                            : 'Amount ex VAT (€)'),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true)),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: btwRate,
                  decoration: const InputDecoration(labelText: 'BTW'),
                  items: const [
                    DropdownMenuItem(value: 21, child: Text('21%')),
                    DropdownMenuItem(value: 9, child: Text('9%')),
                    DropdownMenuItem(value: 0, child: Text('0%')),
                  ],
                  onChanged: (v) => setSt(() => btwRate = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: InputDecoration(
                      labelText: isNl ? 'Categorie' : 'Category'),
                  items: [
                    DropdownMenuItem(
                        value: 'general',
                        child: Text(isNl ? 'Algemeen' : 'General')),
                    DropdownMenuItem(
                        value: 'travel',
                        child: Text(isNl ? 'Reizen' : 'Travel')),
                    DropdownMenuItem(
                        value: 'materials',
                        child:
                            Text(isNl ? 'Materialen' : 'Materials')),
                    const DropdownMenuItem(
                        value: 'software', child: Text('Software')),
                    DropdownMenuItem(
                        value: 'food',
                        child: Text(
                            isNl ? 'Eten & Drinken' : 'Food & Drinks')),
                    DropdownMenuItem(
                        value: 'office',
                        child: Text(isNl ? 'Kantoor' : 'Office')),
                    DropdownMenuItem(
                        value: 'other',
                        child: Text(isNl ? 'Overig' : 'Other')),
                  ],
                  onChanged: (v) => setSt(() => category = v!),
                ),
                if (projects.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: projectId,
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
                    onChanged: (v) => setSt(() => projectId = v),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: BigDoggTheme.lightBg,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: BigDoggTheme.lightBorder)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isNl ? 'Bon' : 'Receipt',
                            style: const TextStyle(
                                fontSize: 12,
                                color: BigDoggTheme.lightTextSecondary,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        if (recBytes != null) ...[
                          ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.memory(recBytes!,
                                  height: 120,
                                  width: double.infinity,
                                  fit: BoxFit.cover)),
                          const SizedBox(height: 6),
                          TextButton.icon(
                            onPressed: () => setSt(() {
                              recBytes = null;
                              recName = null;
                            }),
                            icon: const Icon(Icons.close,
                                size: 14, color: BigDoggTheme.error),
                            label: Text(
                                isNl ? 'Verwijderen' : 'Remove',
                                style: const TextStyle(
                                    color: BigDoggTheme.error,
                                    fontSize: 12)),
                          ),
                        ] else
                          Text(
                              isNl
                                  ? 'Geen bon bijgevoegd'
                                  : 'No receipt attached',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: BigDoggTheme.lightTextHint)),
                      ]),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child:
                    Text(isNl ? 'Annuleren' : 'Cancel')),
            ElevatedButton(
              onPressed: uploading
                  ? null
                  : () async {
                      if (descCtrl.text.isEmpty ||
                          amtCtrl.text.isEmpty) return;
                      // Accept both comma and dot — NL users type commas.
                      final amountStr = amtCtrl.text.trim().replaceAll(',', '.');
                      final amount = double.tryParse(amountStr);
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          backgroundColor: BigDoggTheme.error,
                          content: Text(isNl
                              ? 'Vul een geldig bedrag in'
                              : 'Enter a valid amount'),
                        ));
                        return;
                      }
                      setSt(() => uploading = true);
                      try {
                        final result = await ExpensesService.createExpense(
                          description: descCtrl.text.trim(),
                          amountExBtw: amount,
                          btwRate: btwRate,
                          category: category,
                          expenseDate: prefill?['expense_date'],
                          projectId: projectId,
                        );
                        if (result['success'] != true) {
                          if (mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              backgroundColor: BigDoggTheme.error,
                              content: Text(result['message']?.toString() ??
                                  (isNl
                                      ? 'Kon kostenpost niet aanmaken'
                                      : 'Could not create expense')),
                            ));
                          }
                          setSt(() => uploading = false);
                          return;
                        }
                        if (result['offline'] == true) {
                          if (mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(
                              backgroundColor: BigDoggTheme.warning,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 4),
                              content: Text(isNl
                                  ? 'Geen verbinding — kosten worden later verstuurd.'
                                  : 'Offline — expense will be sent later.'),
                            ));
                          }
                          return;
                        }
                        if (recBytes != null) {
                          await ExpensesService.uploadReceipt(
                              result['expense']['id'],
                              recBytes!,
                              recName ?? 'receipt.jpg');
                        }
                        if (mounted) Navigator.pop(ctx);
                        _loadExpenses();
                      } catch (e) {
                        setSt(() => uploading = false);
                        if (mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            backgroundColor: BigDoggTheme.error,
                            content: Text('Error: $e'),
                          ));
                        }
                      }
                    },
              child: uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(isNl ? 'Toevoegen' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddInvestment(bool isNl) {
    final descCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    String category = 'general';
    int years = 5;
    String date = DateTime.now().toIso8601String().substring(0, 10);
    bool saving = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) {
          final amt = double.tryParse(amtCtrl.text) ?? 0;
          final isUnder450 = amt > 0 && amt < 450;
          final List<int> yearOptions = isUnder450
              ? List.generate(30, (i) => i + 1)
              : List.generate(26, (i) => i + 5);
          if (!yearOptions.contains(years)) {
            years = yearOptions.first;
          }

          return AlertDialog(
            title: Text(isNl ? 'Investering toevoegen' : 'Add investment'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descCtrl,
                    decoration: InputDecoration(
                        labelText: isNl ? 'Omschrijving' : 'Description'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amtCtrl,
                    decoration: InputDecoration(
                        labelText: isNl
                            ? 'Aankoopbedrag (€)'
                            : 'Purchase amount (€)'),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    onChanged: (_) => setSt(() {}),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setSt(() => date =
                            picked.toIso8601String().substring(0, 10));
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                          labelText: isNl
                              ? 'Aankoopdatum'
                              : 'Purchase date'),
                      child: Text(date),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: InputDecoration(
                        labelText: isNl ? 'Categorie' : 'Category'),
                    items: [
                      DropdownMenuItem(
                          value: 'general',
                          child: Text(isNl ? 'Algemeen' : 'General')),
                      DropdownMenuItem(
                          value: 'equipment',
                          child: Text(
                              isNl ? 'Apparatuur' : 'Equipment')),
                      const DropdownMenuItem(
                          value: 'software', child: Text('Software')),
                      DropdownMenuItem(
                          value: 'vehicle',
                          child:
                              Text(isNl ? 'Voertuig' : 'Vehicle')),
                      const DropdownMenuItem(
                          value: 'goodwill',
                          child: Text('Goodwill (10+ jaar)')),
                      DropdownMenuItem(
                          value: 'other',
                          child: Text(isNl ? 'Overig' : 'Other')),
                    ],
                    onChanged: (v) => setSt(() {
                      category = v!;
                      if (category == 'goodwill' && years < 10) {
                        years = 10;
                      }
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: yearOptions.contains(years)
                        ? years
                        : yearOptions.first,
                    decoration: InputDecoration(
                        labelText: isNl
                            ? 'Afschrijving (jaren)'
                            : 'Depreciation (years)'),
                    items: yearOptions.map((y) {
                      String label =
                          '$y ${isNl ? 'jaar' : 'years'}';
                      if (y == 1 && isUnder450) {
                        label += isNl
                            ? ' (volledig aftrekbaar)'
                            : ' (full write-off)';
                      } else if (y == 5) {
                        label +=
                            isNl ? ' (standaard)' : ' (standard)';
                      } else if (y == 10) {
                        label += ' (goodwill)';
                      }
                      return DropdownMenuItem(
                          value: y, child: Text(label));
                    }).toList(),
                    onChanged: (v) => setSt(() => years = v!),
                  ),
                  const SizedBox(height: 8),
                  if (amt > 0)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isUnder450
                            ? BigDoggTheme.successBg
                            : BigDoggTheme.teal100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isUnder450
                            ? (isNl
                                ? '€< 450: direct volledig aftrekbaar in 1 jaar (NL belastingwet).'
                                : '€< 450: fully deductible in year 1 (NL tax law).')
                            : (isNl
                                ? '€≥ 450: max 20% per jaar — minimaal 5 jaar afschrijven.'
                                : '€≥ 450: max 20%/yr — minimum 5 years depreciation.'),
                        style: TextStyle(
                          fontSize: 11,
                          color: isUnder450
                              ? BigDoggTheme.success
                              : BigDoggTheme.teal800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(isNl ? 'Annuleren' : 'Cancel')),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (descCtrl.text.trim().isEmpty ||
                            amtCtrl.text.isEmpty) return;
                        final amountStr = amtCtrl.text.trim().replaceAll(',', '.');
                        final amount = double.tryParse(amountStr);
                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            backgroundColor: BigDoggTheme.error,
                            content: Text(isNl
                                ? 'Vul een geldig bedrag in'
                                : 'Enter a valid amount'),
                          ));
                          return;
                        }
                        setSt(() => saving = true);
                        try {
                          final token = await _getToken();
                          await http.post(
                            Uri.parse(
                                '${ApiConfig.baseUrl}/api/v1/investments/'),
                            headers: {
                              'Authorization': 'Bearer $token',
                              'Content-Type': 'application/json'
                            },
                            body: jsonEncode({
                              'description': descCtrl.text.trim(),
                              'amount': amount,
                              'purchase_date': date,
                              'category': category,
                              'depreciation_years': years,
                            }),
                          );
                          if (mounted) Navigator.pop(ctx);
                          _loadInvestments();
                        } catch (e) {
                          setSt(() => saving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              backgroundColor: BigDoggTheme.error,
                              content: Text('Error: $e'),
                            ));
                          }
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(isNl ? 'Toevoegen' : 'Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showReceiptDialog(String receiptUrl, bool isNl) {
    final isPdf = receiptUrl.toLowerCase().contains('.pdf') ||
        receiptUrl.toLowerCase().contains('%2Fpdf');
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(isNl ? 'Bon' : 'Receipt'),
              backgroundColor: BigDoggTheme.teal800,
              foregroundColor: Colors.white,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context))
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(isPdf ? Icons.picture_as_pdf : Icons.image,
                    size: 64, color: BigDoggTheme.teal800),
                const SizedBox(height: 16),
                Text(
                    isPdf
                        ? (isNl ? 'PDF bon' : 'PDF receipt')
                        : (isNl ? 'Foto bon' : 'Photo receipt'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: BigDoggTheme.teal800)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(receiptUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: Text(isNl
                        ? 'Openen in browser'
                        : 'Open in browser'),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'travel':
        return Icons.directions_car;
      case 'materials':
      case 'equipment':
        return Icons.build;
      case 'software':
        return Icons.computer;
      case 'food':
        return Icons.restaurant;
      case 'office':
        return Icons.business;
      case 'vehicle':
        return Icons.directions_car;
      default:
        return Icons.receipt;
    }
  }

  String _categoryLabel(String cat, bool isNl) {
    switch (cat) {
      case 'travel':
        return isNl ? 'Reizen' : 'Travel';
      case 'materials':
        return isNl ? 'Materialen' : 'Materials';
      case 'software':
        return 'Software';
      case 'food':
        return isNl ? 'Eten & Drinken' : 'Food & Drinks';
      case 'office':
        return isNl ? 'Kantoor' : 'Office';
      case 'equipment':
        return isNl ? 'Apparatuur' : 'Equipment';
      case 'vehicle':
        return isNl ? 'Voertuig' : 'Vehicle';
      case 'other':
        return isNl ? 'Overig' : 'Other';
      default:
        return isNl ? 'Algemeen' : 'General';
    }
  }

  Widget _buildExpensesTab(bool isNl, bool isMobile) {
    final filtered = _filteredExpenses;
    final double totalExBtw = filtered.fold(
        0, (s, e) => s + ((e['amount_ex_btw'] as num?) ?? 0).toDouble());
    final double totalBtw = filtered.fold(
        0, (s, e) => s + ((e['btw_amount'] as num?) ?? 0).toDouble());

    return Stack(
      children: [
        _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // ── Period header (matches invoices_screen) ──────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
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
                  // ── Filter bar ───────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    color: BigDoggTheme.lightSurface,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${filtered.length} ${isNl ? 'kosten' : 'expenses'}',
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
                  // ── Totals strip (compact, gives the list more room) ──
                  if (filtered.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: BigDoggTheme.teal800,
                          borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          _miniTotal(isNl ? 'ex BTW' : 'ex VAT',
                              '€${totalExBtw.toStringAsFixed(2)}'),
                          _miniTotal('BTW',
                              '€${totalBtw.toStringAsFixed(2)}'),
                          _miniTotal(isNl ? 'incl BTW' : 'incl VAT',
                              '€${(totalExBtw + totalBtw).toStringAsFixed(2)}'),
                        ],
                      ),
                    ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.receipt,
                                  size: 64,
                                  color: BigDoggTheme.lightTextHint),
                              const SizedBox(height: 16),
                              Text(
                                  _hasActiveFilters
                                      ? (isNl
                                          ? 'Geen kosten in deze periode'
                                          : 'No expenses in this period')
                                      : (isNl
                                          ? 'Nog geen kosten dit kwartaal'
                                          : 'No expenses this quarter yet'),
                                  style: const TextStyle(
                                      fontSize: 18,
                                      color: BigDoggTheme
                                          .lightTextSecondary)),
                              const SizedBox(height: 8),
                              if (_hasActiveFilters)
                                TextButton(
                                  onPressed: () => setState(() {
                                    _filterQuarter = _currentQuarter;
                                    _filterMonth = null;
                                    _sortBy = 'date_desc';
                                  }),
                                  child: Text(isNl
                                      ? 'Filters wissen'
                                      : 'Clear filters'),
                                )
                              else
                                Text(
                                    isNl
                                        ? 'Tik + om een uitgave toe te voegen'
                                        : 'Tap + to add an expense',
                                    style: const TextStyle(
                                        color:
                                            BigDoggTheme.lightTextHint)),
                            ],
                          ))
                        : ListView.builder(
                            // Bottom padding clears the stack of FABs so the
                            // last entry's delete icon stays tappable.
                            padding: const EdgeInsets.fromLTRB(
                                12, 4, 12, 220),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final exp = filtered[i];
                              final hasReceipt =
                                  (exp['receipt_url'] ?? '')
                                      .toString()
                                      .isNotEmpty;
                              return Container(
                                margin:
                                    const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                    color: BigDoggTheme.lightSurface,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    border: Border.all(
                                        color:
                                            BigDoggTheme.lightBorder)),
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        BigDoggTheme.teal100,
                                    child: Icon(
                                        _categoryIcon(
                                            exp['category'] ??
                                                'general'),
                                        color: BigDoggTheme.teal800,
                                        size: 20),
                                  ),
                                  title: Text(exp['description'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: BigDoggTheme
                                              .lightTextPrimary)),
                                  subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            '${exp['expense_date']} · ${_categoryLabel(exp['category'] ?? 'general', isNl)} · ${exp['btw_rate']}% BTW',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: BigDoggTheme
                                                    .lightTextSecondary)),
                                        if (hasReceipt)
                                          GestureDetector(
                                            onTap: () =>
                                                _showReceiptDialog(
                                                    exp['receipt_url'],
                                                    isNl),
                                            child: Row(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                      Icons.attach_file,
                                                      size: 12,
                                                      color: BigDoggTheme
                                                          .teal700),
                                                  const SizedBox(
                                                      width: 2),
                                                  Text(
                                                      isNl
                                                          ? 'Bon bekijken'
                                                          : 'View receipt',
                                                      style: const TextStyle(
                                                          fontSize: 11,
                                                          color: BigDoggTheme
                                                              .teal700,
                                                          fontWeight:
                                                              FontWeight
                                                                  .w500)),
                                                ]),
                                          ),
                                      ]),
                                  trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                  '€${exp['amount_ex_btw']}',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: BigDoggTheme
                                                          .teal800)),
                                              Text(
                                                  '+ €${exp['btw_amount']} BTW',
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: BigDoggTheme
                                                          .lightTextSecondary)),
                                            ]),
                                        const SizedBox(width: 4),
                                        IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: BigDoggTheme.error),
                                            onPressed: () =>
                                                _deleteExpense(exp['id'])),
                                      ]),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
        if (_parsing)
          Container(
            color: Colors.black45,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                      isNl
                          ? 'Bon analyseren...'
                          : 'Analysing receipt...',
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (isMobile) ...[
              FloatingActionButton(
                heroTag: 'camera_fab',
                onPressed: _parsing
                    ? null
                    : () => _pickAndParseReceipt(isNl, camera: true),
                backgroundColor: BigDoggTheme.teal800,
                child: const Icon(Icons.camera_alt,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(height: 12),
            ],
            FloatingActionButton(
              heroTag: 'upload_fab',
              onPressed: _parsing
                  ? null
                  : () => _pickAndParseReceipt(isNl, camera: false),
              backgroundColor: BigDoggTheme.teal800,
              child: const Icon(Icons.folder_open,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(height: 12),
            FloatingActionButton(
              heroTag: 'add_fab',
              onPressed: () => _showAddExpense(isNl),
              child: const Icon(Icons.add, color: Colors.white, size: 24),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildInvestmentsTab(bool isNl) {
    final currentYear = DateTime.now().year;
    double totalThisYear = 0;
    for (final inv in _investments) {
      totalThisYear +=
          (inv['current_year_depreciation'] as num? ?? 0).toDouble();
    }

    return Stack(
      children: [
        _loadingInvestments
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_investments.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: BigDoggTheme.teal800,
                          borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          _miniTotal(isNl ? 'Investeringen' : 'Investments',
                              '${_investments.length}'),
                          _miniTotal(
                              isNl
                                  ? 'Afschr. $currentYear'
                                  : 'Depr. $currentYear',
                              '€${totalThisYear.toStringAsFixed(2)}'),
                        ],
                      ),
                    ),
                  Expanded(
                    child: _investments.isEmpty
                        ? Center(
                            child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.trending_up_outlined,
                                  size: 64,
                                  color: BigDoggTheme.lightTextHint),
                              const SizedBox(height: 16),
                              Text(
                                  isNl
                                      ? 'Nog geen investeringen'
                                      : 'No investments yet',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      color: BigDoggTheme
                                          .lightTextSecondary)),
                              const SizedBox(height: 8),
                              Text(
                                  isNl
                                      ? 'Tik + om een investering toe te voegen'
                                      : 'Tap + to add an investment',
                                  style: const TextStyle(
                                      color:
                                          BigDoggTheme.lightTextHint)),
                            ],
                          ))
                        : ListView.builder(
                            // Bottom padding clears the stack of FABs so the
                            // last entry's delete icon stays tappable.
                            padding: const EdgeInsets.fromLTRB(
                                12, 4, 12, 220),
                            itemCount: _investments.length,
                            itemBuilder: (_, i) {
                              final inv = _investments[i];
                              final schedule =
                                  (inv['depreciation_schedule'] as List? ??
                                      []);
                              final yearDep =
                                  inv['current_year_depreciation'] ?? 0;
                              return Container(
                                margin:
                                    const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                    color: BigDoggTheme.lightSurface,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    border: Border.all(
                                        color:
                                            BigDoggTheme.lightBorder)),
                                child: ExpansionTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        BigDoggTheme.teal100,
                                    child: Icon(
                                        _categoryIcon(
                                            inv['category'] ??
                                                'general'),
                                        color: BigDoggTheme.teal800,
                                        size: 20),
                                  ),
                                  title: Text(inv['description'] ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: BigDoggTheme.teal800)),
                                  subtitle: Text(
                                    '${inv['purchase_date']} · €${inv['amount']} · ${inv['depreciation_years']}j',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: BigDoggTheme
                                            .lightTextSecondary),
                                  ),
                                  trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                  isNl
                                                      ? 'Dit jaar'
                                                      : 'This year',
                                                  style: const TextStyle(
                                                      fontSize: 10,
                                                      color: BigDoggTheme
                                                          .lightTextSecondary)),
                                              Text(
                                                  '€${(yearDep as num).toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: BigDoggTheme
                                                          .teal800,
                                                      fontSize: 13)),
                                            ]),
                                        const SizedBox(width: 4),
                                        IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: BigDoggTheme.error,
                                                size: 18),
                                            onPressed: () =>
                                                _deleteInvestment(
                                                    inv['id'])),
                                      ]),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 0, 16, 12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              isNl
                                                  ? 'Afschrijvingsschema'
                                                  : 'Depreciation schedule',
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  fontSize: 13,
                                                  color: BigDoggTheme
                                                      .teal800)),
                                          const SizedBox(height: 8),
                                          ...schedule
                                              .map((s) => Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 3),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Text(
                                                            '${s['year']}',
                                                            style: TextStyle(
                                                                fontSize:
                                                                    12,
                                                                fontWeight: s['year'] ==
                                                                        currentYear
                                                                    ? FontWeight
                                                                        .bold
                                                                    : FontWeight
                                                                        .normal,
                                                                color: s['year'] ==
                                                                        currentYear
                                                                    ? BigDoggTheme
                                                                        .teal800
                                                                    : BigDoggTheme
                                                                        .lightTextSecondary)),
                                                        Text(
                                                            '€${(s['amount'] as num).toStringAsFixed(2)}',
                                                            style: TextStyle(
                                                                fontSize:
                                                                    12,
                                                                fontWeight: s['year'] ==
                                                                        currentYear
                                                                    ? FontWeight
                                                                        .bold
                                                                    : FontWeight
                                                                        .normal,
                                                                color: BigDoggTheme
                                                                    .teal800)),
                                                        Text(
                                                            isNl
                                                                ? 'Restwaarde: €${(s['remaining'] as num).toStringAsFixed(2)}'
                                                                : 'Remaining: €${(s['remaining'] as num).toStringAsFixed(2)}',
                                                            style: const TextStyle(
                                                                fontSize:
                                                                    11,
                                                                color: BigDoggTheme
                                                                    .lightTextSecondary)),
                                                      ],
                                                    ),
                                                  ))
                                              .toList(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'inv_add_fab',
            onPressed: () => _showAddInvestment(isNl),
            child: const Icon(Icons.add, color: Colors.white, size: 24),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNl = context.watch<AppProvider>().language == 'nl';
    final isMobile = _isMobile();

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
                fontWeight: FontWeight.w600,
                fontFamily: 'PlusJakartaSans'),
            tabs: [
              Tab(text: isNl ? 'Kosten' : 'Expenses'),
              Tab(text: isNl ? 'Investeringen' : 'Investments'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildExpensesTab(isNl, isMobile),
              _buildInvestmentsTab(isNl),
            ],
          ),
        ),
      ],
    );
  }

  /// Compact label/value cell used inside the totals strip on the
  /// Kosten and Investeringen tabs. Designed to fit three across without
  /// dominating vertical real estate.
  Widget _miniTotal(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 10)),
          const SizedBox(height: 1),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
        ],
      ),
    );
  }
}
