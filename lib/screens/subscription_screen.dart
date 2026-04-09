import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/subscription_service.dart';

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
          SnackBar(content: Text(result['message'] ?? 'Something went wrong'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Subscription', style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 24),
                  _buildPlanCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    if (_subscription == null) return const SizedBox();

    final status = _subscription!['status'];
    final isActive = _subscription!['is_active'] ?? false;
    final daysLeft = _subscription!['days_left'];

    Color statusColor;
    String statusText;
    String statusDetail;

    if (status == 'trial') {
      statusColor = daysLeft > 3 ? const Color(0xFF059669) : const Color(0xFFF59E0B);
      statusText = 'Free Trial';
      statusDetail = daysLeft > 0
          ? '$daysLeft days remaining'
          : 'Trial expired';
    } else if (status == 'active') {
      statusColor = const Color(0xFF059669);
      statusText = 'Active';
      statusDetail = 'Subscription active';
    } else {
      statusColor = const Color(0xFFDC2626);
      statusText = 'Expired';
      statusDetail = 'Please subscribe to continue';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
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
                Text(statusText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                Text(statusDetail, style: TextStyle(color: statusColor, fontSize: 14)),
              ],
            ),
          ),
          if (!isActive || status == 'trial')
            ElevatedButton(
              onPressed: _checkingOut ? null : _startCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1A1A2E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _checkingOut
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Subscribe', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildPlanCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bigdogg Pro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                      Text('Everything you need as a ZZP\'er', style: TextStyle(color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('€12', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28)),
                    const Text('per month', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            _feature('✓ Unlimited invoices'),
            _feature('✓ AI prompt to invoice'),
            _feature('✓ Client management'),
            _feature('✓ Expense tracking'),
            _feature('✓ Quarterly BTW overview'),
            _feature('✓ Annual financial overview'),
            _feature('✓ Receipt scanning'),
            _feature('✓ iDEAL, credit card via Mollie'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _checkingOut ? null : _startCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A2E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _checkingOut
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Start subscription — €12/month', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Cancel anytime · iDEAL, credit card, PayPal',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 15)),
    );
  }
}