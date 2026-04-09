import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../services/invoices_service.dart';

class PromptInvoiceScreen extends StatefulWidget {
  const PromptInvoiceScreen({super.key});

  @override
  State<PromptInvoiceScreen> createState() => _PromptInvoiceScreenState();
}

class _PromptInvoiceScreenState extends State<PromptInvoiceScreen> {
  final _promptController = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _parsed;
  String? _error;

  Future<void> _parsePrompt() async {
    if (_promptController.text.trim().isEmpty) return;
    setState(() { _loading = true; _error = null; _parsed = null; });

    final result = await AiService.parseInvoicePrompt(_promptController.text.trim());

    setState(() { _loading = false; });

    if (result['success']) {
      setState(() => _parsed = result['parsed']);
    } else {
      setState(() => _error = result['message']);
    }
  }

  Future<void> _createInvoice() async {
    if (_parsed == null) return;
    setState(() => _loading = true);

    final lines = (_parsed!['lines'] as List).map((l) => {
      'description': l['description'],
      'quantity': l['quantity'],
      'unit_price_ex_btw': l['unit_price_ex_btw'],
      'btw_rate': l['btw_rate'],
    }).toList();

    final result = await InvoicesService.createInvoice(
      clientId: _parsed!['client_id'],
      lines: List<Map<String, dynamic>>.from(lines),
    );

    setState(() => _loading = false);

    if (result['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice created successfully'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('AI Invoice', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
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
                    const Text(
                      'Describe your invoice',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'e.g. "10 dayfees for ToraTora plus travel"',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _promptController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Type your invoice description...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF1A1A2E), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _parsePrompt,
                        icon: const Icon(Icons.auto_awesome, color: Colors.white),
                        label: const Text('Parse with AI', style: TextStyle(color: Colors.white, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A1A2E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626))),
                ),
              ),

            if (_parsed != null) ...[
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF059669)),
                          const SizedBox(width: 8),
                          const Text('AI parsed your invoice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _parsed!['confidence'] ?? 'medium',
                              style: const TextStyle(color: Color(0xFF059669), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Client: ${_parsed!['client_name']}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 12),
                      const Text('Lines:', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...(_parsed!['lines'] as List).map((line) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(line['description'], style: const TextStyle(fontWeight: FontWeight.w500)),
                                  Text('${line['quantity']}x € ${line['unit_price_ex_btw']} (${line['btw_rate']}% BTW)',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                ],
                              ),
                            ),
                            Text(
                              '€${(line['quantity'] * line['unit_price_ex_btw']).toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )),
                      if (_parsed!['notes'] != null && _parsed!['notes'].toString().isNotEmpty) ...[
                        const Divider(),
                        Text('Note: ${_parsed!['notes']}',
                            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _createInvoice,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Create Invoice', style: TextStyle(color: Colors.white, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}