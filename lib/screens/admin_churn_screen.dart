import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../services/api_config.dart';
import '../theme.dart';

/// `bigdogg.nl/#/admin/churn?token=<cron_secret>&since=YYYY-MM-DD`.
///
/// Solo-founder churn dashboard. Auth is the cron_secret passed as
/// `x-cron-secret` header; we pull it from the URL `?token=` and put it
/// on every request. Not bullet-proof (URLs land in logs) but fine for
/// internal use.
class AdminChurnScreen extends StatefulWidget {
  const AdminChurnScreen({super.key});

  @override
  State<AdminChurnScreen> createState() => _AdminChurnScreenState();
}

class _AdminChurnScreenState extends State<AdminChurnScreen> {
  String? _token;
  String? _since;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final state = GoRouterState.of(context);
    _token = state.uri.queryParameters['token'];
    _since = state.uri.queryParameters['since'];
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing ?token=<cron_secret> in URL';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = StringBuffer(
          '${ApiConfig.baseUrl}/api/v1/subscription/admin/churn-stats');
      if ((_since ?? '').isNotEmpty) {
        url.write('?since=$_since');
      }
      final resp = await http.get(
        Uri.parse(url.toString()),
        headers: {'x-cron-secret': token},
      );
      if (resp.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'HTTP ${resp.statusCode}: ${resp.body}';
        });
        return;
      }
      setState(() {
        _loading = false;
        _data = jsonDecode(resp.body) as Map<String, dynamic>;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Connection error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      appBar: AppBar(
        title: const Text('Churn'),
        backgroundColor: BigDoggTheme.teal800,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : _body(),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: BigDoggTheme.error, size: 56),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: BigDoggTheme.lightTextPrimary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final data = _data!;
    final totals = (data['totals'] as Map?) ?? {};
    final saveRate = (data['save_rate_pct'] as num?)?.toDouble() ?? 0;
    final reasonBreakdown = (data['reason_breakdown'] as Map?) ?? {};
    final monthly = (data['monthly'] as List?) ?? const [];
    final recentComments = (data['recent_comments'] as List?) ?? const [];
    final since = (data['since'] ?? '').toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Sinds $since',
                  style: const TextStyle(
                      color: BigDoggTheme.lightTextSecondary, fontSize: 13)),
              const SizedBox(height: 14),

              // KPI row
              LayoutBuilder(builder: (ctx, constraints) {
                final wide = constraints.maxWidth > 700;
                final tiles = [
                  _kpi('Cancelled',
                      (totals['cancelled'] ?? 0).toString(),
                      BigDoggTheme.error),
                  _kpi('Offer accepted',
                      (totals['offer_accepted'] ?? 0).toString(),
                      BigDoggTheme.success),
                  _kpi('Reactivated',
                      (totals['reactivated'] ?? 0).toString(),
                      BigDoggTheme.teal700),
                  _kpi('Save rate',
                      '${saveRate.toStringAsFixed(1)}%',
                      BigDoggTheme.gold600),
                ];
                if (wide) {
                  return Row(
                    children: [
                      for (final t in tiles) ...[
                        Expanded(child: t),
                        if (t != tiles.last) const SizedBox(width: 12),
                      ],
                    ],
                  );
                }
                return Column(
                  children: [
                    for (final t in tiles) ...[
                      t,
                      if (t != tiles.last) const SizedBox(height: 10),
                    ],
                  ],
                );
              }),
              const SizedBox(height: 28),

              _sectionTitle('Reason breakdown'),
              const SizedBox(height: 10),
              _reasonTable(reasonBreakdown.cast<String, dynamic>()),
              const SizedBox(height: 28),

              _sectionTitle('By month'),
              const SizedBox(height: 10),
              _monthlyTable(monthly.cast<Map<dynamic, dynamic>>()),
              const SizedBox(height: 28),

              _sectionTitle('Recent comments'),
              const SizedBox(height: 10),
              if (recentComments.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BigDoggTheme.lightSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: BigDoggTheme.lightBorder),
                  ),
                  child: const Text('No comments yet.',
                      style: TextStyle(
                          color: BigDoggTheme.lightTextSecondary,
                          fontSize: 13)),
                )
              else
                Column(
                  children: [
                    for (final c in recentComments.cast<Map>())
                      _commentCard(c.cast<String, dynamic>()),
                  ],
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: BigDoggTheme.teal800,
          letterSpacing: -0.2,
          fontFamily: 'PlusJakartaSans'));

  Widget _kpi(String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: BigDoggTheme.lightTextSecondary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: accent,
                  letterSpacing: -0.4)),
        ],
      ),
    );
  }

  Widget _reasonTable(Map<String, dynamic> breakdown) {
    final reasons = breakdown.keys.toList();
    if (reasons.isEmpty) {
      return _emptyCard('No cancellation events in this window.');
    }
    return Container(
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Column(
        children: [
          _tableHeaderRow(const [
            'Reason',
            'Cancelled',
            'Offer accepted',
            'Reactivated',
          ]),
          for (final r in reasons)
            _tableRow([
              _humanReason(r),
              (breakdown[r]?['cancelled'] ?? 0).toString(),
              (breakdown[r]?['offer_accepted'] ?? 0).toString(),
              (breakdown[r]?['reactivated'] ?? 0).toString(),
            ]),
        ],
      ),
    );
  }

  Widget _monthlyTable(List<Map<dynamic, dynamic>> monthly) {
    if (monthly.isEmpty) {
      return _emptyCard('No monthly data yet.');
    }
    return Container(
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Column(
        children: [
          _tableHeaderRow(const [
            'Month',
            'Cancelled',
            'Offer accepted',
            'Reactivated',
          ]),
          for (final m in monthly)
            _tableRow([
              (m['month'] ?? '').toString(),
              (m['cancelled'] ?? 0).toString(),
              (m['offer_accepted'] ?? 0).toString(),
              (m['reactivated'] ?? 0).toString(),
            ]),
        ],
      ),
    );
  }

  Widget _tableHeaderRow(List<String> cells) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: BigDoggTheme.teal800,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          for (final c in cells)
            Expanded(
              flex: c == cells.first ? 2 : 1,
              child: Text(c.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1)),
            ),
        ],
      ),
    );
  }

  Widget _tableRow(List<String> cells) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: BigDoggTheme.lightBorder)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: i == 0 ? 2 : 1,
              child: Text(
                cells[i],
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w500,
                    color: i == 0
                        ? BigDoggTheme.lightTextPrimary
                        : BigDoggTheme.teal800),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Text(text,
          style: const TextStyle(
              color: BigDoggTheme.lightTextSecondary, fontSize: 13)),
    );
  }

  Widget _commentCard(Map<String, dynamic> c) {
    final happenedRaw = (c['happened_at'] ?? '').toString();
    String when = '';
    try {
      when = DateTime.parse(happenedRaw)
          .toLocal()
          .toIso8601String()
          .substring(0, 16)
          .replaceFirst('T', ' ');
    } catch (_) {}
    final reason = _humanReason((c['reason'] ?? '').toString());
    final outcome = (c['outcome'] ?? '').toString();
    final plan = (c['plan'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
              Expanded(
                child: Text(reason,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: BigDoggTheme.teal800)),
              ),
              _outcomeChip(outcome),
            ],
          ),
          if (plan.isNotEmpty || when.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (plan.isNotEmpty) plan,
                if (when.isNotEmpty) when,
              ].join(' · '),
              style: const TextStyle(
                  fontSize: 11.5,
                  color: BigDoggTheme.lightTextHint,
                  fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            (c['comment'] ?? '').toString(),
            style: const TextStyle(
                fontSize: 13.5,
                color: BigDoggTheme.lightTextPrimary,
                height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _outcomeChip(String outcome) {
    Color bg;
    String label;
    switch (outcome) {
      case 'cancelled':
        bg = BigDoggTheme.error;
        label = 'Cancelled';
        break;
      case 'offer_accepted':
        bg = BigDoggTheme.success;
        label = 'Saved';
        break;
      case 'reactivated':
        bg = BigDoggTheme.teal700;
        label = 'Reactivated';
        break;
      default:
        bg = BigDoggTheme.lightTextHint;
        label = outcome;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label.toUpperCase(),
          style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5)),
    );
  }

  String _humanReason(String r) {
    switch (r) {
      case 'too_expensive':
        return 'Too expensive';
      case 'not_using':
        return 'Not using enough';
      case 'missing_feature':
        return 'Missing feature';
      case 'found_alternative':
        return 'Found alternative';
      case 'stopped_freelancing':
        return 'Stopped freelancing';
      case 'other':
        return 'Other';
      default:
        return r;
    }
  }
}
