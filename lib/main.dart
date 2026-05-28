import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/client_onboarding_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/payment_success_screen.dart';
import 'screens/pricing_screen.dart';
import 'screens/subscription_portal_screen.dart';
import 'screens/quote_public_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/accountant_portal_screen.dart';
import 'services/push_service.dart';
import 'services/auth_service.dart';
import 'theme.dart';
import 'providers/app_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://gjmjdzzhvniufcryuott.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqbWpkenpodm5pdWZjcnl1b3R0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU2NjE1NDYsImV4cCI6MjA5MTIzNzU0Nn0.0i9o_-IpaFTQtAyU12ObPYSCa071MRbZ0rpJLvBUThA',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  // Best-effort Firebase init for FCM push. Silently no-ops on web
  // and on native builds where google-services.json is absent.
  await PushService.initFirebase();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const BigdoggApp(),
    ),
  );
}

void _stashPendingSignupEmail(String? email) {
  final trimmed = email?.trim() ?? '';
  if (trimmed.isEmpty) return;
  // Fire-and-forget; the register screen reads this on init.
  SharedPreferences.getInstance().then((prefs) {
    prefs.setString('pending_signup_email', trimmed);
  });
}

final _router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    // Only intercept the bare landing route — login, register, password
    // reset, public quote, onboard etc. must NOT be hijacked.
    if (state.uri.path != '/') return null;

    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_me') ?? false;
    // The refresh_token is the durable credential — it long-outlives the
    // 1-hour access token. Decide "still logged in" on its presence (plus
    // remember-me), not on the short-lived access token, so a user who
    // hasn't opened the app in hours/days still lands on the dashboard
    // instead of the login screen.
    final hasRefresh = (prefs.getString('refresh_token') ?? '').isNotEmpty;
    final hasAccess = (prefs.getString('access_token') ?? '').isNotEmpty;
    if (remember && (hasRefresh || hasAccess)) {
      // Kick a refresh so the dashboard opens with a valid access token
      // even if the cached one expired while the app was closed.
      // Fire-and-forget; refreshTokenIfNeeded no-ops when still fresh.
      // ignore: unawaited_futures
      AuthService.refreshTokenIfNeeded();
      return '/dashboard';
    }

    // The landing page is a marketing page for the website. Native
    // (Android / iOS) builds skip straight to the login screen.
    if (!kIsWeb) return '/login';
    return null;
  },
  errorBuilder: (context, state) {
    final location = state.uri.toString();
    if (location.contains('type=recovery')) {
      return const ResetPasswordScreen();
    }
    if (location.contains('type=signup') || location.contains('type=email')) {
      return const LoginScreen();
    }
    return const LandingScreen();
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const LandingScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      // Dedicated 3-plan checkout chooser. Opened by the native app's
      // paywall modal in an in-app web view; also linkable from the
      // marketing landing. Reads `?token=` (Supabase access token) so it
      // can call /subscription/checkout without a separate web login.
      path: '/pricing',
      builder: (context, state) {
        _stashPendingSignupEmail(state.uri.queryParameters['email']);
        return const PricingScreen();
      },
    ),
    GoRoute(
      // Subscription management. Active monthly/yearly users get
      // redirected straight to Stripe's billing portal; legacy active
      // users without a Stripe customer see a "subscription active —
      // contact support" status page. Reached from Settings →
      // "Manage subscription" in the native app via in-app web view.
      path: '/subscription',
      builder: (context, state) => const SubscriptionPortalScreen(),
    ),
    GoRoute(
      // Stripe Checkout returns here after a successful payment. Shows
      // a green-check "close this window" page; the native app polls
      // status on webview dismiss and surfaces the welcome snackbar.
      path: '/payment-success',
      builder: (context, state) => const PaymentSuccessScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) {
        // Capture ?ref=XXXXX so it survives the email-confirm round trip.
        final ref = state.uri.queryParameters['ref'];
        if (ref != null && ref.trim().isNotEmpty) {
          // Fire-and-forget; don't block the route build on disk IO.
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString('pending_referral_code', ref.trim());
          });
        }
        // Native app opens /pricing?email=… first which stashes the
        // address; users who hit /register directly with an email param
        // get the same prefill.
        _stashPendingSignupEmail(state.uri.queryParameters['email']);
        return const RegisterScreen();
      },
    ),
    GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
    GoRoute(path: '/reset-password', builder: (context, state) => const ResetPasswordScreen()),
    GoRoute(
      path: '/onboard/:token',
      builder: (context, state) {
        final token = state.pathParameters['token'] ?? '';
        return ClientOnboardingScreen(token: token);
      },
    ),
    GoRoute(
      path: '/q/:token',
      builder: (context, state) {
        final token = state.pathParameters['token'] ?? '';
        return QuotePublicScreen(token: token);
      },
    ),
    GoRoute(
      path: '/transactions',
      builder: (context, state) {
        final tx = state.uri.queryParameters['tx'];
        return TransactionsScreen(focusTxId: tx);
      },
    ),
    GoRoute(
      path: '/accountant/portal/:token',
      builder: (context, state) {
        final token = state.pathParameters['token'] ?? '';
        return AccountantPortalScreen(token: token);
      },
    ),
  ],
);

class BigdoggApp extends StatelessWidget {
  const BigdoggApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    return MaterialApp.router(
      title: 'BigDogg.',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: BigDoggTheme.light(),
      darkTheme: BigDoggTheme.dark(),
      themeMode: appProvider.themeMode,
    );
  }
}