import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../services/subscription_service.dart';
import '../theme.dart';

// ─── Web URLs ────────────────────────────────────────────────────
const String kBigDoggWebOrigin = 'https://www.bigdogg.nl';
const String _pricingPath = '/#/pricing';
const String _portalPath = '/#/subscription';

/// Build a bigdogg.nl URL with the user's email pre-filled as a query
/// parameter so the web signup form lands ready-to-submit.
Future<Uri> buildPricingUrl() => _buildWebUrl(_pricingPath);

/// Build the Stripe customer-portal URL on bigdogg.nl (for users with an
/// already-active subscription who want to manage billing).
Future<Uri> buildPortalUrl() => _buildWebUrl(_portalPath);

Future<Uri> _buildWebUrl(String pathWithHash) async {
  final prefs = await SharedPreferences.getInstance();
  final email = (prefs.getString('user_email') ?? '').trim();
  final query =
      email.isEmpty ? '' : '?email=${Uri.encodeQueryComponent(email)}';
  return Uri.parse('$kBigDoggWebOrigin$pathWithHash$query');
}

/// Open [url] inside the in-app web view (Chrome Custom Tabs on Android,
/// SFSafariViewController on iOS) so the user never fully leaves the app.
/// Falls back to the external browser when the in-app view is unavailable
/// (e.g. on web or older devices).
Future<void> _openInAppWebView(Uri url) async {
  try {
    final ok = await launchUrl(url, mode: LaunchMode.inAppWebView);
    if (!ok) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  } catch (_) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

// ─── Public entry points ─────────────────────────────────────────

/// Shows the polished paywall modal — used by feature-gate triggers
/// (read-only FAB taps, send-invoice attempts). Respects the per-session
/// "already dismissed once" flag so we don't badger the user.
Future<void> maybeShowPaywallModal(BuildContext context, bool isNl) async {
  final app = context.read<AppProvider>();
  if (app.paywallShownThisSession) return;
  app.markPaywallShownThisSession();
  await _showPaywallModal(context, isNl);
}

/// Shows the paywall modal unconditionally — used by explicit user
/// actions (banner tap, settings "Start subscription" row) where
/// suppressing the modal would feel broken.
Future<void> showPaywallModal(BuildContext context, bool isNl) {
  return _showPaywallModal(context, isNl);
}

/// Open the Stripe customer-portal page in the in-app web view. Used by
/// the Settings "Manage subscription" row for already-active users.
Future<void> openManageSubscription(BuildContext context, bool isNl) async {
  final url = await buildPortalUrl();
  await _launchAndRefresh(context, url, isNl);
}

/// Legacy shim — old call sites still use this name. Redirects to the
/// session-deduped paywall flow.
Future<void> showSubscriptionWebSheet(BuildContext context, bool isNl) {
  return maybeShowPaywallModal(context, isNl);
}

// ─── Internals ────────────────────────────────────────────────────

Future<void> _showPaywallModal(BuildContext outerCtx, bool isNl) async {
  final app = outerCtx.read<AppProvider>();
  app.setPaywallVisible(true);
  await showModalBottomSheet<void>(
    context: outerCtx,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _PaywallModal(outerCtx: outerCtx, isNl: isNl),
  );
  app.setPaywallVisible(false);
}

/// After the in-app web view closes, give Stripe's webhook a moment to
/// flip the subscription row, then refetch status. If the user is now
/// active, push that into AppProvider and surface a brief snackbar.
Future<void> _launchAndRefresh(
    BuildContext outerCtx, Uri url, bool isNl) async {
  final wasActive =
      outerCtx.read<AppProvider>().isSubscriptionActive;
  await _openInAppWebView(url);
  // Stripe's checkout.session.completed webhook usually lands within a
  // second — wait briefly before re-checking so we don't race ahead of
  // the backend writing the new row.
  await Future.delayed(const Duration(milliseconds: 1500));
  final result = await SubscriptionService.getStatus();
  if (result['success'] != true || result['subscription'] is! Map) return;
  final sub = result['subscription'] as Map;
  final status = (sub['status'] ?? '').toString();
  final isActive = sub['is_active'] == true;

  if (!outerCtx.mounted) return;
  outerCtx
      .read<AppProvider>()
      .setSubscription(status: status, isActive: isActive);

  if (!wasActive && isActive) {
    // Newly activated — celebrate.
    ScaffoldMessenger.of(outerCtx).showSnackBar(
      SnackBar(
        backgroundColor: BigDoggTheme.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: Text(
          isNl ? 'Welkom bij BigDogg! 🎉' : 'Welcome to BigDogg! 🎉',
          style: const TextStyle(
              fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
    );
  }
}

class _PaywallModal extends StatelessWidget {
  final BuildContext outerCtx;
  final bool isNl;
  const _PaywallModal({required this.outerCtx, required this.isNl});

  Future<void> _onActivatePressed(BuildContext ctx) async {
    // Pop the sheet first so the in-app web view comes up over the
    // dashboard, not over a half-open modal.
    Navigator.of(ctx).pop();
    final url = await buildPricingUrl();
    await _launchAndRefresh(outerCtx, url, isNl);
  }

  @override
  Widget build(BuildContext context) {
    final bullets = isNl
        ? const [
            '✓ Facturen versturen & bijhouden',
            '✓ BTW aangifte in één klik',
            '✓ AI-gedreven boekhouding',
          ]
        : const [
            '✓ Send & track invoices',
            '✓ VAT return in one click',
            '✓ AI-powered accounting',
          ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grab handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 22),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Logo badge
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  BigDoggTheme.teal800,
                  BigDoggTheme.teal700,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: BigDoggTheme.teal800.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Image.asset(
              'assets/images/logo.png',
              width: 56,
              height: 56,
            ),
          ),
          const SizedBox(height: 20),

          Text(
            isNl ? 'Activeer BigDogg' : 'Activate BigDogg',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: BigDoggTheme.teal800,
              fontFamily: 'PlusJakartaSans',
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 18),

          // Value props
          ...bullets.map((b) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        b,
                        style: const TextStyle(
                          fontSize: 15,
                          color: BigDoggTheme.lightTextPrimary,
                          fontFamily: 'PlusJakartaSans',
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 18),

          // Price line
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: BigDoggTheme.gold500.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BigDoggTheme.gold500.withOpacity(0.3)),
            ),
            child: Text(
              isNl
                  ? '€9,99 / maand — 30 dagen gratis proberen'
                  : '€9.99 / month — 30-day free trial',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: BigDoggTheme.gold600,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Primary CTA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _onActivatePressed(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: BigDoggTheme.teal800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: Text(
                isNl ? 'Abonnement starten →' : 'Start subscription →',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Dismiss
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              isNl ? 'Later' : 'Maybe later',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline status/management card kept for the Settings + standalone
/// subscription screens (was previously the only public surface). Tapping
/// the CTA now also runs through the in-app web view + status refresh.
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
              onPressed: () => openManageSubscription(context, isNl),
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
