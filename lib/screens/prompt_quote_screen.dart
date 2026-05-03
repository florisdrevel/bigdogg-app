import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ai_service.dart';
import '../services/quotes_service.dart';
import '../providers/app_provider.dart';
import '../theme.dart';

/// AI-powered prompt-to-quote screen. Mirrors PromptInvoiceScreen but
/// builds a quote (offerte) instead of an invoice. No voice input — the
/// project explicitly forbids speech-to-text.
class PromptQuoteScreen extends StatefulWidget {
  const PromptQuoteScreen({super.key});

  @override
  State<PromptQuoteScreen> createState() => _PromptQuoteScreenState();
}

class _PromptQuoteScreenState extends State<PromptQuoteScreen> {
  final _promptController = TextEditingController();
  Map<String, dynamic>? _parsed;
  bool _loading = false;
  bool _creating = false;
  String? _error;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _parse(bool isNl) async {
    if (_promptController.text.isEmpty) return;
    // Drop the on-screen keyboard so the parsed-result card is visible.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _parsed = null;
    });
    final result = await AiService.parseQuotePrompt(_promptController.text);
    setState(() {
      _loading = false;
      if (result['success']) {
        _parsed = result['parsed'];
      } else {
        _error = result['message'];
      }
    });
  }

  Future<void> _createQuote(bool isNl) async {
    if (_parsed == null) return;
    setState(() => _creating = true);

    final lines = (_parsed!['lines'] as List).map((l) => {
          'description': l['description'],
          'quantity': l['quantity'],
          'unit_price_ex_btw': l['unit_price_ex_btw'],
          'btw_rate': l['btw_rate'],
          'unit': l['unit'] ?? 'fixed',
        }).toList();

    final result = await QuotesService.createQuote(
      clientId: _parsed!['client_id'],
      lines: lines.cast<Map<String, dynamic>>(),
      notes: _parsed!['notes']?.toString(),
    );

    setState(() => _creating = false);

    if (result['success'] && mounted) {
      final quoteId = result['quote']['id'];
      Navigator.pop(context, quoteId);
    } else {
      setState(() => _error = result['message'] ??
          (isNl ? 'Aanmaken mislukt' : 'Failed to create'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNl = context.watch<AppProvider>().language == 'nl';

    return Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      appBar: AppBar(
        backgroundColor: BigDoggTheme.teal800,
        title: Text(isNl ? 'AI Offerte' : 'AI Quote',
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BigDoggTheme.lightSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BigDoggTheme.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isNl ? 'Omschrijf je offerte' : 'Describe your quote',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: BigDoggTheme.teal800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isNl
                        ? 'bijv. "Offerte voor ToraTora: 5 dagen ontwerpwerk en 2 dagen revisie"'
                        : 'e.g. "Quote for ToraTora: 5 days of design plus 2 days of revisions"',
                    style: const TextStyle(
                        fontSize: 13,
                        color: BigDoggTheme.lightTextSecondary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _promptController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: isNl
                          ? 'Typ je omschrijving...'
                          : 'Type your description...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _parse(isNl),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : () => _parse(isNl),
                      icon: const Icon(Icons.smart_toy),
                      label: Text(isNl ? 'Genereer' : 'Generate'),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BigDoggTheme.errorBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!,
                    style: const TextStyle(color: BigDoggTheme.error)),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_parsed != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BigDoggTheme.lightSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BigDoggTheme.lightBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: BigDoggTheme.success),
                        const SizedBox(width: 8),
                        Text(
                          isNl
                              ? 'AI heeft je offerte verwerkt'
                              : 'AI parsed your quote',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: BigDoggTheme.teal800),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: BigDoggTheme.teal100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _parsed!['confidence']?.toString() ?? 'medium',
                            style: const TextStyle(
                                fontSize: 11,
                                color: BigDoggTheme.teal800,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${isNl ? 'Klant' : 'Client'}: ${_parsed!['client_name'] ?? '-'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(isNl ? 'Regels:' : 'Lines:',
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    ...(_parsed!['lines'] as List).map((line) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(line['description'],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500)),
                                    Text(
                                      '${line['quantity']}x €${line['unit_price_ex_btw']} (${line['btw_rate']}% BTW)',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: BigDoggTheme
                                              .lightTextSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '€${((line['quantity'] as num) * (line['unit_price_ex_btw'] as num)).toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )),
                    if (_parsed!['notes'] != null &&
                        _parsed!['notes'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${isNl ? 'Opmerking' : 'Note'}: ${_parsed!['notes']}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: BigDoggTheme.lightTextSecondary,
                            fontStyle: FontStyle.italic),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed:
                            _creating ? null : () => _createQuote(isNl),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: BigDoggTheme.success),
                        child: _creating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(
                                isNl
                                    ? 'Offerte aanmaken'
                                    : 'Create Quote',
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
