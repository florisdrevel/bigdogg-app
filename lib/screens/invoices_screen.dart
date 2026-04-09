import 'package:flutter/material.dart';
import '../services/invoices_service.dart';
import '../services/clients_service.dart';
import '../services/products_service.dart';
import '../app_theme.dart';
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

  void _showCreateInvoice() async {
    final clientsResult = await ClientsService.getClients();
    final productsResult = await ProductsService.getProducts();

    if (!clientsResult['success'] || !productsResult['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load data: ${clientsResult['message']} / ${productsResult['message']}',
            ),
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
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('New Invoice'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          value: selectedClientId,
                          decoration: const InputDecoration(
                            labelText: 'Client',
                          ),
                          items:
                              clients
                                  .map(
                                    (c) => DropdownMenuItem<String>(
                                      value: c['id'] as String,
                                      child: Text(
                                        c['company_name'] ?? c['contact_name'],
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (val) => setDialogState(
                                () => selectedClientId = val,
                              ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Lines',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...lines.asMap().entries.map((entry) {
                          final i = entry.key;
                          final line = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.bgPage,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        line['description'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${line['quantity']}x  ·  €${line['unit_price_ex_btw']}  ·  ${line['btw_rate']}% BTW',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: AppColors.danger,
                                    size: 20,
                                  ),
                                  onPressed:
                                      () => setDialogState(
                                        () => lines.removeAt(i),
                                      ),
                                ),
                              ],
                            ),
                          );
                        }),
                        TextButton.icon(
                          onPressed: () {
                            _showAddLine(context, products, (line) {
                              setDialogState(() => lines.add(line));
                            });
                          },
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('Add line'),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed:
                          selectedClientId == null || lines.isEmpty
                              ? null
                              : () async {
                                Navigator.pop(context);
                                final result = await InvoicesService.createInvoice(
                                  clientId: selectedClientId!,
                                  lines: lines,
                                );
                                if (result['success']) _loadInvoices();
                              },
                      child: const Text('Create'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showAddLine(
    BuildContext context,
    List products,
    Function(Map<String, dynamic>) onAdd,
  ) {
    String? selectedProductId;
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController();
    final descController = TextEditingController();
    int btwRate = 21;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Add Line'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: selectedProductId,
                          decoration: const InputDecoration(
                            labelText: 'Product (optional)',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Custom line'),
                            ),
                            ...products.map(
                              (p) => DropdownMenuItem<String>(
                                value: p['id'] as String,
                                child: Text(p['name']),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setDialogState(() {
                              selectedProductId = val;
                              if (val != null) {
                                final p = products.firstWhere(
                                  (p) => p['id'] == val,
                                );
                                descController.text = p['name'];
                                priceController.text =
                                    p['unit_price'].toString();
                                btwRate = p['btw_rate'];
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descController,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: qtyController,
                                decoration: const InputDecoration(
                                  labelText: 'Qty',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: priceController,
                                decoration: const InputDecoration(
                                  labelText: 'Price ex BTW',
                                ),
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                              ),
                            ),
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
                          onChanged:
                              (val) => setDialogState(() => btwRate = val!),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (descController.text.isEmpty ||
                            priceController.text.isEmpty)
                          return;
                        Navigator.pop(context);
                        onAdd({
                          'description': descController.text,
                          'quantity': double.parse(qtyController.text),
                          'unit_price_ex_btw': double.parse(
                            priceController.text,
                          ),
                          'btw_rate': btwRate,
                        });
                      },
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
      backgroundColor: AppColors.bgPage,
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateInvoice,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
          ? _buildEmpty()
          : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Column(
      children: [
        _buildAIBanner(),
        const Expanded(
          child: EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No invoices yet',
            subtitle: 'Tap + to create your first invoice',
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    return Column(
      children: [
        _buildAIBanner(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: _invoices.length,
            itemBuilder: (context, index) {
              final inv = _invoices[index];
              final status = inv['status'] ?? 'draft';
              return _InvoiceCard(
                invoice: inv,
                status: status,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InvoiceDetailScreen(invoiceId: inv['id']),
                  ),
                ).then((_) => _loadInvoices()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAIBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PromptInvoiceScreen()),
      ).then((created) {
        if (created == true) _loadInvoices();
      }),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          gradient: AppGradients.indigoAccent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Invoice',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: -0.1,
                    ),
                  ),
                  Text(
                    'Describe it, we\'ll build it',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.white70,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final dynamic invoice;
  final String status;
  final VoidCallback onTap;

  const _InvoiceCard({
    required this.invoice,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: AppDecorations.card,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        invoice['invoice_number'],
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    invoice['clients']?['contact_name'] ?? '',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    invoice['invoice_date'] ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '€${invoice['total_incl_btw']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
