import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/quotes_service.dart';
import '../services/email_service.dart';
import '../services/api_config.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import 'invoice_detail_screen.dart';

class QuoteDetailScreen extends StatefulWidget {
  final String quoteId;
  const QuoteDetailScreen({super.key, required this.quoteId});

  @override
  State<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends State<QuoteDetailScreen> {
  Map<String, dynamic>? _quote;
  List<dynamic> _lines = [];
  bool _loading = true;
  bool _busy = false;
  bool _sendingEmail = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await QuotesService.getQuote(widget.quoteId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success']) {
        _quote = result['quote'];
        _lines = result['lines'] ?? [];
      }
    });
  }

  Future<void> _changeStatus(String newStatus, bool isNl) async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await QuotesService.updateStatus(widget.quoteId, newStatus);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r['success']) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isNl ? 'Status wijzigen mislukt' : 'Status update failed'),
      ));
    }
  }

  Future<void> _downloadPdf(bool isNl) async {
    final token = await QuotesService.getToken();
    if (token == null) return;
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/api/v1/quotes/${widget.quoteId}/pdf?token=$token',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isNl ? 'Kon PDF niet openen' : 'Could not open PDF'),
      ));
    }
  }

  Future<void> _sendEmail(bool isNl) async {
    if (_quote == null) return;
    final client = _quote!['clients'];
    final clientEmail = client?['email'] ?? _quote!['client_email'] ?? '';
    if (clientEmail.toString().isEmpty) {
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

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isNl ? 'Offerte versturen' : 'Send Quote'),
        content: Text(isNl
            ? 'Verstuur offerte ${_quote!['quote_number']} naar $clientEmail?'
            : 'Send quote ${_quote!['quote_number']} to $clientEmail?'),
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
    if (confirm != true || !mounted) return;

    setState(() => _sendingEmail = true);
    final result = await EmailService.sendQuote(widget.quoteId);
    if (!mounted) return;
    setState(() => _sendingEmail = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['success']
          ? (isNl ? 'Offerte verstuurd!' : 'Quote sent!')
          : (result['message']?.toString() ?? 'Error')),
      backgroundColor:
          result['success'] ? BigDoggTheme.success : BigDoggTheme.error,
      behavior: SnackBarBehavior.floating,
    ));
    if (result['success']) _load();
  }

  Future<void> _convert(bool isNl) async {
    if (_busy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isNl ? 'Omzetten naar factuur?' : 'Convert to invoice?'),
        content: Text(isNl
            ? 'De offerte wordt gekopieerd naar een nieuwe concept-factuur. De offerte zelf blijft bewaard.'
            : 'This quote will be copied to a new draft invoice. The quote itself stays in place.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isNl ? 'Annuleren' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isNl ? 'Omzetten' : 'Convert'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    final r = await QuotesService.convertToInvoice(widget.quoteId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r['success']) {
      final invoiceId = r['invoice_id'] as String?;
      if (invoiceId != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => InvoiceDetailScreen(invoiceId: invoiceId),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r['message']?.toString() ??
            (isNl ? 'Omzetten mislukt' : 'Conversion failed')),
      ));
    }
  }

  Future<void> _delete(bool isNl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isNl ? 'Offerte verwijderen?' : 'Delete quote?'),
        content: Text(isNl
            ? 'Dit kan niet ongedaan worden gemaakt.'
            : 'This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isNl ? 'Annuleren' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: BigDoggTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isNl ? 'Verwijderen' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final r = await QuotesService.deleteQuote(widget.quoteId);
    if (!mounted) return;
    if (r['success']) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r['message']?.toString() ??
            (isNl ? 'Verwijderen mislukt' : 'Delete failed')),
      ));
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'sent':
        return BigDoggTheme.info;
      case 'accepted':
        return BigDoggTheme.success;
      case 'declined':
        return BigDoggTheme.error;
      case 'converted':
        return const Color(0xFF7C3AED);
      default:
        return BigDoggTheme.lightTextSecondary;
    }
  }

  String _statusLabel(String s, bool isNl) {
    switch (s) {
      case 'sent':
        return isNl ? 'Verstuurd' : 'Sent';
      case 'accepted':
        return isNl ? 'Geaccepteerd' : 'Accepted';
      case 'declined':
        return isNl ? 'Afgewezen' : 'Declined';
      case 'converted':
        return isNl ? 'Omgezet' : 'Converted';
      default:
        return isNl ? 'Concept' : 'Draft';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNl = context.watch<AppProvider>().language == 'nl';
    final q = _quote;

    return Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      appBar: AppBar(
        backgroundColor: BigDoggTheme.teal800,
        title: Text(
          q?['quote_number'] ?? (isNl ? 'Offerte' : 'Quote'),
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined,
                color: Colors.white),
            onPressed: () => _downloadPdf(isNl),
            tooltip: 'PDF',
          ),
          if (q != null && q['status'] != 'converted')
            IconButton(
              tooltip: isNl ? 'Verwijderen' : 'Delete',
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: () => _delete(isNl),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : q == null
              ? Center(
                  child: Text(isNl ? 'Niet gevonden' : 'Not found',
                      style: const TextStyle(
                          color: BigDoggTheme.lightTextSecondary)),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _statusBadge(q['status'] ?? 'draft', isNl),
                      const SizedBox(height: 16),
                      _infoCard(q, isNl),
                      const SizedBox(height: 16),
                      _linesCard(isNl),
                      const SizedBox(height: 16),
                      _totalsCard(q, isNl),
                      const SizedBox(height: 24),
                      _actionsBlock(q, isNl),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _statusBadge(String status, bool isNl) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        _statusLabel(status, isNl),
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _infoCard(Map<String, dynamic> q, bool isNl) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv(isNl ? 'Klant' : 'Client',
              (q['clients']?['contact_name'] ?? q['client_name'] ?? '-')
                  .toString()),
          if ((q['client_company'] ?? '').toString().isNotEmpty)
            _kv(isNl ? 'Bedrijf' : 'Company', q['client_company']),
          _kv(isNl ? 'Offertedatum' : 'Quote date',
              (q['quote_date'] ?? '-').toString()),
          _kv(isNl ? 'Geldig tot' : 'Valid until',
              (q['valid_until'] ?? '-').toString()),
          if ((q['notes'] ?? '').toString().isNotEmpty)
            _kv(isNl ? 'Notities' : 'Notes', q['notes']),
        ],
      ),
    );
  }

  Widget _linesCard(bool isNl) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isNl ? 'Regels' : 'Lines',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: BigDoggTheme.teal800)),
          const SizedBox(height: 8),
          ..._lines.map((l) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l['description']?.toString() ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500)),
                          Text(
                            '${l['quantity']}x €${l['unit_price_ex_btw']} (${l['btw_rate']}% BTW)',
                            style: const TextStyle(
                                fontSize: 12,
                                color: BigDoggTheme.lightTextSecondary),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '€${(double.tryParse((l['line_total_ex_btw'] ?? 0).toString()) ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _totalsCard(Map<String, dynamic> q, bool isNl) {
    final subtotal = double.tryParse((q['subtotal_ex_btw'] ?? 0).toString()) ?? 0;
    final btw = double.tryParse((q['btw_amount'] ?? 0).toString()) ?? 0;
    final total = double.tryParse((q['total_incl_btw'] ?? 0).toString()) ?? 0;
    return _card(
      child: Column(
        children: [
          _row(isNl ? 'Subtotaal ex BTW' : 'Subtotal ex VAT',
              '€${subtotal.toStringAsFixed(2)}'),
          _row(isNl ? 'BTW' : 'VAT', '€${btw.toStringAsFixed(2)}'),
          const Divider(),
          _row(
            isNl ? 'Totaal incl BTW' : 'Total incl VAT',
            '€${total.toStringAsFixed(2)}',
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _actionsBlock(Map<String, dynamic> q, bool isNl) {
    final status = (q['status'] ?? 'draft').toString();
    final isConverted = status == 'converted';

    return Column(
      children: [
        if (status == 'accepted') ...[
          _bigButton(
            label: isNl ? 'Omzetten naar factuur' : 'Convert to invoice',
            color: BigDoggTheme.gold500,
            icon: Icons.swap_horiz_rounded,
            onTap: _busy ? null : () => _convert(isNl),
          ),
          const SizedBox(height: 8),
        ],
        if (!isConverted)
          _bigButton(
            label: _sendingEmail
                ? (isNl ? 'Versturen...' : 'Sending...')
                : (isNl ? 'Verstuur per e-mail' : 'Send by email'),
            color: BigDoggTheme.teal600,
            icon: Icons.email_outlined,
            onTap: _sendingEmail ? null : () => _sendEmail(isNl),
          ),
        if (!isConverted) const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _downloadPdf(isNl),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(isNl ? 'Download PDF' : 'Download PDF'),
          ),
        ),
        if (!isConverted) ...[
          const SizedBox(height: 16),
          Text(isNl ? 'Status wijzigen' : 'Change status',
              style: const TextStyle(
                  fontSize: 12, color: BigDoggTheme.lightTextSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _statusButton('draft', isNl, status),
              _statusButton('sent', isNl, status),
              _statusButton('accepted', isNl, status),
              _statusButton('declined', isNl, status),
            ],
          ),
        ],
        if (isConverted && q['converted_invoice_id'] != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => InvoiceDetailScreen(
                    invoiceId: q['converted_invoice_id'].toString()),
              ),
            ),
            icon: const Icon(Icons.receipt_long_outlined),
            label: Text(isNl ? 'Open factuur' : 'Open invoice'),
          ),
        ],
      ],
    );
  }

  Widget _statusButton(String value, bool isNl, String current) {
    final selected = value == current;
    return ChoiceChip(
      label: Text(_statusLabel(value, isNl)),
      selected: selected,
      onSelected: (_) {
        if (!selected) _changeStatus(value, isNl);
      },
      selectedColor: _statusColor(value).withOpacity(0.2),
      labelStyle: TextStyle(
        color: selected ? _statusColor(value) : BigDoggTheme.lightTextSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _bigButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: child,
    );
  }

  Widget _kv(String k, dynamic v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(k,
                style: const TextStyle(
                    fontSize: 12, color: BigDoggTheme.lightTextSecondary)),
          ),
          Expanded(
            child: Text(v?.toString() ?? '-',
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final ts = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
      fontSize: bold ? 16 : 14,
      color: bold ? BigDoggTheme.teal800 : BigDoggTheme.lightTextPrimary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: ts)),
          Text(value, style: ts),
        ],
      ),
    );
  }
}
