import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_config.dart';
import '../theme.dart';

/// Public landing page for a shared quote. Reached via the URL the
/// recipient gets in their email (https://bigdogg.nl/#/q/<token>).
/// No login required — auth is the unguessable share_token.
class QuotePublicScreen extends StatefulWidget {
  final String token;
  const QuotePublicScreen({super.key, required this.token});

  @override
  State<QuotePublicScreen> createState() => _QuotePublicScreenState();
}

class _QuotePublicScreenState extends State<QuotePublicScreen> {
  Map<String, dynamic>? _quote;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _decision; // 'accepted' | 'declined' (after the user clicks)

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/quotes/public/${widget.token}'),
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _quote = data;
            _decision = (data['status'] == 'accepted' ||
                    data['status'] == 'converted')
                ? 'accepted'
                : (data['status'] == 'declined' ? 'declined' : null);
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = r.statusCode == 404
                ? 'Deze offerte bestaat niet of is verwijderd.'
                : 'Kon offerte niet laden.';
            _loading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Geen verbinding.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _act(String action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final r = await http.post(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/v1/quotes/public/${widget.token}/$action'),
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _decision = data['status'];
            _busy = false;
          });
        }
      } else {
        final detail = (() {
          try {
            return (jsonDecode(r.body) as Map)['detail']?.toString();
          } catch (_) {
            return null;
          }
        })();
        if (mounted) {
          setState(() {
            _error = detail ?? 'Er ging iets mis. Probeer het opnieuw.';
            _busy = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Geen verbinding.';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: _body(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _quote == null) {
      return _card(
        Column(
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: BigDoggTheme.error),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15)),
          ],
        ),
      );
    }
    final q = _quote!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(q),
        const SizedBox(height: 16),
        _summaryCard(q),
        const SizedBox(height: 16),
        _linesCard(q),
        const SizedBox(height: 16),
        _totalsCard(q),
        const SizedBox(height: 24),
        if (_decision == null) _actionButtons(),
        if (_decision != null) _decisionBanner(),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'Verzonden via BigDogg · bigdogg.nl',
            style: TextStyle(
                fontSize: 11, color: Colors.grey[500]),
          ),
        ),
      ],
    );
  }

  Widget _header(Map<String, dynamic> q) {
    final logo = q['from_logo_url']?.toString();
    final business = q['from_business']?.toString() ?? '';
    return _card(
      Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: BigDoggTheme.lightBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: BigDoggTheme.lightBorder),
            ),
            child: (logo != null && logo.isNotEmpty)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.network(logo, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.business_outlined,
                            color: BigDoggTheme.lightTextHint)),
                  )
                : const Icon(Icons.business_outlined,
                    color: BigDoggTheme.lightTextHint),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('OFFERTE',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                        color: BigDoggTheme.gold500)),
                const SizedBox(height: 2),
                Text(q['quote_number']?.toString() ?? '',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: BigDoggTheme.teal800)),
                const SizedBox(height: 2),
                Text('Van $business',
                    style: const TextStyle(
                        fontSize: 13,
                        color: BigDoggTheme.lightTextSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(Map<String, dynamic> q) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv('Offertedatum', q['quote_date']?.toString() ?? '-'),
          _kv('Geldig tot', q['valid_until']?.toString() ?? '-'),
          _kv('T.a.v.',
              (q['client_name'] ?? q['client_company'] ?? '-').toString()),
          if ((q['notes'] ?? '').toString().isNotEmpty)
            _kv('Opmerking', q['notes'].toString()),
        ],
      ),
    );
  }

  Widget _linesCard(Map<String, dynamic> q) {
    final lines = (q['lines'] as List?) ?? [];
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Regels',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: BigDoggTheme.teal800)),
          const SizedBox(height: 8),
          ...lines.map((l) {
            final lineTotal =
                double.tryParse((l['line_total_ex_btw'] ?? 0).toString()) ?? 0;
            return Padding(
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
                  Text('€${lineTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _totalsCard(Map<String, dynamic> q) {
    final subtotal =
        double.tryParse((q['subtotal_ex_btw'] ?? 0).toString()) ?? 0;
    final btw = double.tryParse((q['btw_amount'] ?? 0).toString()) ?? 0;
    final total = double.tryParse((q['total_incl_btw'] ?? 0).toString()) ?? 0;
    return _card(
      Column(
        children: [
          _row('Subtotaal ex BTW', '€${subtotal.toStringAsFixed(2)}'),
          _row('BTW', '€${btw.toStringAsFixed(2)}'),
          const Divider(),
          _row('Totaal incl BTW', '€${total.toStringAsFixed(2)}', bold: true),
        ],
      ),
    );
  }

  Widget _actionButtons() {
    return Column(
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: BigDoggTheme.errorBg,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(_error!,
                  style: const TextStyle(color: BigDoggTheme.error)),
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : () => _act('accept'),
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded),
            label: const Text('Offerte accepteren',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: BigDoggTheme.success,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _act('decline'),
            icon: const Icon(Icons.close_rounded),
            label: const Text('Afwijzen'),
            style: OutlinedButton.styleFrom(
              foregroundColor: BigDoggTheme.error,
              side: const BorderSide(color: BigDoggTheme.error),
            ),
          ),
        ),
      ],
    );
  }

  Widget _decisionBanner() {
    final accepted = _decision == 'accepted';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accepted
            ? BigDoggTheme.successBg
            : BigDoggTheme.errorBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: (accepted ? BigDoggTheme.success : BigDoggTheme.error)
                .withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(accepted ? Icons.check_circle : Icons.cancel,
              size: 32,
              color: accepted ? BigDoggTheme.success : BigDoggTheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  accepted ? 'Offerte geaccepteerd' : 'Offerte afgewezen',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: accepted
                          ? BigDoggTheme.success
                          : BigDoggTheme.error),
                ),
                const SizedBox(height: 4),
                Text(
                  accepted
                      ? 'Bedankt! De afzender is op de hoogte gebracht.'
                      : 'De afzender is op de hoogte gebracht.',
                  style: const TextStyle(
                      fontSize: 13,
                      color: BigDoggTheme.lightTextSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Widget child) {
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

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(k,
                  style: const TextStyle(
                      fontSize: 12,
                      color: BigDoggTheme.lightTextSecondary)),
            ),
            Expanded(
              child: Text(v,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );

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
