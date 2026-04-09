import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/subscription_service.dart';
import '../app_theme.dart';

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
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 16),
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
      statusColor =
          daysLeft > 3 ? AppColors.success : AppColors.warning;
      statusText = 'Free Trial';
      statusDetail =
          daysLeft > 0 ? '$daysLeft days remaining' : 'Trial expired';
    } else if (status == 'active') {
      statusColor = AppColors.success;
      statusText = 'Active';
      statusDetail = 'Subscription active';
    } else {
      statusColor = AppColors.danger;
      statusText = 'Expired';
      statusDetail = 'Please subscribe to continue';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: AppGradients.navySubtle,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusDetail,
                  style: TextStyle(color: statusColor, fontSize: 13),
                ),
              ],
            ),
          ),
          if (!isActive || status == 'trial')
            ElevatedButton(
              onPressed: _checkingOut ? null : _startCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.navy,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                minimumSize: const Size(0, 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  fontFamily: 'Inter',
                ),
              ),
              child: _checkingOut
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Subscribe'),
            ),
        ],
      ),
    );
  }

  Widget _buildPlanCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Bigdogg',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppGradients.navySubtle,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Pro',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Everything you need as a ZZP\'er',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    '€12',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 30,
                      color: AppColors.textPrimary,
                      letterSpacing: -1,
                    ),
                  ),
                  const Text(
                    'per month',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),
          Container(
            height: 1,
            color: AppColors.borderLight,
          ),
          const SizedBox(height: 20),

          // Features grid (2 columns)
          _FeatureItem(Icons.receipt_long_outlined, 'Unlimited invoices'),
          _FeatureItem(Icons.auto_awesome_outlined, 'AI prompt to invoice'),
          _FeatureItem(Icons.people_outline_rounded, 'Client management'),
          _FeatureItem(Icons.receipt_outlined, 'Expense tracking'),
          _FeatureItem(Icons.bar_chart_outlined, 'Quarterly BTW overview'),
          _FeatureItem(Icons.calendar_today_outlined, 'Annual financial overview'),
          _FeatureItem(Icons.document_scanner_outlined, 'Receipt scanning'),
          _FeatureItem(Icons.credit_card_outlined, 'iDEAL, card via Mollie'),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _checkingOut ? null : _startCheckout,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _checkingOut
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Start subscription — €12/month',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Cancel anytime · iDEAL, credit card, PayPal',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureItem(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.check_rounded,
              color: AppColors.success,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
