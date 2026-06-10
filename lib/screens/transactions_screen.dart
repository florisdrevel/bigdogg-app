import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/banking_service.dart';
import '../services/invoices_service.dart';
import '../services/web_io.dart';
import '../theme.dart';

/// Bank-transactions screen with auto-matching against invoices and
/// expenses. Each row renders a link badge (auto-matched, suggested,
/// private, or unlinked) and a tap opens a bottom sheet with the
/// available actions.
///
/// `focusTxId` (optional) is a deep-link target — when provided, after
/// the list loads we auto-open the bottom sheet on that row so a user
/// arriving from a notification lands directly on the actionable view.
class TransactionsScreen extends StatefulWidget {
  final String? focusTxId;
  const TransactionsScreen({super.key, this.focusTxId});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _transactions = const [];
  bool _matchedOnly = false;
  bool _downloading = false;

  bool _isMatched(Map<String, dynamic> tx) {
    final t = (tx['link'] as Map<String, dynamic>?)?['type']?.toString();
    return t == 'invoice' || t == 'expense' || t == 'investment';
  }

  List<Map<String, dynamic>> get _visible =>
      _matchedOnly ? _transactions.where(_isMatched).toList() : _transactions;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _focusHandled = false;

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
      // Deep-link: open the sheet on the requested transaction once.
      if (!_focusHandled &&
          widget.focusTxId != null &&
          widget.focusTxId!.isNotEmpty) {
        _focusHandled = true;
        final isNl = context.read<AppProvider>().language == 'nl';
        final tx = _transactions.firstWhere(
          (t) => t['id'] == widget.focusTxId,
          orElse: () => const {},
        );
        if (tx.isNotEmpty) {
          // Schedule after build so the route transition completes
          // before we push the bottom sheet on top.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openSheet(tx, isNl);
          });
        }
      }
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
      case 'investment':
        bg = BigDoggTheme.successBg;
        fg = BigDoggTheme.success;
        icon = Icons.check_circle;
        text = isNl ? 'Investering · $label' : 'Investment · $label';
        break;
      case 'private':
        bg = BigDoggTheme.lightSurface2;
        fg = BigDoggTheme.lightTextSecondary;
        icon = Icons.lock_outline;
        text = isNl ? 'Privé' : 'Private';
        break;
      case 'suggested_invoice':
      case 'suggested_expense':
      case 'suggested_investment':
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
        // Targets already linked to OTHER transactions — excluded from the
        // invoice picker so the same invoice can't be linked twice.
        linkedTargetIds: <String>{
          for (final t in _transactions)
            if (t['id'] != tx['id'] && t['link'] is Map)
              if (const ['invoice', 'expense', 'investment']
                      .contains((t['link'] as Map)['type']) &&
                  (t['link'] as Map)['linked_id'] != null)
                (t['link'] as Map)['linked_id'].toString(),
        },
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
      backgroundColor: BigDoggTheme.lightBg,
      appBar: AppBar(
        title: Text(
          isNl ? 'Transacties' : 'Transactions',
          style: const TextStyle(
            color: BigDoggTheme.teal800,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: BigDoggTheme.lightSurface,
        foregroundColor: BigDoggTheme.teal800,
        iconTheme: const IconThemeData(color: BigDoggTheme.teal800),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          if (!_loading && _error == null && _transactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                tooltip: isNl ? 'Download rapport (PDF)' : 'Download report (PDF)',
                icon: _downloading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                onPressed: _downloading ? null : () => _downloadReport(isNl),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_error == null && _transactions.isNotEmpty)
                    _buildFilterBar(isNl),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: _error != null
                          ? _buildError(isNl)
                          : _visible.isEmpty
                              ? _buildEmpty(isNl)
                              : _buildList(isNl),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFilterBar(bool isNl) {
    final matchedCount = _transactions.where(_isMatched).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      decoration: const BoxDecoration(
        color: BigDoggTheme.lightSurface,
        border: Border(bottom: BorderSide(color: BigDoggTheme.lightBorder)),
      ),
      child: Row(
        children: [
          const Icon(Icons.link, size: 16, color: BigDoggTheme.teal800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isNl ? 'Alleen gekoppelde tonen' : 'Show matched only',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: BigDoggTheme.teal800,
              ),
            ),
          ),
          Text(
            '$matchedCount/${_transactions.length}',
            style: const TextStyle(
                fontSize: 11, color: BigDoggTheme.lightTextHint),
          ),
          Switch(
            value: _matchedOnly,
            activeColor: BigDoggTheme.teal800,
            onChanged: (v) => setState(() => _matchedOnly = v),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadReport(bool isNl) async {
    setState(() => _downloading = true);
    final bytes = await BankingService.fetchReportPdf(matchedOnly: _matchedOnly);
    if (!mounted) return;
    setState(() => _downloading = false);
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: BigDoggTheme.error,
        content: Text(isNl ? 'Download mislukt' : 'Download failed'),
      ));
      return;
    }
    final name = _matchedOnly
        ? 'bigdogg-transacties-gekoppeld.pdf'
        : 'bigdogg-transacties.pdf';
    downloadBytes(name, bytes, mimeType: 'application/pdf');
  }

  Widget _buildError(bool isNl) {
    final isExpired = (_error ?? '').contains('bank_session_expired');
    if (isExpired) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          const Icon(Icons.timer_off_outlined,
              size: 64, color: BigDoggTheme.warning),
          const SizedBox(height: 16),
          Text(
            isNl
                ? 'Bank-koppeling verlopen'
                : 'Bank connection expired',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: BigDoggTheme.teal800),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              isNl
                  ? 'Tink-toegang in sandbox is ~1 uur geldig. Koppel je bankrekening opnieuw om de meest recente transacties op te halen.'
                  : 'Tink sandbox access is ~1 hour. Reconnect your bank to fetch the latest transactions.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: BigDoggTheme.lightTextSecondary),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              onPressed: () => context.go('/dashboard?tab=settings'),
              icon: const Icon(Icons.account_balance, color: Colors.white, size: 16),
              label: Text(
                isNl ? 'Ga naar instellingen' : 'Go to settings',
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: BigDoggTheme.teal800,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      );
    }
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
          (_matchedOnly && _transactions.isNotEmpty)
              ? (isNl ? 'Geen gekoppelde transacties' : 'No matched transactions')
              : (isNl ? 'Nog geen transacties gevonden' : 'No transactions yet'),
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
    for (final tx in _visible) {
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
  final Set<String> linkedTargetIds;
  final void Function(Map<String, dynamic> updated) onChanged;
  const _TransactionSheet({
    required this.tx,
    required this.isNl,
    required this.linkedTargetIds,
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
    final txDate = (tx['date'] as String?) ?? '';
    final link = tx['link'] as Map<String, dynamic>?;
    final linkType = link?['type']?.toString();
    final isIncome = amount > 0;

    final heroTitle = merchant.isNotEmpty ? merchant : desc;
    final heroSubtitle = (merchant.isNotEmpty && desc.isNotEmpty && desc != merchant) ? desc : '';
    final amountColor = isIncome ? BigDoggTheme.success : BigDoggTheme.error;
    final amountBg = isIncome ? BigDoggTheme.successBg : BigDoggTheme.errorBg;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: BigDoggTheme.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ─── Hero card: merchant + amount ───
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: amountBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isIncome ? Icons.south_west : Icons.north_east,
                        color: amountColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            heroTitle.isEmpty ? (isNl ? 'Transactie' : 'Transaction') : heroTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: BigDoggTheme.lightTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (heroSubtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              heroSubtitle,
                              style: const TextStyle(
                                fontSize: 11,
                                color: BigDoggTheme.lightTextSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (txDate.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              txDate,
                              style: const TextStyle(
                                fontSize: 11,
                                color: BigDoggTheme.lightTextHint,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${isIncome ? '+' : '−'} € ${amount.abs().toStringAsFixed(2).replaceAll('.', ',')}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: amountColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── Body: actions ───
              if (_busy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                ..._buildBody(linkType, isIncome, isNl),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBody(String? linkType, bool isIncome, bool isNl) {
    final tx = widget.tx;
    final link = tx['link'] as Map<String, dynamic>?;
    final widgets = <Widget>[];

    // ── Suggestion banner: yellow card with "Ja"/"Nee" buttons. ──
    if (linkType == 'suggested_invoice' ||
        linkType == 'suggested_expense' ||
        linkType == 'suggested_investment') {
      final suggestedId = link?['linked_id']?.toString();
      final suggestedLabel = link?['linked_label']?.toString() ?? '';
      final firmType = linkType == 'suggested_invoice'
          ? 'invoice'
          : (linkType == 'suggested_investment' ? 'investment' : 'expense');
      widgets.add(Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BigDoggTheme.warningBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BigDoggTheme.warning.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.bolt, size: 16, color: BigDoggTheme.warning),
              const SizedBox(width: 6),
              Text(
                isNl ? 'Mogelijk match' : 'Possible match',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: BigDoggTheme.warning,
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              firmType == 'invoice'
                  ? (isNl
                      ? 'Wij denken dat dit een betaling is van factuur $suggestedLabel.'
                      : 'We think this is a payment of invoice $suggestedLabel.')
                  : firmType == 'investment'
                      ? (isNl
                          ? 'Wij denken dat dit hoort bij investering · $suggestedLabel.'
                          : 'We think this matches investment · $suggestedLabel.')
                      : (isNl
                          ? 'Wij denken dat dit hoort bij kosten · $suggestedLabel.'
                          : 'We think this matches expense · $suggestedLabel.'),
              style: const TextStyle(
                fontSize: 13,
                color: BigDoggTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : () => _confirmLink(firmType, suggestedId),
                  icon: const Icon(Icons.check, size: 16, color: Colors.white),
                  label: Text(isNl ? 'Klopt' : 'Confirm',
                      style: const TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BigDoggTheme.success,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _unlink(silent: true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BigDoggTheme.lightTextSecondary,
                    side: const BorderSide(color: BigDoggTheme.lightBorder),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(isNl ? 'Anders' : 'Different'),
                ),
              ),
            ]),
          ],
        ),
      ));
      widgets.add(const SizedBox(height: 16));
    }

    // ── Already linked: status banner + only "Ontkoppel" row. ──
    if (linkType == 'invoice' ||
        linkType == 'expense' ||
        linkType == 'investment' ||
        linkType == 'private') {
      final label = link?['linked_label']?.toString() ?? '';
      String text;
      IconData icon = Icons.check_circle;
      Color color = BigDoggTheme.success;
      Color bg = BigDoggTheme.successBg;
      if (linkType == 'invoice') {
        text = isNl ? 'Gekoppeld aan factuur $label' : 'Linked to invoice $label';
      } else if (linkType == 'expense') {
        text = isNl ? 'Gekoppeld aan kosten · $label' : 'Linked to expense · $label';
      } else if (linkType == 'investment') {
        text = isNl ? 'Gekoppeld aan investering · $label' : 'Linked to investment · $label';
      } else {
        text = isNl ? 'Gemarkeerd als privé' : 'Marked as private';
        icon = Icons.lock_outline;
        color = BigDoggTheme.lightTextSecondary;
        bg = BigDoggTheme.lightSurface2;
      }
      widgets.add(Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: color,
              ),
            ),
          ),
        ]),
      ));
      widgets.add(const SizedBox(height: 12));
      widgets.add(_actionRow(
        icon: Icons.link_off,
        iconColor: BigDoggTheme.error,
        title: isNl ? 'Ontkoppel' : 'Unlink',
        subtitle: isNl
            ? (linkType == 'invoice'
                ? 'Factuur weer als verzonden markeren'
                : 'Verwijder de koppeling')
            : 'Remove the link',
        onTap: _unlink,
      ));
      return widgets;
    }

    // ── Unlinked: primary action + Privé. ──
    if (isIncome) {
      widgets.add(_actionRow(
        icon: Icons.receipt_long,
        iconColor: BigDoggTheme.teal800,
        title: isNl ? 'Markeer als betaling van factuur' : 'Mark as invoice payment',
        subtitle: isNl
            ? 'Kies welke openstaande factuur is betaald'
            : 'Pick which unpaid invoice this settles',
        onTap: _pickInvoice,
      ));
    } else {
      widgets.add(_actionRow(
        icon: Icons.shopping_bag_outlined,
        iconColor: BigDoggTheme.teal800,
        title: isNl ? 'Voeg toe als zakelijke kosten' : 'Add as business expense',
        subtitle: isNl
            ? 'Maak een kostenpost aan met BTW'
            : 'Create an expense entry with VAT',
        onTap: _createExpense,
      ));
      widgets.add(_actionRow(
        icon: Icons.precision_manufacturing_outlined,
        iconColor: BigDoggTheme.teal800,
        title: isNl ? 'Voeg toe als investering' : 'Add as investment',
        subtitle: isNl
            ? 'Voor aankopen die je afschrijft over meerdere jaren'
            : 'For purchases depreciated over multiple years',
        onTap: _createInvestment,
      ));
    }
    widgets.add(_actionRow(
      icon: Icons.lock_outline,
      iconColor: BigDoggTheme.lightTextSecondary,
      title: isNl ? 'Privé / negeren' : 'Private / ignore',
      subtitle: isNl
          ? 'Hoort niet bij je administratie'
          : 'Does not belong to your bookkeeping',
      onTap: _markPrivate,
    ));
    return widgets;
  }

  Widget _actionRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _busy ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            decoration: BoxDecoration(
              color: BigDoggTheme.lightSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BigDoggTheme.lightBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 18, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: BigDoggTheme.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: BigDoggTheme.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: BigDoggTheme.lightTextHint,
                  ),
                ],
              ),
            ),
          ),
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
      final raw = result['message']?.toString() ?? 'Error';
      final msg = raw.contains('already_linked')
          ? (widget.isNl
              ? 'Dit is al aan een andere transactie gekoppeld.'
              : 'This is already linked to another transaction.')
          : raw;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: BigDoggTheme.error,
        content: Text(msg),
      ));
    }
  }

  Future<void> _unlink({bool silent = false}) async {
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
      // Mutate the local map so the sheet re-renders with no link.
      widget.tx['link'] = null;
      setState(() => _busy = false);
      if (!silent) {
        Navigator.pop(context);
      }
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
    // Show paid AND unpaid invoices — you may want to match a payment to an
    // invoice you already marked paid manually. Exclude invoices already
    // linked to another transaction (one-to-one).
    final available = invoices
        .where((i) => !widget.linkedTargetIds.contains(i['id']?.toString()))
        .toList()
      ..sort((a, b) {
        // Unpaid first, then paid.
        final ap = (a['status']?.toString() ?? '') == 'paid' ? 1 : 0;
        final bp = (b['status']?.toString() ?? '') == 'paid' ? 1 : 0;
        return ap.compareTo(bp);
      });
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.isNl
            ? 'Geen koppelbare facturen'
            : 'No linkable invoices'),
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
                  itemCount: available.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final inv = available[i] as Map<String, dynamic>;
                    final invNum = inv['invoice_number']?.toString() ?? '';
                    final clientName = inv['client_name']?.toString() ?? '';
                    final clientCo = inv['client_company']?.toString() ?? '';
                    final total = (inv['total_incl_btw'] as num?)?.toDouble() ?? 0;
                    final isPaid = (inv['status']?.toString() ?? '') == 'paid';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              invNum,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isPaid) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: BigDoggTheme.successBg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.isNl ? 'Betaald' : 'Paid',
                                style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: BigDoggTheme.success),
                              ),
                            ),
                          ],
                        ],
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

  Future<void> _createInvestment() async {
    final tx = widget.tx;
    final isNl = widget.isNl;
    final initialDescription =
        (tx['merchant']?.toString() ?? tx['description']?.toString() ?? '').trim();
    final amount = ((tx['amount'] as num?)?.toDouble() ?? 0).abs();
    final txDate = (tx['date'] as String?) ?? DateTime.now().toIso8601String().split('T').first;

    final descCtrl = TextEditingController(text: initialDescription);
    int years = 5;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          title: Text(isNl ? 'Nieuwe investering' : 'New investment'),
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
                  Text(
                    isNl ? 'Afschrijving:' : 'Depreciation:',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  ...[3, 5, 10].map((y) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(isNl ? '$y jaar' : '$y yr'),
                          selected: years == y,
                          onSelected: (_) => setLocal(() => years = y),
                        ),
                      )),
                ]),
                const SizedBox(height: 12),
                Text(
                  '${isNl ? 'Aankoopbedrag' : 'Purchase amount'}: € ${amount.toStringAsFixed(2)}',
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
    final result = await BankingService.createInvestmentFromTransaction(
      txId: tx['id'].toString(),
      description: descCtrl.text.trim().isEmpty ? 'Bank transactie' : descCtrl.text.trim(),
      amount: amount,
      purchaseDate: txDate,
      depreciationYears: years,
    );
    if (!mounted) return;
    if (result['success'] == true) {
      final inv = result['investment'] as Map<String, dynamic>?;
      widget.onChanged({
        'link': {
          'type': 'investment',
          'linked_id': inv?['id']?.toString(),
          'linked_label': (inv?['description']?.toString() ?? '').substring(
              0,
              ((inv?['description']?.toString() ?? '').length).clamp(0, 40)),
          'auto': false,
        }
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: BigDoggTheme.success,
        content: Text(isNl ? 'Investering toegevoegd' : 'Investment added'),
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
