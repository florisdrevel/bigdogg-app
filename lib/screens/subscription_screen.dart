import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/subscription_service.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../widgets/subscription_web_widget.dart';

/// Read-only subscription overview: shows the user's current status and
/// directs all billing actions to bigdogg.nl. No payment UI in the app.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  Map<String, dynamic>? _subscription;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _loading = true);
    final result = await SubscriptionService.getStatus();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success']) _subscription = result['subscription'];
    });
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
          const SizedBox(height: 16),
          SubscriptionWebCard(isNl: isNl),
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool isNl) {
    if (_subscription == null) return const SizedBox();
    final status = _subscription!['status'];
    final daysLeft = _subscription!['days_left'];

    Color statusColor;
    String statusText;
    String statusDetail;

    if (status == 'trial') {
      statusColor = daysLeft != null && daysLeft > 5
          ? BigDoggTheme.success
          : BigDoggTheme.warning;
      statusText = isNl ? 'Proefperiode' : 'Trial';
      statusDetail = (daysLeft ?? 0) > 0
          ? (isNl ? '$daysLeft dagen resterend' : '$daysLeft days remaining')
          : (isNl ? 'Proefperiode afgelopen' : 'Trial ended');
    } else if (status == 'active') {
      statusColor = BigDoggTheme.success;
      statusText = isNl ? 'Actief' : 'Active';
      statusDetail = isNl ? 'Abonnement actief' : 'Subscription active';
    } else {
      statusColor = BigDoggTheme.warning;
      statusText = isNl ? 'Niet actief' : 'Inactive';
      statusDetail = isNl ? 'Geen actief abonnement' : 'No active subscription';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration:
                BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(statusText,
                    style: const TextStyle(
                        color: BigDoggTheme.teal800,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                Text(statusDetail,
                    style: TextStyle(
                        color: BigDoggTheme.lightTextSecondary, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
