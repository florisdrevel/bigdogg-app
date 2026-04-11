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
                  decoration: InputDecoration(labelText: isNl ? 'Klant' : 'Client'),
                  items: clients.map((c) => DropdownMenuItem<String>(
                    value: c['id'] as String,
                    child: Text(c['company_name'] ?? c['contact_name']),
                  )).toList(),
                  onChanged: (val) => setDialogState(() => selectedClientId = val),
                ),
                const SizedBox(height: 16),
                Text(isNl ? 'Regels' : 'Lines', style: const TextStyle(fontWeight: FontWeight.w600)),
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
                                Text(line['description'], style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text('${line['quantity']}x €${line['unit_price_ex_btw']} (${line['btw_rate']}% BTW)',
                                    style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextSecondary)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: BigDoggTheme.error),
                            onPressed: () => setDialogState(() => lines.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () => _showAddLine(context, products, isNl, (line) {
                    setDialogState(() => lines.add(line));
                  }),
                  icon: const Icon(Icons.add),
                  label: Text(isNl ? 'Regel toevoegen' : 'Add line'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(isNl ? 'Annuleren' : 'Cancel')),
            ElevatedButton(
              onPressed: selectedClientId == null || lines.isEmpty ? null : () async {
                Navigator.pop(context);
                final result = await InvoicesService.createInvoice(clientId: selectedClientId!, lines: lines);
                if (result['success']) _loadInvoices();
              },
              child: Text(isNl ? 'Aanmaken' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddLine(BuildContext context, List products, bool isNl, Function(Map<String, dynamic>) onAdd) {
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
                  decoration: InputDecoration(labelText: isNl ? 'Product (optioneel)' : 'Product (optional)'),
                  items: [
                    DropdownMenuItem(value: null, child: Text(isNl ? 'Aangepaste regel' : 'Custom line')),
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
                TextField(controller: descController, decoration: InputDecoration(labelText: isNl ? 'Omschrijving' : 'Description')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: qtyController, decoration: InputDecoration(labelText: isNl ? 'Aantal' : 'Qty'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: priceController, decoration: InputDecoration(labelText: isNl ? 'Prijs ex BTW' : 'Price ex BTW'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
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
            TextButton(onPressed: () => Navigator.pop(context), child: Text(isNl ? 'Annuleren' : 'Cancel')),
            ElevatedButton(
              onPressed: () {
                if (descController.text.isEmpty || priceController.text.isEmpty) return;
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

    return Stack(
      children: [
        _loading
            ? const Center(child: CircularProgressIndicator())
            : _invoices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 64, color: BigDoggTheme.lightTextHint),
                        const SizedBox(height: 16),
                        Text(isNl ? 'Nog geen facturen' : 'No invoices yet',
                            style: const TextStyle(fontSize: 18, color: BigDoggTheme.lightTextSecondary)),
                        const SizedBox(height: 8),
                        Text(isNl ? 'Tik + om je eerste factuur aan te maken' : 'Tap + to create your first invoice',
                            style: const TextStyle(color: BigDoggTheme.lightTextHint)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _invoices.length,
                    itemBuilder: (context, index) {
                      final inv = _invoices[index];
                      final status = inv['status'] ?? 'draft';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: BigDoggTheme.lightSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: BigDoggTheme.lightBorder),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (context) => InvoiceDetailScreen(invoiceId: inv['id'])))
                              .then((_) => _loadInvoices()),
                          title: Row(
                            children: [
                              Text(inv['invoice_number'], style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _statusColor(status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _statusLabel(status, isNl),
                                  style: TextStyle(fontSize: 11, color: _statusColor(status), fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(inv['clients']?['contact_name'] ?? '', style: const TextStyle(color: BigDoggTheme.lightTextSecondary)),
                              Text(inv['invoice_date'] ?? '', style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextHint)),
                            ],
                          ),
                          trailing: Text('€${inv['total_incl_btw']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: BigDoggTheme.teal800)),
                        ),
                      );
                    },
                  ),
        // AI button — above the + button
        Positioned(
          bottom: 88,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'ai_fab',
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (context) => const PromptInvoiceScreen()))
                .then((created) { if (created == true) _loadInvoices(); }),
            backgroundColor: Colors.grey.shade200,
            elevation: 2,
            mini: false,
            child: const Icon(Icons.smart_toy_outlined, color: Colors.grey),
          ),
        ),
        // + button
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