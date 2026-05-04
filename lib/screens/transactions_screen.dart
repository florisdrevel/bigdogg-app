import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/banking_service.dart';
import '../theme.dart';

/// Lists transactions pulled from the user's connected bank (via Tink).
/// Read-only for now: groups by date, colours incoming green and outgoing
/// red, pull-to-refresh. Future iterations can add "match to invoice"
/// and "create expense from this transaction" actions.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _transactions = const [];

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
    final result = await BankingService.getTransactions(pageSize: 200);
    if (!mounted) return;
    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>?;
      final list = (data?['transactions'] as List?) ?? const [];
      setState(() {
        _transactions = list.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } else {
      setState(() {
        _error = result['message']?.toString() ?? 'transactions_error';
        _loading = false;
      });
    }
  }

  String _formatAmount(num value, String currency) {
    final fixed = value.abs().toStringAsFixed(2).replaceAll('.', ',');
    final symbol = currency == 'EUR' ? '€' : currency;
    final sign = value >= 0 ? '+' : '−';
    return '$sign $symbol $fixed';
  }

  String _formatDateHeading(String? raw, bool isNl) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      final d = DateTime.parse(raw);
      final months = isNl
          ? const [
              'januari', 'februari', 'maart', 'april', 'mei', 'juni',
              'juli', 'augustus', 'september', 'oktober', 'november', 'december'
            ]
          : const [
              'January', 'February', 'March', 'April', 'May', 'June',
              'July', 'August', 'September', 'October', 'November', 'December'
            ];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNl = context.watch<AppProvider>().language == 'nl';

    return Scaffold(
      appBar: AppBar(
        title: Text(isNl ? 'Transacties' : 'Transactions'),
        backgroundColor: BigDoggTheme.lightSurface,
        foregroundColor: BigDoggTheme.teal800,
        elevation: 0,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _error != null
                    ? _buildError(isNl)
                    : _transactions.isEmpty
                        ? _buildEmpty(isNl)
                        : _buildList(isNl),
              ),
      ),
    );
  }

  Widget _buildError(bool isNl) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline,
            size: 56, color: BigDoggTheme.error),
        const SizedBox(height: 12),
        Text(
          isNl
              ? 'Kon transacties niet ophalen'
              : 'Could not fetch transactions',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: BigDoggTheme.error),
        ),
        const SizedBox(height: 6),
        Text(
          _error ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 12, color: BigDoggTheme.lightTextSecondary),
        ),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: Text(isNl ? 'Opnieuw proberen' : 'Try again'),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(bool isNl) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.receipt_long_outlined,
            size: 64, color: BigDoggTheme.lightTextHint),
        const SizedBox(height: 12),
        Text(
          isNl
              ? 'Nog geen transacties gevonden'
              : 'No transactions yet',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: BigDoggTheme.lightTextSecondary),
        ),
        const SizedBox(height: 6),
        Text(
          isNl
              ? 'Sleep naar beneden om te vernieuwen.'
              : 'Pull down to refresh.',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 12, color: BigDoggTheme.lightTextHint),
        ),
      ],
    );
  }

  Widget _buildList(bool isNl) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final tx in _transactions) {
      final d = (tx['date'] ?? '') as String;
      grouped.putIfAbsent(d, () => []).add(tx);
    }
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: dates.length,
      itemBuilder: (_, i) {
        final date = dates[i];
        final items = grouped[date]!;
        final dayTotal = items.fold<double>(
            0, (sum, t) => sum + ((t['amount'] as num?)?.toDouble() ?? 0));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDateHeading(date, isNl),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: BigDoggTheme.teal800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    _formatAmount(dayTotal, 'EUR'),
                    style: TextStyle(
                      fontSize: 12,
                      color: dayTotal >= 0
                          ? BigDoggTheme.success
                          : BigDoggTheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            ...items.map((tx) {
              final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
              final currency = (tx['currency'] as String?) ?? 'EUR';
              final desc = (tx['description'] as String?) ?? '';
              final merchant = (tx['merchant'] as String?) ?? '';
              return Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: BigDoggTheme.lightSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: BigDoggTheme.lightBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      amount >= 0 ? Icons.south_west : Icons.north_east,
                      size: 16,
                      color: amount >= 0
                          ? BigDoggTheme.success
                          : BigDoggTheme.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            merchant.isNotEmpty ? merchant : desc,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: BigDoggTheme.lightTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (merchant.isNotEmpty && desc.isNotEmpty && desc != merchant)
                            Text(
                              desc,
                              style: const TextStyle(
                                fontSize: 11,
                                color: BigDoggTheme.lightTextHint,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatAmount(amount, currency),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: amount >= 0
                            ? BigDoggTheme.success
                            : BigDoggTheme.error,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
