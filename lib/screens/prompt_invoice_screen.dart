import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../services/ai_service.dart';
import '../services/invoices_service.dart';
import '../providers/app_provider.dart';
import '../theme.dart';

class PromptInvoiceScreen extends StatefulWidget {
  const PromptInvoiceScreen({super.key});

  @override
  State<PromptInvoiceScreen> createState() => _PromptInvoiceScreenState();
}

class _PromptInvoiceScreenState extends State<PromptInvoiceScreen> {
  final _promptController = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  Map<String, dynamic>? _parsed;
  bool _loading = false;
  bool _creating = false;
  bool _listening = false;
  bool _speechAvailable = false;
  String? _error;
  String _lastWords = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onError: (error) => setState(() => _listening = false),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _listening = false);
        }
      },
    );
    setState(() => _speechAvailable = available);
  }

  Future<void> _toggleListening(bool isNl) async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }

    if (!_speechAvailable) {
      setState(() => _error = isNl
          ? 'Spraakherkenning niet beschikbaar in deze browser'
          : 'Speech recognition not available in this browser');
      return;
    }

    setState(() {
      _listening = true;
      _error = null;
      _lastWords = _promptController.text;
    });

    await _speech.listen(
      onResult: (result) {
        // Only update on final result to prevent duplication
        if (result.finalResult) {
          setState(() {
            _promptController.text = result.recognizedWords;
            _lastWords = result.recognizedWords;
            _listening = false;
          });
        }
      },
      localeId: isNl ? 'nl_NL' : 'en_US',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      listenMode: ListenMode.confirmation,
    );
  }

  Future<void> _parse(bool isNl) async {
    if (_promptController.text.isEmpty) return;
    setState(() { _loading = true; _error = null; _parsed = null; });
    final result = await AiService.parseInvoicePrompt(_promptController.text);
    setState(() {
      _loading = false;
      if (result['success']) {
        _parsed = result['parsed'];
      } else {
        _error = result['message'];
      }
    });
  }

  Future<void> _createInvoice(bool isNl) async {
    if (_parsed == null) return;
    setState(() => _creating = true);

    final lines = (_parsed!['lines'] as List).map((l) => {
      'description': l['description'],
      'quantity': l['quantity'],
      'unit_price_ex_btw': l['unit_price_ex_btw'],
      'btw_rate': l['btw_rate'],
    }).toList();

    final result = await InvoicesService.createInvoice(
      clientId: _parsed!['client_id'],
      lines: lines,
    );

    setState(() => _creating = false);

    if (result['success'] && mounted) {
      Navigator.pop(context, true);
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
        title: Text(isNl ? 'AI Factuur' : 'AI Invoice',
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
                    isNl ? 'Omschrijf je factuur' : 'Describe your invoice',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: BigDoggTheme.teal800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isNl
                        ? 'bijv. "5 dagen gewerkt voor ToraTora en een reiskostenvergoeding"'
                        : 'e.g. "5 days work for ToraTora plus travel expenses"',
                    style: const TextStyle(
                        fontSize: 13,
                        color: BigDoggTheme.lightTextSecondary),
                  ),
                  const SizedBox(height: 12),
                  Stack(
                    children: [
                      TextField(
                        controller: _promptController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: _listening
                              ? (isNl ? 'Luisteren...' : 'Listening...')
                              : (isNl
                                  ? 'Typ of spreek je omschrijving...'
                                  : 'Type or speak your description...'),
                          contentPadding:
                              const EdgeInsets.fromLTRB(12, 12, 48, 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: _listening
                                  ? BigDoggTheme.error
                                  : BigDoggTheme.lightBorder,
                              width: _listening ? 2 : 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: _listening
                                  ? BigDoggTheme.error
                                  : BigDoggTheme.lightBorder,
                              width: _listening ? 2 : 1,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: IconButton(
                          icon: Icon(
                            _listening ? Icons.mic : Icons.mic_none,
                            color: _listening
                                ? BigDoggTheme.error
                                : BigDoggTheme.teal800,
                          ),
                          onPressed: () => _toggleListening(isNl),
                          tooltip: isNl
                              ? 'Spreek je factuur in'
                              : 'Speak your invoice',
                        ),
                      ),
                    ],
                  ),
                  if (_listening) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: BigDoggTheme.error),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isNl
                              ? 'Aan het luisteren... tik opnieuw om te stoppen'
                              : 'Listening... tap again to stop',
                          style: const TextStyle(
                              fontSize: 12, color: BigDoggTheme.error),
                        ),
                      ],
                    ),
                  ],
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
                              ? 'AI heeft je factuur verwerkt'
                              : 'AI parsed your invoice',
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
                            _parsed!['confidence'] ?? 'medium',
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
                            _creating ? null : () => _createInvoice(isNl),
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
                                    ? 'Factuur aanmaken'
                                    : 'Create Invoice',
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