import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/subscription_service.dart';
import '../providers/app_provider.dart';
import '../theme.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  Map<String, dynamic>? _subscription;
  bool _loading = true;
  bool _checkingOut = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _loading = true);
    final result = await SubscriptionService.getStatus();
    setState(() {
      _loading = false;
      if (result['success']) _subscription = result['subscription'];
    });
  }

  Future<void> _startCheckout() async {
    setState(() => _checkingOut = true);
    final result = await SubscriptionService.createCheckout();
    setState(() => _checkingOut = false);
    if (result['success']) {
      final url = Uri.parse(result['checkout_url']);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Something went wrong'),
            backgroundColor: BigDoggTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNl = context.watch<AppProvider>().language == 'nl';

    if (_loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusCard(isNl),
          const SizedBox(height: 24),
          _buildPlanCard(isNl),
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool isNl) {
    if (_subscription == null) return const SizedBox();
    final status = _subscription!['status'];
    final isActive = _subscription!['is_active'] ?? false;
    final daysLeft = _subscription!['days_left'];

    Color statusColor;
    String statusText;
    String statusDetail;

    if (status == 'trial') {
      statusColor = daysLeft > 3 ? BigDoggTheme.success : BigDoggTheme.warning;
      statusText = isNl ? 'Gratis proefperiode' : 'Free Trial';
      statusDetail = daysLeft > 0
          ? isNl ? '$daysLeft dagen resterend' : '$daysLeft days remaining'
          : isNl ? 'Proefperiode verlopen' : 'Trial expired';
    } else if (status == 'active') {
      statusColor = BigDoggTheme.success;
      statusText = isNl ? 'Actief' : 'Active';
      statusDetail = isNl ? 'Abonnement actief' : 'Subscription active';
    } else {
      statusColor = BigDoggTheme.error;
      statusText = isNl ? 'Verlopen' : 'Expired';
      statusDetail = isNl ? 'Verleng je abonnement om door te gaan' : 'Please subscribe to continue';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BigDoggTheme.teal800,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(statusText,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                Text(statusDetail, style: TextStyle(color: statusColor, fontSize: 14)),
              ],
            ),
          ),
          if (!isActive || status == 'trial')
            ElevatedButton(
              onPressed: _checkingOut ? null : _startCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: BigDoggTheme.teal800,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _checkingOut
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isNl ? 'Abonneren' : 'Subscribe',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(bool isNl) {
    return Container(
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('BigDogg Pro',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: BigDoggTheme.teal800)),
                    Text(
                      isNl ? 'Alles wat je nodig hebt als ZZP\'er' : 'Everything you need as a ZZP\'er',
                      style: const TextStyle(color: BigDoggTheme.lightTextSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('€12',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28, color: BigDoggTheme.teal800)),
                  Text(isNl ? 'per maand' : 'per month',
                      style: const TextStyle(color: BigDoggTheme.lightTextSecondary, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          _feature(isNl ? '✓ Onbeperkt facturen' : '✓ Unlimited invoices'),
          _feature(isNl ? '✓ AI factuur assistent' : '✓ AI invoice assistant'),
          _feature(isNl ? '✓ Klantenbeheer' : '✓ Client management'),
          _feature(isNl ? '✓ Uitgaven bijhouden' : '✓ Expense tracking'),
          _feature(isNl ? '✓ Kwartaal BTW overzicht' : '✓ Quarterly BTW overview'),
          _feature(isNl ? '✓ Jaaroverzicht financiën' : '✓ Annual financial overview'),
          _feature(isNl ? '✓ Bonnen scannen' : '✓ Receipt scanning'),
          _feature(isNl ? '✓ Betalen via Stripe (iDEAL, creditcard)' : '✓ Pay via Stripe (iDEAL, credit card)'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _checkingOut ? null : _startCheckout,
              child: _checkingOut
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      isNl ? 'Start abonnement — €12/maand' : 'Start subscription — €12/month',
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              isNl
                  ? 'Altijd opzegbaar · iDEAL en creditcard via Stripe'
                  : 'Cancel anytime · iDEAL and credit card via Stripe',
              style: const TextStyle(color: BigDoggTheme.lightTextHint, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _feature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 15, color: BigDoggTheme.lightTextPrimary)),
    );
  }
}