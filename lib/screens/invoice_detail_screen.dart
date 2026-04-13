import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/invoices_service.dart';
import '../services/email_service.dart';
import '../services/payments_service.dart';
import '../services/api_config.dart';
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
  bool _generatingLink = false;

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

  Future<void> _downloadPdf(bool isNl) async {
    final token = await InvoicesService.getToken();
    final url = '${ApiConfig.baseUrl}/api/v1/pdf/${widget.invoiceId}';
    final uri = Uri.parse('$url?token=$token');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isNl ? 'Kan PDF niet openen' : 'Could not open PDF'),
          backgroundColor: BigDoggTheme.error,
        ));
      }
    }
  }

  Future<void> _generatePaymentLink(bool isNl) async {
    setState(() => _generatingLink = true);
    final result = await PaymentsService.createPaymentLink(widget.invoiceId);
    setState(() => _generatingLink = false);

    if (result['success']) {
      await _loadInvoice();
      if (mounted) _showQrDialog(isNl, result['payment_link']);
    } else {
      if (mounted) {
        final msg = result['message'] ?? '';
        if (msg.contains('No Stripe account') || msg.contains('not fully set up')) {
          _showStripeNotConnectedDialog(isNl);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg),
            backgroundColor: BigDoggTheme.error,
          ));
        }
      }
    }
  }

  void _showStripeNotConnectedDialog(bool isNl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isNl ? 'Stripe niet gekoppeld' : 'Stripe not connected'),
        content: Text(isNl
            ? 'Koppel eerst je Stripe account via Instellingen om betalingslinks te genereren.'
            : 'Connect your Stripe account first via Settings to generate payment links.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isNl ? 'Sluiten' : 'Close'),
          ),
        ],
      ),
    );
  }

  void _showQrDialog(bool isNl, String paymentUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isNl ? 'Betaallink & QR Code' : 'Payment Link & QR Code',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: BigDoggTheme.teal800),
              ),
              const SizedBox(height: 8),
              Text(
                isNl
                    ? 'Laat de klant de QR code scannen voor directe betaling.'
                    : 'Let the client scan the QR code for instant payment.',
                style: const TextStyle(
                    fontSize: 13, color: BigDoggTheme.lightTextSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BigDoggTheme.lightBorder),
                ),
                child: QrImageView(
                  data: paymentUrl,
                  version: QrVersions.auto,
                  size: 200,
                ),
              ),
              const SizedBox(height: 16),
              // Copy link
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BigDoggTheme.lightBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BigDoggTheme.lightBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        paymentUrl,
                        style: const TextStyle(
                            fontSize: 11,
                            color: BigDoggTheme.lightTextSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18,
                          color: BigDoggTheme.teal700),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: paymentUrl));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(isNl
                              ? 'Link gekopieerd'
                              : 'Link copied'),
                          backgroundColor: BigDoggTheme.success,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(isNl ? 'Sluiten' : 'Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendEmail(bool isNl) async {
    final client = _invoice!['clients'];
    final clientEmail =
        client?['email'] ?? _invoice!['client_email'] ?? '';
    if (clientEmail.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isNl
              ? 'Geen e-mailadres beschikbaar'
              : 'No email address available'),
          backgroundColor: BigDoggTheme.error,
        ));
      }
      return;
    }

    final paymentLink = _invoice!['payment_link'] as String?;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isNl ? 'Factuur versturen' : 'Send Invoice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isNl
                ? 'Verstuur factuur ${_invoice!['invoice_number']} naar $clientEmail?'
                : 'Send invoice ${_invoice!['invoice_number']} to $clientEmail?'),
            if (paymentLink != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BigDoggTheme.successBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link,
                        size: 16, color: BigDoggTheme.success),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isNl
                            ? 'Betaallink wordt toegevoegd aan de e-mail.'
                            : 'Payment link will be included in the email.',
                        style: const TextStyle(
                            fontSize: 12,
                            color: BigDoggTheme.success),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BigDoggTheme.lightBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BigDoggTheme.lightBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16,
                        color: BigDoggTheme.lightTextSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isNl
                            ? 'Geen betaallink. Genereer er eerst een voor directe betaling.'
                            : 'No payment link. Generate one first for instant payment.',
                        style: const TextStyle(
                            fontSize: 12,
                            color: BigDoggTheme.lightTextSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isNl ? 'Annuleren' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isNl ? 'Versturen' : 'Send'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final result = await EmailService.sendInvoice(widget.invoiceId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['success']
              ? (isNl ? 'Factuur verstuurd!' : 'Invoice sent!')
              : result['message'] ?? 'Error'),
          backgroundColor: result['success']
              ? BigDoggTheme.success
              : BigDoggTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
        if (result['success']) _loadInvoice();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNl = context.watch<AppProvider>().language == 'nl';

    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (_invoice == null) {
      return Scaffold(
          body: Center(
              child: Text(isNl
                  ? 'Factuur niet gevonden'
                  : 'Invoice not found')));
    }

    final status = _invoice!['status'] ?? 'draft';
    final client = _invoice!['clients'];
    final clientName = client?['contact_name'] ??
        _invoice!['client_name'] ??
        (isNl ? 'Verwijderde klant' : 'Deleted client');
    final clientCompany =
        client?['company_name'] ?? _invoice!['client_company'] ?? '';
    final clientEmail =
        client?['email'] ?? _invoice!['client_email'] ?? '';
    final paymentLink = _invoice!['payment_link'] as String?;
    final isPaid = status == 'paid';

    return Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      appBar: AppBar(
        backgroundColor: BigDoggTheme.teal800,
        title: Text(_invoice!['invoice_number'],
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor(status).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusLabel(status, isNl),
              style: TextStyle(
                  color: _statusColor(status),
                  fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined,
                color: Colors.white),
            onPressed: () => _downloadPdf(isNl),
            tooltip: 'PDF',
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
                  style: const TextStyle(
                      fontSize: 12,
                      color: BigDoggTheme.lightTextSecondary)),
              const SizedBox(height: 4),
              Text(clientName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: BigDoggTheme.teal800)),
              if (clientCompany.isNotEmpty)
                Text(clientCompany,
                    style: const TextStyle(
                        color: BigDoggTheme.lightTextSecondary)),
              if (clientEmail.isNotEmpty)
                Text(clientEmail,
                    style: const TextStyle(
                        color: BigDoggTheme.lightTextHint,
                        fontSize: 12)),
            ]),
            const SizedBox(height: 12),
            _card([
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            isNl ? 'Factuurdatum' : 'Invoice date',
                            style: const TextStyle(
                                fontSize: 12,
                                color:
                                    BigDoggTheme.lightTextSecondary)),
                        Text(_invoice!['invoice_date'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isNl ? 'Vervaldatum' : 'Due date',
                            style: const TextStyle(
                                fontSize: 12,
                                color:
                                    BigDoggTheme.lightTextSecondary)),
                        Text(_invoice!['due_date'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 12),
            _card([
              Text(isNl ? 'Regels' : 'Lines',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: BigDoggTheme.teal800)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      flex: 3,
                      child: Text(
                          isNl ? 'Omschrijving' : 'Description',
                          style: const TextStyle(
                              fontSize: 12,
                              color:
                                  BigDoggTheme.lightTextSecondary))),
                  Expanded(
                      child: Text(isNl ? 'Aantal' : 'Qty',
                          style: const TextStyle(
                              fontSize: 12,
                              color:
                                  BigDoggTheme.lightTextSecondary),
                          textAlign: TextAlign.right)),
                  Expanded(
                      child: Text(isNl ? 'Prijs' : 'Price',
                          style: const TextStyle(
                              fontSize: 12,
                              color:
                                  BigDoggTheme.lightTextSecondary),
                          textAlign: TextAlign.right)),
                  Expanded(
                      child: Text(isNl ? 'Totaal' : 'Total',
                          style: const TextStyle(
                              fontSize: 12,
                              color:
                                  BigDoggTheme.lightTextSecondary),
                          textAlign: TextAlign.right)),
                ],
              ),
              const Divider(),
              ..._lines.map((line) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(line['description'],
                                    style: const TextStyle(
                                        fontWeight:
                                            FontWeight.w500)),
                                Text('${line['btw_rate']}% BTW',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: BigDoggTheme
                                            .lightTextHint)),
                              ],
                            )),
                        Expanded(
                            child: Text('${line['quantity']}x',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    color: BigDoggTheme
                                        .lightTextSecondary))),
                        Expanded(
                            child: Text(
                                '€${line['unit_price_ex_btw']}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    color: BigDoggTheme
                                        .lightTextSecondary))),
                        Expanded(
                            child: Text(
                                '€${line['line_total_ex_btw']}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight:
                                        FontWeight.w600))),
                      ],
                    ),
                  )),
              const Divider(),
              _totalRow(
                  isNl ? 'Subtotaal ex BTW' : 'Subtotal ex BTW',
                  '€${_invoice!['subtotal_ex_btw']}'),
              _totalRow('BTW', '€${_invoice!['btw_amount']}'),
              const SizedBox(height: 4),
              _totalRow(
                  isNl ? 'Totaal incl BTW' : 'Total incl BTW',
                  '€${_invoice!['total_incl_btw']}',
                  bold: true,
                  large: true),
            ]),
            const SizedBox(height: 12),

            // Payment link card — show if exists or not paid
            if (!isPaid) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BigDoggTheme.lightSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: paymentLink != null
                        ? BigDoggTheme.success.withOpacity(0.4)
                        : BigDoggTheme.lightBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          paymentLink != null
                              ? Icons.qr_code
                              : Icons.qr_code_outlined,
                          color: paymentLink != null
                              ? BigDoggTheme.success
                              : BigDoggTheme.teal800,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isNl ? 'Betaallink & QR Code' : 'Payment Link & QR Code',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: BigDoggTheme.teal800),
                        ),
                        if (paymentLink != null) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: BigDoggTheme.successBg,
                              borderRadius:
                                  BorderRadius.circular(6),
                            ),
                            child: Text(
                              isNl ? 'Actief' : 'Active',
                              style: const TextStyle(
                                  color: BigDoggTheme.success,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      paymentLink != null
                          ? (isNl
                              ? 'Betaallink is gegenereerd. Toon QR code voor directe betaling ter plekke, of stuur de factuur per e-mail.'
                              : 'Payment link generated. Show QR code for instant on-site payment, or send invoice by email.')
                          : (isNl
                              ? 'Genereer een betaallink zodat de klant direct kan betalen via iDEAL of creditcard.'
                              : 'Generate a payment link so the client can pay instantly via iDEAL or credit card.'),
                      style: const TextStyle(
                          fontSize: 12,
                          color: BigDoggTheme.lightTextSecondary),
                    ),
                    const SizedBox(height: 12),
                    if (paymentLink != null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _showQrDialog(isNl, paymentLink),
                          icon: const Icon(Icons.qr_code,
                              color: Colors.white),
                          label: Text(
                              isNl
                                  ? 'Toon QR Code'
                                  : 'Show QR Code',
                              style: const TextStyle(
                                  color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BigDoggTheme.success,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(10)),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _generatingLink
                              ? null
                              : () => _generatePaymentLink(isNl),
                          icon: _generatingLink
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Icon(Icons.qr_code_outlined,
                                  color: Colors.white),
                          label: Text(
                              _generatingLink
                                  ? (isNl
                                      ? 'Genereren...'
                                      : 'Generating...')
                                  : (isNl
                                      ? 'Genereer betaallink & QR'
                                      : 'Generate payment link & QR'),
                              style: const TextStyle(
                                  color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BigDoggTheme.teal800,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            _actionButton(
              isNl ? 'Download PDF' : 'Download PDF',
              BigDoggTheme.teal700,
              Icons.picture_as_pdf_outlined,
              () => _downloadPdf(isNl),
            ),
            const SizedBox(height: 8),
            _actionButton(
              isNl ? 'Verstuur per e-mail' : 'Send by email',
              BigDoggTheme.teal600,
              Icons.email_outlined,
              () => _sendEmail(isNl),
            ),
            const SizedBox(height: 8),
            if (status != 'paid') ...[
              if (status == 'draft')
                _actionButton(
                  isNl ? 'Markeer als verstuurd' : 'Mark as Sent',
                  BigDoggTheme.info,
                  Icons.send,
                  () async {
                    await InvoicesService.updateStatus(
                        widget.invoiceId, 'sent');
                    _loadInvoice();
                  },
                ),
              if (status == 'sent' || status == 'overdue') ...[
                _actionButton(
                  isNl ? 'Markeer als betaald' : 'Mark as Paid',
                  BigDoggTheme.success,
                  Icons.check_circle_outline,
                  () async {
                    await InvoicesService.updateStatus(
                        widget.invoiceId, 'paid');
                    _loadInvoice();
                  },
                ),
                const SizedBox(height: 8),
                _actionButton(
                  isNl ? 'Stuur herinnering' : 'Send Reminder',
                  BigDoggTheme.warning,
                  Icons.notifications_outlined,
                  () async {
                    await InvoicesService.sendReminder(
                        widget.invoiceId);
                    if (mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(
                        content: Text(isNl
                            ? 'Herinnering verstuurd'
                            : 'Reminder sent'),
                        backgroundColor: BigDoggTheme.success,
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  },
                ),
              ],
              if (status == 'sent')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _actionButton(
                    isNl
                        ? 'Markeer als verlopen'
                        : 'Mark as Overdue',
                    BigDoggTheme.error,
                    Icons.warning_amber_outlined,
                    () async {
                      await InvoicesService.updateStatus(
                          widget.invoiceId, 'overdue');
                      _loadInvoice();
                    },
                  ),
                ),
              if (status == 'draft')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _actionButton(
                    isNl
                        ? 'Concept verwijderen'
                        : 'Delete Draft',
                    BigDoggTheme.lightTextSecondary,
                    Icons.delete_outline,
                    () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(isNl
                              ? 'Factuur verwijderen'
                              : 'Delete Invoice'),
                          content: Text(isNl
                              ? 'Weet je zeker dat je dit concept wilt verwijderen?'
                              : 'Are you sure you want to delete this draft?'),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, false),
                              child: Text(isNl
                                  ? 'Annuleren'
                                  : 'Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () =>
                                  Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      BigDoggTheme.error),
                              child: Text(isNl
                                  ? 'Verwijderen'
                                  : 'Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await InvoicesService.deleteInvoice(
                            widget.invoiceId);
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
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children),
    );
  }

  Widget _totalRow(String label, String value,
      {bool bold = false, bool large = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                color: bold
                    ? BigDoggTheme.lightTextPrimary
                    : BigDoggTheme.lightTextSecondary,
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal,
                fontSize: large ? 16 : 14,
              )),
          Text(value,
              style: TextStyle(
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal,
                fontSize: large ? 16 : 14,
                color: bold
                    ? BigDoggTheme.teal800
                    : BigDoggTheme.lightTextPrimary,
              )),
        ],
      ),
    );
  }

  Widget _actionButton(
      String label, Color color, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
        label: Text(label,
            style:
                const TextStyle(color: Colors.white, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}