import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Eager imports — on the critical initial-render path ────────────
// Landing (web), login (native), and reset-password (magic-link fallback
// inside errorBuilder, which is synchronous and can't await loadLibrary).
import 'screens/login_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/reset_password_screen.dart';

// ─── Deferred imports — split into separate JS chunks on web ───────
// Each screen is loaded the first time its route fires; subsequent
// visits hit the already-loaded chunk and render synchronously.
import 'screens/dashboard_screen.dart' deferred as dashboard_lib;
import 'screens/register_screen.dart' deferred as register_lib;
import 'screens/client_onboarding_screen.dart' deferred as onboard_lib;
import 'screens/admin_churn_screen.dart' deferred as admin_lib;
import 'screens/payment_success_screen.dart' deferred as paysuccess_lib;
import 'screens/pricing_screen.dart' deferred as pricing_lib;
import 'screens/subscription_portal_screen.dart' deferred as portal_lib;
import 'screens/quote_public_screen.dart' deferred as quote_lib;
import 'screens/transactions_screen.dart' deferred as tx_lib;
import 'screens/accountant_portal_screen.dart' deferred as accountant_lib;

import 'services/push_service.dart';
import 'services/auth_service.dart';
import 'services/local_storage_service.dart';
import 'services/connectivity_service.dart';
import 'theme.dart';
import 'providers/app_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Persistent cache + connectivity awareness. Both must finish before
  // runApp so screens can read cache synchronously on first build and
  // create-actions can check connection state immediately.
  await LocalStorageService.init();
  await ConnectivityService.init();

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

  // On native (Android/iOS) the deferred-import infrastructure still
  // works but every chunk lives in the same APK/IPA, so loadLibrary()
  // resolves synchronously. The deferred wrapper still costs a frame
  // on first hit though, so kick off the dashboard chunk in the
  // background — the post-login navigation then finds it already
  // loaded and renders instantly.
  // ignore: unawaited_futures
  dashboard_lib.loadLibrary();

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

/// Tiny loader shown while a deferred chunk is being fetched. Inline
/// (not a shared widget) so we don't introduce new files — uses the
/// existing BigDogg theme colors directly.
class _DeferredLoader extends StatelessWidget {
  const _DeferredLoader();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      body: Center(
        child: CircularProgressIndicator(
          valueColor:
              AlwaysStoppedAnimation<Color>(BigDoggTheme.teal800),
        ),
      ),
    );
  }
}

/// Wraps a deferred-library load + builder in a FutureBuilder so the
/// route renders a loader until the chunk is in memory.
class _Deferred extends StatelessWidget {
  final Future<void> Function() load;
  final Widget Function() builder;
  const _Deferred({required this.load, required this.builder});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return builder();
        }
        return const _DeferredLoader();
      },
    );
  }
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
      debugPrint('[Auth] cold-start redirect: firing refresh (hasRefresh='
          '$hasRefresh, hasAccess=$hasAccess) → /dashboard');
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
    // errorBuilder is synchronous, so it can only return eagerly-loaded
    // screens. Reset-password is kept eager specifically for this path:
    // Supabase recovery links land here with `type=recovery` in the hash.
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
      path: '/reset-password',
      builder: (context, state) => const ResetPasswordScreen(),
    ),

    // ─── Deferred routes ───────────────────────────────────────────
    GoRoute(
      // Dedicated 3-plan checkout chooser. Opened by the native app's
      // paywall modal in an in-app web view; also linkable from the
      // marketing landing. Reads `?token=` (Supabase access token) so it
      // can call /subscription/checkout without a separate web login.
      path: '/pricing',
      builder: (context, state) {
        _stashPendingSignupEmail(state.uri.queryParameters['email']);
        return _Deferred(
          load: pricing_lib.loadLibrary,
          builder: () => pricing_lib.PricingScreen(),
        );
      },
    ),
    GoRoute(
      // Subscription management. Active monthly/yearly users get
      // redirected straight to Stripe's billing portal; legacy active
      // users without a Stripe customer see a "subscription active —
      // contact support" status page. Reached from Settings →
      // "Manage subscription" in the native app via in-app web view.
      path: '/subscription',
      builder: (context, state) => _Deferred(
        load: portal_lib.loadLibrary,
        builder: () => portal_lib.SubscriptionPortalScreen(),
      ),
    ),
    GoRoute(
      // Stripe Checkout returns here after a successful payment. Shows
      // a green-check "close this window" page; the native app polls
      // status on webview dismiss and surfaces the welcome snackbar.
      path: '/payment-success',
      builder: (context, state) => _Deferred(
        load: paysuccess_lib.loadLibrary,
        builder: () => paysuccess_lib.PaymentSuccessScreen(),
      ),
    ),
    GoRoute(
      // Solo-founder churn dashboard. Auth via ?token=<cron_secret>.
      // Open at: bigdogg.nl/#/admin/churn?token=<secret>&since=2026-01-01
      path: '/admin/churn',
      builder: (context, state) => _Deferred(
        load: admin_lib.loadLibrary,
        builder: () => admin_lib.AdminChurnScreen(),
      ),
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
        return _Deferred(
          load: register_lib.loadLibrary,
          builder: () => register_lib.RegisterScreen(),
        );
      },
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => _Deferred(
        load: dashboard_lib.loadLibrary,
        builder: () => dashboard_lib.DashboardScreen(),
      ),
    ),
    GoRoute(
      path: '/onboard/:token',
      builder: (context, state) {
        final token = state.pathParameters['token'] ?? '';
        return _Deferred(
          load: onboard_lib.loadLibrary,
          builder: () => onboard_lib.ClientOnboardingScreen(token: token),
        );
      },
    ),
    GoRoute(
      path: '/q/:token',
      builder: (context, state) {
        final token = state.pathParameters['token'] ?? '';
        return _Deferred(
          load: quote_lib.loadLibrary,
          builder: () => quote_lib.QuotePublicScreen(token: token),
        );
      },
    ),
    GoRoute(
      path: '/transactions',
      builder: (context, state) {
        final tx = state.uri.queryParameters['tx'];
        return _Deferred(
          load: tx_lib.loadLibrary,
          builder: () => tx_lib.TransactionsScreen(focusTxId: tx),
        );
      },
    ),
    GoRoute(
      path: '/accountant/portal/:token',
      builder: (context, state) {
        final token = state.pathParameters['token'] ?? '';
        return _Deferred(
          load: accountant_lib.loadLibrary,
          builder: () => accountant_lib.AccountantPortalScreen(token: token),
        );
      },
    ),
  ],
);

class BigdoggApp extends StatefulWidget {
  const BigdoggApp({super.key});

  @override
  State<BigdoggApp> createState() => _BigdoggAppState();
}

class _BigdoggAppState extends State<BigdoggApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthService.sessionExpired.addListener(_onSessionExpired);
  }

  @override
  void dispose() {
    AuthService.sessionExpired.removeListener(_onSessionExpired);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onSessionExpired() {
    if (!AuthService.sessionExpired.value) return;
    AuthService.sessionExpired.value = false;
    debugPrint('[Auth] sessionExpired fired → logging out and routing to /login');
    // The session is genuinely gone (refresh token rejected). Clear stale
    // creds + caches and route to login — replacing the old "offline"
    // dead-end that forced a manual log-out/in. Device prefs (theme,
    // language, walkthrough-seen) survive via logout()'s preserve list.
    AuthService.logout().whenComplete(() => _router.go('/login'));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Foregrounding: proactively refresh so a token that expired while
      // backgrounded is renewed before any screen fires a request (and a
      // truly-dead session routes to login via the listener above).
      debugPrint('[Auth] app resumed → firing ensureFreshToken');
      // ignore: unawaited_futures
      AuthService.ensureFreshToken();
    }
  }

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
