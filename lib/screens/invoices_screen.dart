import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/invoices_service.dart';
import '../services/clients_service.dart';
import '../services/products_service.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import 'invoice_detail_screen.dart';
import 'prompt_invoice_screen.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  List<dynamic> _invoices = [];
  bool _loading = true;

  String? _filterStatus;
  int? _filterQuarter;
  int? _filterMonth;
  String _sortBy = 'date_desc';

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _loading = true);
    final result = await InvoicesService.getInvoices();
    setState(() {
      _loading = false;
      if (result['success']) _invoices = result['invoices'];
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

  List<dynamic> get _filteredInvoices {
    List<dynamic> list = List.from(_invoices);

    if (_filterStatus != null) {
      list = list.where((inv) => inv['status'] == _filterStatus).toList();
    }

    if (_filterMonth != null) {
      list = list.where((inv) {
        final date = inv['invoice_date'] as String?;
        if (date == null) return false;
        return int.tryParse(date.split('-')[1]) == _filterMonth;
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
        final month = int.tryParse(date.split('-')[1]) ?? 0;
        return months.contains(month);
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

  Color _statusColor(String status) {
    switch (status) {
      case 'paid': return BigDoggTheme.success;
      case 'sent': return BigDoggTheme.info;
      case 'overdue': return BigDoggTheme.error;
      default: return BigDoggTheme.lightTextSecondary;
    }
  }

  String _statusLabel(String status, bool isNl) {
    switch (status) {
      case 'paid': return isNl ? 'Betaald' : 'Paid';
      case 'sent': return isNl ? 'Verstuurd' : 'Sent';
      case 'overdue': return isNl ? 'Verlopen' : 'Overdue';
      default: return isNl ? 'Concept' : 'Draft';
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
                          _filterChip(isNl ? 'Alle' : 'All', _filterStatus == null, () {
                            setSheetState(() => _filterStatus = null);
                            setState(() => _filterStatus = null);
                          }),
                          _filterChip(isNl ? 'Betaald' : 'Paid', _filterStatus == 'paid', () {
                            setSheetState(() => _filterStatus = 'paid');
                            setState(() => _filterStatus = 'paid');
                          }),
                          _filterChip(isNl ? 'Verstuurd' : 'Sent', _filterStatus == 'sent', () {
                            setSheetState(() => _filterStatus = 'sent');
                            setState(() => _filterStatus = 'sent');
                          }),
                          _filterChip(isNl ? 'Verlopen' : 'Overdue', _filterStatus == 'overdue', () {
                            setSheetState(() => _filterStatus = 'overdue');
                            setState(() => _filterStatus = 'overdue');
                          }),
                          _filterChip(isNl ? 'Concept' : 'Draft', _filterStatus == 'draft', () {
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
                              (i) => _filterChip('Q${i + 1}',
                                  _filterQuarter == i + 1, () {
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
                              ? ['Jan', 'Feb', 'Mrt', 'Apr', 'Mei', 'Jun',
                                  'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dec']
                              : ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                          return _filterChip(months[i], _filterMonth == i + 1, () {
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
                              _filterStatus = null;
                              _filterQuarter = null;
                              _filterMonth = null;
                              _sortBy = 'date_desc';
                            });
                            Navigator.pop(context);
                          },
                          child: Text(
                              isNl ? 'Filters wissen' : 'Clear filters',
                              style: const TextStyle(color: BigDoggTheme.error)),
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
              color: selected ? BigDoggTheme.teal800 : BigDoggTheme.lightBorder),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : BigDoggTheme.lightTextSecondary)),
      ),
    );
  }

  bool get _hasActiveFilters =>
      _filterStatus != null ||
      _filterQuarter != null ||
      _filterMonth != null ||
      _sortBy != 'date_desc';

  void _showCreateInvoice(bool isNl) async {
    final clientsResult = await ClientsService.getClients();
    final productsResult = await ProductsService.getProducts();
    if (!clientsResult['success'] || !productsResult['success']) return;
    final clients = clientsResult['clients'] as List;
    final products = productsResult['products'] as List;
    if (!mounted) return;

    String? selectedClientId;
    List<Map<String, dynamic>> lines = [];

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
                  decoration: InputDecoration(
                      labelText: isNl ? 'Klant' : 'Client'),
                  items: clients
                      .map((c) => DropdownMenuItem<String>(
                            value: c['id'] as String,
                            child: Text(c['company_name'] ?? c['contact_name']),
                          ))
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedClientId = val),
                ),
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
                                        color: BigDoggTheme.lightTextSecondary)),
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
                      final result = await InvoicesService.createInvoice(
                          clientId: selectedClientId!, lines: lines);
                      if (result['success'] && mounted) {
                        await _loadInvoices();
                        final invoiceId = result['invoice']['id'];
                        _navigateToInvoice(invoiceId);
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
                        final p = products.firstWhere((p) => p['id'] == val);
                        descController.text = p['name'];
                        priceController.text = p['unit_price'].toString();
                        btwRate = p['btw_rate'];
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: descController,
                    decoration: InputDecoration(
                        labelText: isNl ? 'Omschrijving' : 'Description')),
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
                  decoration: const InputDecoration(labelText: 'BTW'),
                  items: const [
                    DropdownMenuItem(value: 21, child: Text('21%')),
                    DropdownMenuItem(value: 9, child: Text('9%')),
                    DropdownMenuItem(value: 0, child: Text('0%')),
                  ],
                  onChanged: (val) => setDialogState(() => btwRate = val!),
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
                Navigator.pop(context);
                onAdd({
                  'description': descController.text,
                  'quantity': double.parse(qtyController.text),
                  'unit_price_ex_btw': double.parse(priceController.text),
                  'btw_rate': btwRate,
                });
              },
              child: Text(isNl ? 'Toevoegen' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNl = context.watch<AppProvider>().language == 'nl';
    final filtered = _filteredInvoices;

    return Stack(
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: BigDoggTheme.lightSurface,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${filtered.length} ${isNl ? 'facturen' : 'invoices'}',
                      style: const TextStyle(
                          color: BigDoggTheme.lightTextSecondary, fontSize: 13),
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
                                        ? 'Nog geen facturen'
                                        : 'No invoices yet'),
                                style: const TextStyle(
                                    fontSize: 18,
                                    color: BigDoggTheme.lightTextSecondary),
                              ),
                              const SizedBox(height: 8),
                              if (_hasActiveFilters)
                                TextButton(
                                  onPressed: () => setState(() {
                                    _filterStatus = null;
                                    _filterQuarter = null;
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
                                contentPadding: const EdgeInsets.symmetric(
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
                                            color:
                                                BigDoggTheme.lightTextHint)),
                                  ],
                                ),
                                trailing: Text('€${inv['total_incl_btw']}',
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
        ),
        Positioned(
          bottom: 88,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'ai_fab',
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const PromptInvoiceScreen()))
                .then((result) {
              if (result is String) {
                _loadInvoices();
                _navigateToInvoice(result);
              } else if (result == true) {
                _loadInvoices();
              }
            }),
            backgroundColor: BigDoggTheme.teal800,
            elevation: 2,
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white),
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'create_fab',
            onPressed: () => _showCreateInvoice(isNl),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}