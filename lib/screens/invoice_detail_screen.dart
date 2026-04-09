import 'package:flutter/material.dart';
import '../services/invoices_service.dart';
import '../app_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_invoice == null) {
      return const Scaffold(
        body: Center(child: Text('Invoice not found')),
      );
    }

    final status = _invoice!['status'] ?? 'draft';
    final client = _invoice!['clients'];

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(gradient: AppGradients.navySubtle),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              _invoice!['invoice_number'],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(child: StatusBadge(status)),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Client card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppDecorations.card,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppGradients.navySubtle,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (client['contact_name'] as String? ?? '?')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client['contact_name'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (client['company_name'] != null &&
                            client['company_name'].toString().isNotEmpty)
                          Text(
                            client['company_name'],
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        Text(
                          client['email'] ?? '',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Dates card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppDecorations.card,
              child: Row(
                children: [
                  Expanded(
                    child: _DateItem(
                      label: 'Invoice date',
                      value: _invoice!['invoice_date'] ?? '',
                      icon: Icons.calendar_today_outlined,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: AppColors.borderLight,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DateItem(
                      label: 'Due date',
                      value: _invoice!['due_date'] ?? '',
                      icon: Icons.event_outlined,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Lines card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppDecorations.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Line items',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Header row
                  const Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Qty',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Price',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  ..._lines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  line['description'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${line['btw_rate']}% BTW',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${line['quantity']}×',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '€${line['unit_price_ex_btw']}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '€${line['line_total_ex_btw']}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  _TotalRow('Subtotal ex BTW', '€${_invoice!['subtotal_ex_btw']}'),
                  _TotalRow('BTW', '€${_invoice!['btw_amount']}'),
                  const SizedBox(height: 6),
                  _TotalRow(
                    'Total incl BTW',
                    '€${_invoice!['total_incl_btw']}',
                    bold: true,
                    large: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            if (status != 'paid') ...[
              if (status == 'draft')
                _ActionButton(
                  label: 'Mark as Sent',
                  color: AppColors.info,
                  icon: Icons.send_rounded,
                  onTap: () async {
                    await InvoicesService.updateStatus(
                      widget.invoiceId,
                      'sent',
                    );
                    _loadInvoice();
                  },
                ),
              if (status == 'sent' || status == 'overdue') ...[
                _ActionButton(
                  label: 'Mark as Paid',
                  color: AppColors.success,
                  icon: Icons.check_circle_outline_rounded,
                  onTap: () async {
                    await InvoicesService.updateStatus(
                      widget.invoiceId,
                      'paid',
                    );
                    _loadInvoice();
                  },
                ),
                const SizedBox(height: 10),
                _ActionButton(
                  label: 'Send Reminder',
                  color: AppColors.warning,
                  icon: Icons.notifications_outlined,
                  onTap: () async {
                    await InvoicesService.sendReminder(widget.invoiceId);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reminder sent')),
                      );
                    }
                  },
                ),
              ],
              if (status == 'sent') ...[
                const SizedBox(height: 10),
                _ActionButton(
                  label: 'Mark as Overdue',
                  color: AppColors.danger,
                  icon: Icons.warning_amber_rounded,
                  onTap: () async {
                    await InvoicesService.updateStatus(
                      widget.invoiceId,
                      'overdue',
                    );
                    _loadInvoice();
                  },
                ),
              ],
              if (status == 'draft') ...[
                const SizedBox(height: 10),
                _ActionButton(
                  label: 'Delete Draft',
                  color: AppColors.textSecondary,
                  icon: Icons.delete_outline_rounded,
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Invoice'),
                        content: const Text(
                          'Are you sure you want to delete this draft invoice?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.danger,
                            ),
                            child: const Text('Delete'),
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
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _DateItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DateItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final bool large;

  const _TotalRow(
    this.label,
    this.value, {
    this.bold = false,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: bold ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              fontSize: large ? 15 : 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              fontSize: large ? 15 : 13,
              color: AppColors.textPrimary,
              letterSpacing: bold ? -0.2 : 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
