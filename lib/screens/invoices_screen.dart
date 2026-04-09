import 'package:flutter/material.dart';
import '../services/invoices_service.dart';
import '../services/clients_service.dart';
import '../services/products_service.dart';
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
      case 'paid': return const Color(0xFF059669);
      case 'sent': return const Color(0xFF2563EB);
      case 'overdue': return const Color(0xFFDC2626);
      default: return const Color(0xFF6B7280);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid': return 'Paid';
      case 'sent': return 'Sent';
      case 'overdue': return 'Overdue';
      default: return 'Draft';
    }
  }

  void _showCreateInvoice() async {
    final clientsResult = await ClientsService.getClients();
    final productsResult = await ProductsService.getProducts();

    if (!clientsResult['success'] || !productsResult['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: ${clientsResult['message']} / ${productsResult['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final clients = clientsResult['clients'] as List;
    final products = productsResult['products'] as List;

    if (!mounted) return;

    String? selectedClientId;
    List<Map<String, dynamic>> lines = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Invoice'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedClientId,
                  decoration: const InputDecoration(labelText: 'Client'),
                  items: clients.map((c) => DropdownMenuItem<String>(
                    value: c['id'] as String,
                    child: Text(c['company_name'] ?? c['contact_name']),
                  )).toList(),
                  onChanged: (val) => setDialogState(() => selectedClientId = val),
                ),
                const SizedBox(height: 16),
                const Text('Lines', style: TextStyle(fontWeight: FontWeight.w600)),
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
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444)),
                            onPressed: () => setDialogState(() => lines.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () {
                    _showAddLine(context, products, (line) {
                      setDialogState(() => lines.add(line));
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add line'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selectedClientId == null || lines.isEmpty ? null : () async {
                Navigator.pop(context);
                final result = await InvoicesService.createInvoice(
                  clientId: selectedClientId!,
                  lines: lines,
                );
                if (result['success']) _loadInvoices();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A2E),
                foregroundColor: Colors.white,
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddLine(BuildContext context, List products, Function(Map<String, dynamic>) onAdd) {
    String? selectedProductId;
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController();
    final descController = TextEditingController();
    int btwRate = 21;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Line'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedProductId,
                  decoration: const InputDecoration(labelText: 'Product (optional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Custom line')),
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
                TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: qtyController, decoration: const InputDecoration(labelText: 'Qty'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Price ex BTW'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A2E),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Invoices', style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PromptInvoiceScreen()),
            ).then((created) {
              if (created == true) _loadInvoices();
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateInvoice,
        backgroundColor: const Color(0xFF1A1A2E),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 64, color: Color(0xFFD1D5DB)),
                      SizedBox(height: 16),
                      Text('No invoices yet', style: TextStyle(fontSize: 18, color: Color(0xFF6B7280))),
                      SizedBox(height: 8),
                      Text('Tap + to create your first invoice', style: TextStyle(color: Color(0xFF9CA3AF))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _invoices.length,
                  itemBuilder: (context, index) {
                    final inv = _invoices[index];
                    final status = inv['status'] ?? 'draft';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InvoiceDetailScreen(invoiceId: inv['id']),
                          ),
                        ).then((_) => _loadInvoices()),
                        title: Row(
                          children: [
                            Text(inv['invoice_number'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _statusLabel(status),
                                style: TextStyle(fontSize: 12, color: _statusColor(status), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(inv['clients']?['contact_name'] ?? '', style: const TextStyle(color: Color(0xFF6B7280))),
                            Text(inv['invoice_date'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                          ],
                        ),
                        trailing: Text(
                          '€${inv['total_incl_btw']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}