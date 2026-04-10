import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/invoices_service.dart';
import '../providers/app_provider.dart';
import '../theme.dart';

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

  @override
  Widget build(BuildContext context) {
    final isNl = context.watch<AppProvider>().language == 'nl';

    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_invoice == null) return Scaffold(body: Center(child: Text(isNl ? 'Factuur niet gevonden' : 'Invoice not found')));

    final status = _invoice!['status'] ?? 'draft';
    final client = _invoice!['clients'];

    return Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      appBar: AppBar(
        backgroundColor: BigDoggTheme.teal800,
        title: Text(_invoice!['invoice_number'], style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor(status).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusLabel(status, isNl),
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
            _card([
              Text(isNl ? 'Klant' : 'Client',
                  style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextSecondary)),
              const SizedBox(height: 4),
              Text(client['contact_name'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: BigDoggTheme.teal800)),
              if (client['company_name'] != null && client['company_name'].toString().isNotEmpty)
                Text(client['company_name'],
                    style: const TextStyle(color: BigDoggTheme.lightTextSecondary)),
              Text(client['email'] ?? '',
                  style: const TextStyle(color: BigDoggTheme.lightTextHint, fontSize: 12)),
            ]),
            const SizedBox(height: 12),
            _card([
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isNl ? 'Factuurdatum' : 'Invoice date',
                            style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextSecondary)),
                        Text(_invoice!['invoice_date'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isNl ? 'Vervaldatum' : 'Due date',
                            style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextSecondary)),
                        Text(_invoice!['due_date'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 12),
            _card([
              Text(isNl ? 'Regels' : 'Lines',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: BigDoggTheme.teal800)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(flex: 3, child: Text(isNl ? 'Omschrijving' : 'Description',
                      style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextSecondary))),
                  Expanded(child: Text(isNl ? 'Aantal' : 'Qty',
                      style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextSecondary),
                      textAlign: TextAlign.right)),
                  Expanded(child: Text(isNl ? 'Prijs' : 'Price',
                      style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextSecondary),
                      textAlign: TextAlign.right)),
                  Expanded(child: Text(isNl ? 'Totaal' : 'Total',
                      style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextSecondary),
                      textAlign: TextAlign.right)),
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
                        Text(line['description'],
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text('${line['btw_rate']}% BTW',
                            style: const TextStyle(fontSize: 11, color: BigDoggTheme.lightTextHint)),
                      ],
                    )),
                    Expanded(child: Text('${line['quantity']}x',
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: BigDoggTheme.lightTextSecondary))),
                    Expanded(child: Text('€${line['unit_price_ex_btw']}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: BigDoggTheme.lightTextSecondary))),
                    Expanded(child: Text('€${line['line_total_ex_btw']}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                  ],
                ),
              )),
              const Divider(),
              _totalRow(isNl ? 'Subtotaal ex BTW' : 'Subtotal ex BTW', '€${_invoice!['subtotal_ex_btw']}'),
              _totalRow('BTW', '€${_invoice!['btw_amount']}'),
              const SizedBox(height: 4),
              _totalRow(isNl ? 'Totaal incl BTW' : 'Total incl BTW', '€${_invoice!['total_incl_btw']}',
                  bold: true, large: true),
            ]),
            const SizedBox(height: 12),
            if (status != 'paid') ...[
              if (status == 'draft')
                _actionButton(
                  isNl ? 'Markeer als verstuurd' : 'Mark as Sent',
                  BigDoggTheme.info,
                  Icons.send,
                  () async {
                    await InvoicesService.updateStatus(widget.invoiceId, 'sent');
                    _loadInvoice();
                  },
                ),
              if (status == 'sent' || status == 'overdue') ...[
                _actionButton(
                  isNl ? 'Markeer als betaald' : 'Mark as Paid',
                  BigDoggTheme.success,
                  Icons.check_circle_outline,
                  () async {
                    await InvoicesService.updateStatus(widget.invoiceId, 'paid');
                    _loadInvoice();
                  },
                ),
                const SizedBox(height: 8),
                _actionButton(
                  isNl ? 'Stuur herinnering' : 'Send Reminder',
                  BigDoggTheme.warning,
                  Icons.notifications_outlined,
                  () async {
                    await InvoicesService.sendReminder(widget.invoiceId);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isNl ? 'Herinnering verstuurd' : 'Reminder sent'),
                          backgroundColor: BigDoggTheme.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ],
              if (status == 'sent')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _actionButton(
                    isNl ? 'Markeer als verlopen' : 'Mark as Overdue',
                    BigDoggTheme.error,
                    Icons.warning_amber_outlined,
                    () async {
                      await InvoicesService.updateStatus(widget.invoiceId, 'overdue');
                      _loadInvoice();
                    },
                  ),
                ),
              if (status == 'draft')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _actionButton(
                    isNl ? 'Concept verwijderen' : 'Delete Draft',
                    BigDoggTheme.lightTextSecondary,
                    Icons.delete_outline,
                    () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(isNl ? 'Factuur verwijderen' : 'Delete Invoice'),
                          content: Text(isNl
                              ? 'Weet je zeker dat je dit concept wilt verwijderen?'
                              : 'Are you sure you want to delete this draft?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(isNl ? 'Annuleren' : 'Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(backgroundColor: BigDoggTheme.error),
                              child: Text(isNl ? 'Verwijderen' : 'Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await InvoicesService.deleteInvoice(widget.invoiceId);
                        if (mounted) Navigator.pop(context, true);
                      }
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _totalRow(String label, String value, {bool bold = false, bool large = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            color: bold ? BigDoggTheme.lightTextPrimary : BigDoggTheme.lightTextSecondary,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontSize: large ? 16 : 14,
          )),
          Text(value, style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontSize: large ? 16 : 14,
            color: bold ? BigDoggTheme.teal800 : BigDoggTheme.lightTextPrimary,
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
        label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}