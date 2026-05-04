import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/banking_service.dart';
import '../services/invoices_service.dart';
import '../theme.dart';

/// Bank-transactions screen with auto-matching against invoices and
/// expenses. Each row renders a link badge (auto-matched, suggested,
/// private, or unlinked) and a tap opens a bottom sheet with the
/// available actions.
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
    final result = await BankingService.getTransactions(pageSize: 100);
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

  Widget _linkBadge(Map<String, dynamic>? link, bool isNl) {
    if (link == null) return const SizedBox.shrink();
    final type = link['type']?.toString();
    final label = link['linked_label']?.toString() ?? '';
    Color bg;
    Color fg;
    IconData icon;
    String text;
    switch (type) {
      case 'invoice':
        bg = BigDoggTheme.successBg;
        fg = BigDoggTheme.success;
        icon = Icons.check_circle;
        text = isNl ? 'Factuur $label' : 'Invoice $label';
        break;
      case 'expense':
        bg = BigDoggTheme.successBg;
        fg = BigDoggTheme.success;
        icon = Icons.check_circle;
        text = isNl ? 'Kosten · $label' : 'Expense · $label';
        break;
      case 'private':
        bg = BigDoggTheme.lightSurface2;
        fg = BigDoggTheme.lightTextSecondary;
        icon = Icons.lock_outline;
        text = isNl ? 'Privé' : 'Private';
        break;
      case 'suggested_invoice':
        bg = BigDoggTheme.warningBg;
        fg = BigDoggTheme.warning;
        icon = Icons.bolt;
        text = isNl ? 'Match? $label' : 'Match? $label';
        break;
      case 'suggested_expense':
        bg = BigDoggTheme.warningBg;
        fg = BigDoggTheme.warning;
        icon = Icons.bolt;
        text = isNl ? 'Match? $label' : 'Match? $label';
        break;
      default:
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 10.5, color: fg, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSheet(Map<String, dynamic> tx, bool isNl) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BigDoggTheme.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _TransactionSheet(
        tx: tx,
        isNl: isNl,
        onChanged: (updated) {
          // Replace the tx in our list with the updated one (fresh link).
          final idx = _transactions.indexWhere((t) => t['id'] == tx['id']);
          if (idx >= 0) {
            setState(() {
              _transactions[idx] = {..._transactions[idx], ...updated};
            });
          }
        },
      ),
    );
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
        const Icon(Icons.error_outline, size: 56, color: BigDoggTheme.error),
        const SizedBox(height: 12),
        Text(
          isNl ? 'Kon transacties niet ophalen' : 'Could not fetch transactions',
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
          isNl ? 'Nog geen transacties gevonden' : 'No transactions yet',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: BigDoggTheme.lightTextSecondary),
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
              final link = tx['link'] as Map<String, dynamic>?;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _openSheet(tx, isNl),
                child: Container(
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
                            if (merchant.isNotEmpty &&
                                desc.isNotEmpty &&
                                desc != merchant)
                              Text(
                                desc,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: BigDoggTheme.lightTextHint,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            _linkBadge(link, isNl),
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
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

/// Bottom sheet shown when a user taps a transaction.
/// Lets them confirm a suggestion, mark a payment for an invoice,
/// turn a transaction into an expense, mark as private, or unlink.
class _TransactionSheet extends StatefulWidget {
  final Map<String, dynamic> tx;
  final bool isNl;
  final void Function(Map<String, dynamic> updated) onChanged;
  const _TransactionSheet({
    required this.tx,
    required this.isNl,
    required this.onChanged,
  });

  @override
  State<_TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends State<_TransactionSheet> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final tx = widget.tx;
    final isNl = widget.isNl;
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
    final desc = (tx['description'] as String?) ?? '';
    final merchant = (tx['merchant'] as String?) ?? '';
    final link = tx['link'] as Map<String, dynamic>?;
    final linkType = link?['type']?.toString();
    final isIncome = amount > 0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: BigDoggTheme.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              merchant.isNotEmpty ? merchant : desc,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: BigDoggTheme.teal800),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (merchant.isNotEmpty && desc.isNotEmpty && desc != merchant) ...[
              const SizedBox(height: 4),
              Text(
                desc,
                style: const TextStyle(
                    fontSize: 12, color: BigDoggTheme.lightTextSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${amount >= 0 ? '+' : '−'} € ${amount.abs().toStringAsFixed(2).replaceAll('.', ',')}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: amount >= 0
                    ? BigDoggTheme.success
                    : BigDoggTheme.error,
              ),
            ),
            const SizedBox(height: 16),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              ..._buildActions(linkType, isIncome, isNl),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActions(String? linkType, bool isIncome, bool isNl) {
    final tx = widget.tx;
    final link = tx['link'] as Map<String, dynamic>?;
    final widgets = <Widget>[];

    // Already firmly linked → only allow unlink.
    if (linkType == 'invoice' || linkType == 'expense' || linkType == 'private') {
      final label = link?['linked_label']?.toString() ?? '';
      String text;
      if (linkType == 'invoice') {
        text = isNl
            ? 'Gekoppeld aan factuur $label'
            : 'Linked to invoice $label';
      } else if (linkType == 'expense') {
        text = isNl ? 'Gekoppeld aan kosten · $label' : 'Linked to expense · $label';
      } else {
        text = isNl ? 'Gemarkeerd als privé' : 'Marked as private';
      }
      widgets.add(_infoBox(text));
      widgets.add(const SizedBox(height: 12));
      widgets.add(_btn(
        outline: true,
        color: BigDoggTheme.error,
        icon: Icons.link_off,
        label: isNl ? 'Ontkoppel' : 'Unlink',
        onTap: () => _unlink(),
      ));
      return widgets;
    }

    // Suggestion → one-tap confirm.
    if (linkType == 'suggested_invoice' || linkType == 'suggested_expense') {
      final suggestedId = link?['linked_id']?.toString();
      final suggestedLabel = link?['linked_label']?.toString() ?? '';
      final firmType = linkType == 'suggested_invoice' ? 'invoice' : 'expense';
      widgets.add(_btn(
        color: BigDoggTheme.success,
        icon: Icons.check_circle,
        label: isNl
            ? (firmType == 'invoice'
                ? 'Bevestig: betaling van factuur $suggestedLabel'
                : 'Bevestig: kosten · $suggestedLabel')
            : (firmType == 'invoice'
                ? 'Confirm: payment of invoice $suggestedLabel'
                : 'Confirm: expense · $suggestedLabel'),
        onTap: () => _confirmLink(firmType, suggestedId),
      ));
      widgets.add(const SizedBox(height: 8));
    }

    if (isIncome) {
      widgets.add(_btn(
        color: BigDoggTheme.teal800,
        icon: Icons.receipt,
        label: isNl
            ? 'Markeer als betaling van factuur…'
            : 'Mark as payment of invoice…',
        onTap: () => _pickInvoice(),
      ));
    } else {
      widgets.add(_btn(
        color: BigDoggTheme.teal800,
        icon: Icons.shopping_bag_outlined,
        label: isNl ? 'Voeg toe als zakelijke kosten' : 'Add as business expense',
        onTap: () => _createExpense(),
      ));
    }
    widgets.add(const SizedBox(height: 8));
    widgets.add(_btn(
      outline: true,
      color: BigDoggTheme.lightTextSecondary,
      icon: Icons.lock_outline,
      label: isNl ? 'Privé / negeren' : 'Private / ignore',
      onTap: () => _markPrivate(),
    ));
    return widgets;
  }

  Widget _infoBox(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BigDoggTheme.successBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle, size: 16, color: BigDoggTheme.success),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: BigDoggTheme.success),
          ),
        ),
      ]),
    );
  }

  Widget _btn({
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool outline = false,
  }) {
    if (outline) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _busy ? null : onTap,
          icon: Icon(icon, size: 16),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _busy ? null : onTap,
        icon: Icon(icon, size: 16, color: Colors.white),
        label: Text(label, style: const TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Future<void> _confirmLink(String type, String? linkedId) async {
    if (linkedId == null) return;
    setState(() => _busy = true);
    final result = await BankingService.setTransactionLink(
      txId: widget.tx['id'].toString(),
      linkType: type,
      linkedId: linkedId,
    );
    if (!mounted) return;
    if (result['success'] == true) {
      final label = (widget.tx['link'] as Map?)?['linked_label']?.toString() ?? '';
      widget.onChanged({
        'link': {
          'type': type,
          'linked_id': linkedId,
          'linked_label': label,
          'auto': false,
        }
      });
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: BigDoggTheme.error,
        content: Text(result['message']?.toString() ?? 'Error'),
      ));
    }
  }

  Future<void> _unlink() async {
    setState(() => _busy = true);
    // If the previous link was an auto-marked invoice, the backend will
    // revert the invoice status as part of the unlink call.
    final result = await BankingService.setTransactionLink(
      txId: widget.tx['id'].toString(),
      linkType: null,
    );
    if (!mounted) return;
    if (result['success'] == true) {
      widget.onChanged({'link': null});
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
    }
  }

  Future<void> _markPrivate() async {
    setState(() => _busy = true);
    final result = await BankingService.setTransactionLink(
      txId: widget.tx['id'].toString(),
      linkType: 'private',
    );
    if (!mounted) return;
    if (result['success'] == true) {
      widget.onChanged({
        'link': {
          'type': 'private',
          'linked_id': null,
          'linked_label': widget.isNl ? 'Privé' : 'Private',
          'auto': false,
        }
      });
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
    }
  }

  Future<void> _pickInvoice() async {
    final result = await InvoicesService.getInvoices();
    if (!mounted) return;
    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.isNl ? 'Kon facturen niet laden' : 'Could not load invoices'),
        backgroundColor: BigDoggTheme.error,
      ));
      return;
    }
    final invoices = (result['invoices'] as List?) ?? const [];
    final unpaid = invoices.where((i) => (i['status']?.toString() ?? '') != 'paid').toList();
    if (unpaid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.isNl ? 'Geen openstaande facturen' : 'No unpaid invoices'),
      ));
      return;
    }
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BigDoggTheme.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: 480,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: BigDoggTheme.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.isNl ? 'Kies een factuur' : 'Pick an invoice',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: BigDoggTheme.teal800),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: unpaid.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final inv = unpaid[i] as Map<String, dynamic>;
                    final num = inv['invoice_number']?.toString() ?? '';
                    final clientName = inv['client_name']?.toString() ?? '';
                    final clientCo = inv['client_company']?.toString() ?? '';
                    final total = (inv['total_incl_btw'] as num?)?.toDouble() ?? 0;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        num,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        clientCo.isNotEmpty ? clientCo : clientName,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Text(
                        '€ ${total.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () => Navigator.pop(ctx, inv),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || picked == null) return;
    await _confirmLink('invoice', picked['id'].toString());
  }

  Future<void> _createExpense() async {
    final tx = widget.tx;
    final isNl = widget.isNl;
    final initialDescription =
        (tx['merchant']?.toString() ?? tx['description']?.toString() ?? '').trim();
    final amount = ((tx['amount'] as num?)?.toDouble() ?? 0).abs();
    final txDate = (tx['date'] as String?) ?? DateTime.now().toIso8601String().split('T').first;

    final descCtrl = TextEditingController(text: initialDescription);
    double btwRate = 21;
    // amount_ex_btw computed from total / (1 + rate/100). Default rate 21.
    double amountExBtw = amount / (1 + btwRate / 100);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          title: Text(isNl ? 'Nieuwe kostenpost' : 'New expense'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: isNl ? 'Omschrijving' : 'Description',
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Text(isNl ? 'BTW:' : 'VAT:', style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 12),
                  ...[0, 9, 21].map((r) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('$r%'),
                          selected: btwRate == r.toDouble(),
                          onSelected: (_) => setLocal(() {
                            btwRate = r.toDouble();
                            amountExBtw = amount / (1 + btwRate / 100);
                          }),
                        ),
                      )),
                ]),
                const SizedBox(height: 12),
                Text(
                  '${isNl ? 'Bedrag excl. BTW' : 'Amount ex VAT'}: € ${amountExBtw.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 12, color: BigDoggTheme.lightTextSecondary),
                ),
                Text(
                  '${isNl ? 'Totaal incl. BTW' : 'Total incl VAT'}: € ${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 12, color: BigDoggTheme.lightTextSecondary),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(isNl ? 'Annuleren' : 'Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: BigDoggTheme.teal800),
              child: Text(isNl ? 'Aanmaken' : 'Create',
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );
    if (!mounted || ok != true) return;

    setState(() => _busy = true);
    final result = await BankingService.createExpenseFromTransaction(
      txId: tx['id'].toString(),
      description: descCtrl.text.trim().isEmpty ? 'Bank transactie' : descCtrl.text.trim(),
      amountExBtw: double.parse(amountExBtw.toStringAsFixed(2)),
      btwRate: btwRate,
      expenseDate: txDate,
    );
    if (!mounted) return;
    if (result['success'] == true) {
      final expense = result['expense'] as Map<String, dynamic>?;
      widget.onChanged({
        'link': {
          'type': 'expense',
          'linked_id': expense?['id']?.toString(),
          'linked_label': (expense?['description']?.toString() ?? '').substring(
              0,
              ((expense?['description']?.toString() ?? '').length).clamp(0, 40)),
          'auto': false,
        }
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: BigDoggTheme.success,
        content: Text(isNl ? 'Kosten toegevoegd' : 'Expense added'),
      ));
    } else {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: BigDoggTheme.error,
        content: Text(result['message']?.toString() ?? 'Error'),
      ));
    }
  }
}
