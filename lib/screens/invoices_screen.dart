import 'package:flutter/material.dart';
import '../services/invoices_service.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final String invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  Map<String, dynamic>? _invoice;
  List<dynamic> _lines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    setState(() => _loading = true);
    final result = await InvoicesService.getInvoice(widget.invoiceId);
    setState(() {
      _loading = false;
      if (result['success']) {
        _invoice = result['invoice'];
        _lines = result['lines'];
      }
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_invoice == null) return const Scaffold(body: Center(child: Text('Invoice not found')));

    final status = _invoice!['status'] ?? 'draft';
    final client = _invoice!['clients'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(_invoice!['invoice_number'], style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor(status).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _statusLabel(status),
              style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Client', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    const SizedBox(height: 4),
                    Text(client['contact_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (client['company_name'] != null && client['company_name'].toString().isNotEmpty)
                      Text(client['company_name'], style: const TextStyle(color: Color(0xFF6B7280))),
                    Text(client['email'] ?? '', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Invoice date', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                          Text(_invoice!['invoice_date'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Due date', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                          Text(_invoice!['due_date'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Lines', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Expanded(flex: 3, child: Text('Description', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
                        Expanded(child: Text('Qty', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)), textAlign: TextAlign.right)),
                        Expanded(child: Text('Price', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)), textAlign: TextAlign.right)),
                        Expanded(child: Text('Total', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)), textAlign: TextAlign.right)),
                      ],
                    ),
                    const Divider(),
                    ..._lines.map((line) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(line['description'], style: const TextStyle(fontWeight: FontWeight.w500)),
                              Text('${line['btw_rate']}% BTW', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                            ],
                          )),
                          Expanded(child: Text('${line['quantity']}x', textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFF6B7280)))),
                          Expanded(child: Text('€${line['unit_price_ex_btw']}', textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFF6B7280)))),
                          Expanded(child: Text('€${line['line_total_ex_btw']}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
                        ],
                      ),
                    )),
                    const Divider(),
                    _totalRow('Subtotal ex BTW', '€${_invoice!['subtotal_ex_btw']}'),
                    _totalRow('BTW', '€${_invoice!['btw_amount']}'),
                    const SizedBox(height: 4),
                    _totalRow('Total incl BTW', '€${_invoice!['total_incl_btw']}', bold: true, large: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (status != 'paid') ...[
              if (status == 'draft')
                _actionButton('Mark as Sent', const Color(0xFF2563EB), Icons.send, () async {
                  await InvoicesService.updateStatus(widget.invoiceId, 'sent');
                  _loadInvoice();
                }),
              if (status == 'sent' || status == 'overdue') ...[
                _actionButton('Mark as Paid', const Color(0xFF059669), Icons.check_circle_outline, () async {
                  await InvoicesService.updateStatus(widget.invoiceId, 'paid');
                  _loadInvoice();
                }),
                const SizedBox(height: 8),
                _actionButton('Send Reminder', const Color(0xFFF59E0B), Icons.notifications_outlined, () async {
                  await InvoicesService.sendReminder(widget.invoiceId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reminder sent'),
                        backgroundColor: Color(0xFF059669),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }),
              ],
              if (status == 'sent')
                _actionButton('Mark as Overdue', const Color(0xFFDC2626), Icons.warning_amber_outlined, () async {
                  await InvoicesService.updateStatus(widget.invoiceId, 'overdue');
                  _loadInvoice();
                }),
              if (status == 'draft') ...[
                const SizedBox(height: 8),
                _actionButton('Delete Draft', const Color(0xFF6B7280), Icons.delete_outline, () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Invoice'),
                      content: const Text('Are you sure you want to delete this draft invoice?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await InvoicesService.deleteInvoice(widget.invoiceId);
                    if (mounted) Navigator.pop(context, true);
                  }
                }),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool bold = false, bool large = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            color: bold ? Colors.black : const Color(0xFF6B7280),
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontSize: large ? 16 : 14,
          )),
          Text(value, style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontSize: large ? 16 : 14,
          )),
        ],
      ),
    );
  }

  Widget _actionButton(String label, Color color, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}