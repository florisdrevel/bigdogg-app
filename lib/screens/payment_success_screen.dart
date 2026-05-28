import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';

/// Stripe Checkout return target. The webview-user lands here right
/// after paying. Job is just to confirm visually and prompt the user
/// to close the webview so the native app can refresh status.
class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = GoRouterState.of(context);
    final kind = state.uri.queryParameters['kind'] ?? 'subscription';
    final lang = state.uri.queryParameters['lang'] ?? 'nl';
    final isNl = lang != 'en';

    final isReport = kind == 'report';
    final title = isNl
        ? (isReport ? 'Betaling ontvangen!' : 'Welkom bij BigDogg! 🎉')
        : (isReport ? 'Payment received!' : 'Welcome to BigDogg! 🎉');
    final body = isNl
        ? (isReport
            ? 'Sluit dit venster — je rapport staat klaar in de BigDogg app.'
            : 'Je abonnement is actief. Sluit dit venster om verder te gaan in de app.')
        : (isReport
            ? 'Close this window — your report is ready in the BigDogg app.'
            : 'Your subscription is active. Close this window to continue in the app.');

    return Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: BigDoggTheme.lightSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: BigDoggTheme.lightBorder),
                  boxShadow: [
                    BoxShadow(
                      color: BigDoggTheme.teal800.withOpacity(0.08),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(
                        color: BigDoggTheme.success,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 52),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: BigDoggTheme.teal800,
                        letterSpacing: -0.6,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: BigDoggTheme.lightTextSecondary,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: BigDoggTheme.gold500.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: BigDoggTheme.gold500.withOpacity(0.3)),
                      ),
                      child: Text(
                        isNl
                            ? 'Tik op de terug-knop of sluit het venster'
                            : 'Tap back or close this window',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: BigDoggTheme.gold600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
