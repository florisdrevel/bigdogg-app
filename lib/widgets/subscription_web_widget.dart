import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';

const String kBigDoggWebUrl = 'https://www.bigdogg.nl';

Future<void> _openWebsite() async {
  final uri = Uri.parse(kBigDoggWebUrl);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Inline card pointing the user to bigdogg.nl for any account/billing action.
/// Carries no pricing, trial, or upgrade language.
class SubscriptionWebCard extends StatelessWidget {
  final bool isNl;
  const SubscriptionWebCard({super.key, required this.isNl});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BigDoggTheme.teal800,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: BigDoggTheme.gold500.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.public_rounded,
                    color: BigDoggTheme.gold500, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isNl
                      ? 'Beheer je abonnement op bigdogg.nl'
                      : 'Manage your subscription at bigdogg.nl',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openWebsite,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(isNl ? 'Openen' : 'Open',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: BigDoggTheme.teal800,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet variant for modal contexts (replaces the old paywall sheets).
class _SubscriptionWebSheet extends StatelessWidget {
  final bool isNl;
  const _SubscriptionWebSheet({required this.isNl});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: BigDoggTheme.teal800.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.public_rounded,
                size: 36, color: BigDoggTheme.teal800),
          ),
          const SizedBox(height: 20),
          Text(
            isNl
                ? 'Beheer je abonnement op bigdogg.nl'
                : 'Manage your subscription at bigdogg.nl',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: BigDoggTheme.teal800,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _openWebsite();
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(isNl ? 'Openen' : 'Open',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'PlusJakartaSans')),
              style: ElevatedButton.styleFrom(
                backgroundColor: BigDoggTheme.teal800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isNl ? 'Sluiten' : 'Close',
                style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

Future<void> showSubscriptionWebSheet(BuildContext context, bool isNl) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _SubscriptionWebSheet(isNl: isNl),
  );
}
