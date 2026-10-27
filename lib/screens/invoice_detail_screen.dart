import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/pdf_opener.dart';
import '../services/invoices_service.dart';
import '../services/email_service.dart';
import '../services/payments_service.dart';
import '../services/profile_service.dart';
import '../services/api_config.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../widgets/subscription_web_widget.dart';

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
  // Mirror of profile.default_exclude_payment_link — used as the default
  // state of the "Verstuur zonder betaallink" checkbox in the send
  // dialog. Loaded fire-and-forget so opening the screen isn't blocked.
  bool _defaultExcludePaymentLink = false;
  String _defaultInvoiceMessage = '';

  @override
  void initState() {
    super.initState();
    // Paint instantly from the in-memory cache if this invoice was opened
    // earlier this session; the cold fetch only shows a spinner the first
    // time. Fresh data still lands silently via _loadInvoice().
    final cached = InvoicesService.peekInvoice(widget.invoiceId);
    if (cached != null) {
      _invoice = cached['invoice'] as Map<String, dynamic>?;
      _lines = (cached['lines'] as List?) ?? [];
      _loading = false;
    }
    _loadInvoice();
    _loadPaymentLinkPreference();
  }

  Future<void> _loadInvoice() async {
    // Only spin on a cold open (nothing cached). With cache the screen is
    // already rendered; refresh quietly in place.
    if (_invoice == null) setState(() => _loading = true);
    final result = await InvoicesService.getInvoice(widget.invoiceId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success']) {
        _invoice = result['invoice'];
        _lines = result['lines'];
      }
    });
  }

  Future<void> _loadPaymentLinkPreference() async {
    final result = await ProfileService.getProfile();
    if (!mounted) return;
    if (result['success'] == true && result['profile'] is Map) {
      final p = result['profile'] as Map;
      setState(() {
        _defaultExcludePaymentLink =
            p['default_exclude_payment_link'] == true;
        _defaultInvoiceMessage =
            (p['invoice_default_message'] ?? '').toString();
      });
    }
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
    final url =
        '${ApiConfig.baseUrl}/api/v1/pdf/${widget.invoiceId}?token=$token';
    await openPdfInApp(context, url: url, filename: 'bigdogg-factuur.pdf', isNl: isNl);
  }

  // Per-invoice payment-link toggle. Optimistically flips the local
  // state, persists via PATCH, and reverts on failure.
  Future<void> _setPaymentLinkEnabled(bool enabled, bool isNl) async {
    final previous = _invoice?['payment_link_enabled'] != false;
    setState(() => _invoice?['payment_link_enabled'] = enabled);
    final result =
        await InvoicesService.setPaymentLinkEnabled(widget.invoiceId, enabled);
    if (!mounted) return;
    if (result['success'] != true && result['offline'] != true) {
      setState(() => _invoice?['payment_link_enabled'] = previous);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: BigDoggTheme.error,
        content: Text(isNl ? 'Kon betaallink niet bijwerken' : 'Could not update payment link'),
      ));
    }
  }

  // Manual fallback — generate payment link if somehow missing
  Future<void> _generatePaymentLink(bool isNl) async {
    setState(() => _generatingLink = true);
    final result = await PaymentsService.createPaymentLink(widget.invoiceId);
    setState(() => _generatingLink = false);

    if (result['success']) {
      await _loadInvoice();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? 'Error'),
          backgroundColor: BigDoggTheme.error,
        ));
      }
    }
  }

  void _showQrDialog(bool isNl, String paymentUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isNl ? 'QR Code — Directe betaling' : 'QR Code — Instant payment',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: BigDoggTheme.teal800),
              ),
              const SizedBox(height: 8),
              Text(
                isNl
                    ? 'Laat de klant de QR code scannen voor directe betaling via iDEAL of creditcard.'
                    : 'Let the client scan the QR code for instant payment via iDEAL or credit card.',
                style: const TextStyle(
                    fontSize: 13,
                    color: BigDoggTheme.lightTextSecondary),
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
                      icon: const Icon(Icons.copy,
                          size: 18, color: BigDoggTheme.teal700),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: paymentUrl));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              isNl ? 'Link gekopieerd' : 'Link copied'),
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

  /// Optimistic status change — flips the local invoice immediately,
  /// shows a 4-second undo snackbar, fires the API call in the
  /// background. On failure we revert the local state and surface an
  /// error snackbar (6s).
  ///
  /// Per spec: only used for status flips that don't trigger external
  /// communication. Sending the invoice by email goes through the
  /// strict high-risk flow (form stays open on failure).
  Future<void> _optimisticStatusChange({
    required String newStatus,
    required String successLabelNl,
    required String successLabelEn,
    required bool isNl,
  }) async {
    if (await _blockedByReadOnly(isNl)) return;
    final invoice = _invoice;
    if (invoice == null) return;
    final previousStatus = (invoice['status'] ?? '').toString();
    if (previousStatus == newStatus) return;

    // Optimistic flip — UI updates instantly.
    setState(() {
      invoice['status'] = newStatus;
    });

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    var undone = false;
    final snackController = messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      backgroundColor: BigDoggTheme.teal800,
      content: Text(
        isNl ? successLabelNl : successLabelEn,
        style: const TextStyle(color: Colors.white),
      ),
      action: SnackBarAction(
        label: isNl ? 'Ongedaan maken' : 'Undo',
        textColor: BigDoggTheme.gold400,
        onPressed: () {
          undone = true;
          // Revert the local state. We cannot cancel the in-flight
          // HTTP request — if the API already wrote the new status,
          // fire a follow-up PATCH back to the previous value so the
          // server matches the user's intent.
          if (mounted) {
            setState(() {
              invoice['status'] = previousStatus;
            });
          }
          // Best-effort revert on the server.
          // ignore: unawaited_futures
          InvoicesService.updateStatus(widget.invoiceId, previousStatus);
        },
      ),
    ));

    final result =
        await InvoicesService.updateStatus(widget.invoiceId, newStatus);
    if (undone) return; // User clicked Undo before the call returned.
    if (!mounted) return;
    if (result['success'] != true && result['offline'] != true) {
      // Revert and surface an error. (Offline-queue inserts are
      // treated as success — they'll sync when connectivity returns.)
      setState(() {
        invoice['status'] = previousStatus;
      });
      snackController.close();
      messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        backgroundColor: BigDoggTheme.error,
        content: Text(
          isNl ? 'Niet gelukt — probeer opnieuw' : 'Failed — please try again',
          style: const TextStyle(color: Colors.white),
        ),
      ));
    }
  }

  /// Returns true if the user is in read-only mode AND we surfaced the
  /// paywall sheet for them — caller should bail. Returns false if the
  /// action is allowed.
  Future<bool> _blockedByReadOnly(bool isNl) async {
    if (!mounted) return true;
    if (context.read<AppProvider>().isAppReadOnly) {
      await showSubscriptionWebSheet(context, isNl);
      return true;
    }
    return false;
  }

  Future<void> _sendEmail(bool isNl) async {
    if (await _blockedByReadOnly(isNl)) return;
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
    // A link is "available to send" only when one exists AND the invoice's
    // own payment-link toggle is on. If the toggle is off, the send dialog
    // treats it as having no link at all.
    final hasPaymentLink =
        paymentLink != null && _invoice!['payment_link_enabled'] != false;
    // Default the per-send "exclude" checkbox from the global preference.
    bool excludeLink = hasPaymentLink && _defaultExcludePaymentLink;
    final messageController =
        TextEditingController(text: _defaultInvoiceMessage);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isNl ? 'Factuur versturen' : 'Send Invoice'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isNl
                  ? 'Verstuur factuur ${_invoice!['invoice_number']} naar $clientEmail?'
                  : 'Send invoice ${_invoice!['invoice_number']} to $clientEmail?'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (hasPaymentLink && !excludeLink)
                      ? BigDoggTheme.successBg
                      : BigDoggTheme.lightBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (hasPaymentLink && !excludeLink)
                        ? BigDoggTheme.success.withOpacity(0.3)
                        : BigDoggTheme.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      (hasPaymentLink && !excludeLink)
                          ? Icons.link
                          : Icons.link_off,
                      size: 16,
                      color: (hasPaymentLink && !excludeLink)
                          ? BigDoggTheme.success
                          : BigDoggTheme.lightTextSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        !hasPaymentLink
                            ? (isNl
                                ? 'Geen betaallink — Stripe niet gekoppeld.'
                                : 'No payment link — Stripe not connected.')
                            : (excludeLink
                                ? (isNl
                                    ? 'Betaallink wordt NIET meegestuurd.'
                                    : 'Payment link will NOT be sent.')
                                : (isNl
                                    ? 'Betaallink automatisch bijgevoegd.'
                                    : 'Payment link automatically included.')),
                        style: TextStyle(
                            fontSize: 12,
                            color: (hasPaymentLink && !excludeLink)
                                ? BigDoggTheme.success
                                : BigDoggTheme.lightTextSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasPaymentLink) ...[
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => setDialogState(
                      () => excludeLink = !excludeLink),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: excludeLink,
                            onChanged: (v) => setDialogState(
                                () => excludeLink = v ?? false),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isNl
                                ? 'Verstuur zonder betaallink'
                                : 'Send without payment link',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: isNl
                      ? 'Bericht aan klant (optioneel)'
                      : 'Message to client (optional)',
                  hintText: isNl
                      ? 'Persoonlijk bericht bovenaan de e-mail'
                      : 'Personal note at the top of the email',
                  hintMaxLines: 2,
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
              ),
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
      ),
    );

    final customMessage = messageController.text.trim();
    messageController.dispose();

    if (confirm == true && mounted) {
      final result = await EmailService.sendInvoice(
        widget.invoiceId,
        includePaymentLink: !excludeLink,
        message: customMessage,
      );
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
    final paymentLinkEnabled = _invoice!['payment_link_enabled'] != false;
    final isPaid = status == 'paid';

    return Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      appBar: AppBar(
        backgroundColor: BigDoggTheme.teal800,
        title: Text(_invoice!['invoice_number'],
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Status pill only — PDF and QR live in the body to avoid duplicates.
          Container(
            margin: const EdgeInsets.only(right: 12),
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
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, 16 + MediaQuery.of(context).viewPadding.bottom),
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
                              color: BigDoggTheme.lightTextSecondary))),
                  Expanded(
                      child: Text(isNl ? 'Aantal' : 'Qty',
                          style: const TextStyle(
                              fontSize: 12,
                              color: BigDoggTheme.lightTextSecondary),
                          textAlign: TextAlign.right)),
                  Expanded(
                      child: Text(isNl ? 'Prijs' : 'Price',
                          style: const TextStyle(
                              fontSize: 12,
                              color: BigDoggTheme.lightTextSecondary),
                          textAlign: TextAlign.right)),
                  Expanded(
                      child: Text(isNl ? 'Totaal' : 'Total',
                          style: const TextStyle(
                              fontSize: 12,
                              color: BigDoggTheme.lightTextSecondary),
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
                                        fontWeight: FontWeight.w500)),
                                Text('${line['btw_rate']}% BTW',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color:
                                            BigDoggTheme.lightTextHint)),
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
                                    fontWeight: FontWeight.w600))),
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

            // Payment link status card — shown when not paid
            if (!isPaid) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BigDoggTheme.lightSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (paymentLink != null && paymentLinkEnabled)
                        ? BigDoggTheme.success.withOpacity(0.4)
                        : BigDoggTheme.lightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          (paymentLink != null && paymentLinkEnabled)
                              ? Icons.check_circle
                              : Icons.info_outline,
                          color: (paymentLink != null && paymentLinkEnabled)
                              ? BigDoggTheme.success
                              : BigDoggTheme.lightTextSecondary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            paymentLink == null
                                ? (isNl
                                    ? 'Geen betaallink — koppel Stripe via Instellingen.'
                                    : 'No payment link — connect Stripe via Settings.')
                                : (paymentLinkEnabled
                                    ? (isNl
                                        ? 'Betaallink actief — automatisch bijgevoegd aan e-mail.'
                                        : 'Payment link active — automatically included in email.')
                                    : (isNl
                                        ? 'Betaallink uitgeschakeld voor deze factuur.'
                                        : 'Payment link disabled for this invoice.')),
                            style: TextStyle(
                              fontSize: 13,
                              color: (paymentLink != null && paymentLinkEnabled)
                                  ? BigDoggTheme.success
                                  : BigDoggTheme.lightTextSecondary,
                            ),
                          ),
                        ),
                        // Manual fallback generate button if no link
                        if (paymentLink == null)
                          _generatingLink
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : TextButton(
                                  onPressed: () =>
                                      _generatePaymentLink(isNl),
                                  child: Text(
                                      isNl ? 'Genereer' : 'Generate',
                                      style: const TextStyle(
                                          color: BigDoggTheme.teal800,
                                          fontSize: 12)),
                                ),
                        // QR button only when link exists AND it's enabled
                        if (paymentLink != null && paymentLinkEnabled)
                          TextButton.icon(
                            onPressed: () =>
                                _showQrDialog(isNl, paymentLink),
                            icon: const Icon(Icons.qr_code,
                                size: 16, color: BigDoggTheme.teal800),
                            label: Text(
                                isNl ? 'QR Code' : 'QR Code',
                                style: const TextStyle(
                                    color: BigDoggTheme.teal800,
                                    fontSize: 12)),
                          ),
                      ],
                    ),
                    // The on/off toggle — only relevant when a link exists.
                    if (paymentLink != null) ...[
                      const Divider(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isNl ? 'Betaallink meesturen' : 'Send payment link',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: BigDoggTheme.lightTextPrimary),
                            ),
                          ),
                          Switch(
                            value: paymentLinkEnabled,
                            activeColor: BigDoggTheme.teal800,
                            onChanged: (v) =>
                                _setPaymentLinkEnabled(v, isNl),
                          ),
                        ],
                      ),
                    ],
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
                  () => _optimisticStatusChange(
                    newStatus: 'sent',
                    successLabelNl: 'Gemarkeerd als verstuurd',
                    successLabelEn: 'Marked as sent',
                    isNl: isNl,
                  ),
                ),
              if (status == 'sent' || status == 'overdue') ...[
                _actionButton(
                  isNl ? 'Markeer als betaald' : 'Mark as Paid',
                  BigDoggTheme.success,
                  Icons.check_circle_outline,
                  () => _optimisticStatusChange(
                    newStatus: 'paid',
                    successLabelNl: 'Gemarkeerd als betaald',
                    successLabelEn: 'Marked as paid',
                    isNl: isNl,
                  ),
                ),
                const SizedBox(height: 8),
                _actionButton(
                  isNl ? 'Stuur herinnering' : 'Send Reminder',
                  BigDoggTheme.warning,
                  Icons.notifications_outlined,
                  () async {
                    if (await _blockedByReadOnly(isNl)) return;
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
                    () => _optimisticStatusChange(
                      newStatus: 'overdue',
                      successLabelNl: 'Gemarkeerd als verlopen',
                      successLabelEn: 'Marked as overdue',
                      isNl: isNl,
                    ),
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
                      if (await _blockedByReadOnly(isNl)) return;
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
                              child: Text(
                                  isNl ? 'Annuleren' : 'Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () =>
                                  Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      BigDoggTheme.error),
                              child: Text(
                                  isNl ? 'Verwijderen' : 'Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final result = await InvoicesService.deleteInvoice(
                            widget.invoiceId);
                        if (result['offline'] == true && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            backgroundColor: BigDoggTheme.warning,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 4),
                            content: Text(isNl
                                ? 'Geen verbinding — factuur wordt verwijderd zodra je online bent.'
                                : 'Offline — invoice will be deleted once you are back online.'),
                          ));
                          return;
                        }
                        if (mounted) Navigator.pop(context, true);
                      }
                    },
                  ),
                ),
            ],
          ],
          ),
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
            style: const TextStyle(
                color: Colors.white, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}