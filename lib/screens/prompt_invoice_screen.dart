import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../services/invoices_service.dart';
import '../app_theme.dart';

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
    setState(() {
      _loading = true;
      _error = null;
      _parsed = null;
    });

    final result = await AiService.parseInvoicePrompt(
      _promptController.text.trim(),
    );

    setState(() {
      _loading = false;
    });

    if (result['success']) {
      setState(() => _parsed = result['parsed']);
    } else {
      setState(() => _error = result['message']);
    }
  }

  Future<void> _createInvoice() async {
    if (_parsed == null) return;
    setState(() => _loading = true);

    final lines = (_parsed!['lines'] as List)
        .map(
          (l) => {
            'description': l['description'],
            'quantity': l['quantity'],
            'unit_price_ex_btw': l['unit_price_ex_btw'],
            'btw_rate': l['btw_rate'],
          },
        )
        .toList();

    final result = await InvoicesService.createInvoice(
      clientId: _parsed!['client_id'],
      lines: List<Map<String, dynamic>>.from(lines),
    );

    setState(() => _loading = false);

    if (result['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice created successfully')),
        );
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(gradient: AppGradients.navySubtle),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'AI Invoice',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prompt card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: AppDecorations.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppGradients.indigoAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Describe your invoice',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Text(
                              'e.g. "10 dayfees for ToraTora + travel"',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _promptController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Type your invoice description...',
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _parsePrompt,
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text(
                        'Parse with AI',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              ErrorBox(_error!),
            ],

            if (_parsed != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: AppDecorations.card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: AppColors.success,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'AI parsed your invoice',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.success.withOpacity(0.25),
                            ),
                          ),
                          child: Text(
                            _parsed!['confidence'] ?? 'medium',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _parsed!['client_name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...(_parsed!['lines'] as List).map(
                      (line) => Container(
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
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${line['quantity']}×  ·  €${line['unit_price_ex_btw']}  ·  ${line['btw_rate']}% BTW',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '€${(line['quantity'] * line['unit_price_ex_btw']).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_parsed!['notes'] != null &&
                        _parsed!['notes'].toString().isNotEmpty) ...[
                      const Divider(),
                      const SizedBox(height: 4),
                      Text(
                        'Note: ${_parsed!['notes']}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _createInvoice,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Create Invoice',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
