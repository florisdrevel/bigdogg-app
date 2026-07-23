import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/app_provider.dart';
import '../services/api_cache.dart';
import '../services/auth_service.dart';
import '../services/notifications_service.dart';
import '../services/push_service.dart';
import '../services/offline_queue.dart';
import '../config/feature_flags.dart';
import '../services/subscription_service.dart';
import '../widgets/subscription_web_widget.dart';
import 'products_screen.dart';
import 'clients_screen.dart';
import 'invoices_screen.dart';
import 'expenses_screen.dart';
import 'overview_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'projects_screen.dart';
import 'walkthrough_screen.dart';

const String _bankReturnQuery = 'bank';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _walkthroughStarted = false;
  bool _welcomeShown = false;
  bool _bankReturnHandled = false;

  // Notifications bell state — unread count is polled every 60 seconds
  // and refreshed manually after the sheet is closed.
  int _unreadCount = 0;
  int _pendingOffline = 0;
  Timer? _notifTimer;

  // Keep the Supabase access token fresh. Default lifetime is ~1 hour;
  // we refresh every 30 minutes from anywhere the app stays open so
  // tokens never silently expire on the user.
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshUnreadCount();
    // Poll every 15 seconds so the bell badge feels live while the app
    // is in the foreground. Real OS-level pings when the phone is locked
    // require FCM (separate session).
    _notifTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _refreshUnreadCount();
      _refreshPendingCount();
    });
    _refreshPendingCount();
    // Refresh the access token immediately on mount — this catches the
    // case where the app was backgrounded for a while and the cached
    // access token has already expired before the user got back to it.
    // refreshTokenIfNeeded() skips the network call when the JWT still
    // has >5 min left, which avoids rotating the refresh_token on every
    // app open and prevents the race that used to log users out.
    AuthService.refreshTokenIfNeeded();
    _refreshTimer = Timer.periodic(const Duration(minutes: 20),
        (_) => AuthService.refreshTokenIfNeeded());
    _refreshSubscriptionStatus();
    // Make sure FCM is registered for this device. Idempotent: the
    // backend upserts on (user_id, fcm_token), so calling this at
    // every mount is fine. Also handles persistent-login users who
    // skip the login screen entirely.
    // ignore: unawaited_futures
    PushService.registerWithBackend();
    PushService.listen(onMessageOpened: (data) {
      // Bank-link notifications jump to /transactions; everything
      // else just opens the dashboard which the user is already on.
      final type = (data['type'] ?? '');
      if (type == 'bank_auto_link' || type == 'bank_suggest') {
        final txId = data['tx_id'] ?? '';
        final url = txId.isEmpty ? '/transactions' : '/transactions?tx=$txId';
        if (mounted) context.push(url);
      }
    });
    // Try to drain any pending offline writes — most app sessions
    // start online so this usually no-ops, but if the user created
    // anything during a network blip, this is when it gets sent.
    // ignore: unawaited_futures
    _drainOfflineQueue();
// Show a snackbar when Tink redirects back to /dashboard?bank=success
    // (or ?bank_error=...). Done once per session — flag prevents repeats
    // when the user navigates between tabs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _bankReturnHandled) return;
      final uri = GoRouterState.of(context).uri;
      final bank = uri.queryParameters[_bankReturnQuery];
      final bankError = uri.queryParameters['bank_error'];
      if (bank == 'success' || bankError != null) {
        _bankReturnHandled = true;
        final isNl = context.read<AppProvider>().language == 'nl';
        final ok = bank == 'success';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? (isNl ? 'Bankrekening gekoppeld' : 'Bank account connected')
              : (isNl ? 'Koppeling mislukt: ${bankError ?? ''}' : 'Connection failed: ${bankError ?? ''}')),
          backgroundColor:
              ok ? BigDoggTheme.success : BigDoggTheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ));
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the user brings the app back from the background, refresh
    // the access token + bell count immediately. Avoids the "I just
    // opened the app and there's no data" experience when the access
    // token has silently expired during the suspension.
    if (state == AppLifecycleState.resumed) {
      AuthService.refreshTokenIfNeeded();
      _refreshUnreadCount();
      // ignore: unawaited_futures
      _drainOfflineQueue();
      _refreshSubscriptionStatus();
    }
  }

  /// Pull the current subscription state from the backend and push it
  /// into AppProvider so screens can gate creation actions and decide
  /// whether to show the dashboard banner.
  Future<void> _refreshSubscriptionStatus() async {
    final result = await SubscriptionService.getStatus();
    if (!mounted) return;
    if (result['success'] == true && result['subscription'] is Map) {
      final sub = result['subscription'] as Map;
      context.read<AppProvider>().setSubscription(
            status: (sub['status'] ?? '').toString(),
            isActive: sub['is_active'] == true,
            daysLeft: (sub['days_left'] as num?)?.toInt(),
          );
    }
  }

  Future<void> _drainOfflineQueue() async {
    final n = await OfflineQueue.drain();
    final remaining = await OfflineQueue.count();
    if (!mounted) return;
    if (_pendingOffline != remaining) {
      setState(() => _pendingOffline = remaining);
    }
    if (n <= 0) return;
    // Items did go through — the data they touch may now be on the
    // server, so kick a refresh just like a notification would.
    await ApiCache.clearAll();
    if (!mounted) return;
    context.read<AppProvider>().bumpDataVersion();
    final isNl = context.read<AppProvider>().language == 'nl';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: BigDoggTheme.success,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      content: Text(isNl
          ? '$n offline ${n == 1 ? 'wijziging' : 'wijzigingen'} verstuurd'
          : '$n offline ${n == 1 ? 'change' : 'changes'} synced'),
    ));
  }

  Future<void> _refreshPendingCount() async {
    final n = await OfflineQueue.count();
    if (!mounted) return;
    if (_pendingOffline != n) setState(() => _pendingOffline = n);
  }

Future<void> _refreshUnreadCount() async {
    final n = await NotificationsService.unreadCount();
    if (!mounted) return;
    final increased = n > _unreadCount;
    if (_unreadCount != n) {
      setState(() => _unreadCount = n);
    }
    // Notify the user when something new just landed: subtle haptic
    // tap + snackbar with the latest title, AND bump the global
    // dataVersion so screens with cached lists refresh themselves.
    if (increased) {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
      // Invalidate cached reads so the next list-load comes from the network.
      await ApiCache.clearAll();
      // Tell every screen that listens to AppProvider to reload.
      if (mounted) context.read<AppProvider>().bumpDataVersion();
      final list = await NotificationsService.list(limit: 1);
      if (!mounted || list.isEmpty) return;
      final latest = list.first as Map;
      // Make sure only one toast is on screen at a time — if a
      // previous one was still hanging around (Material queues them),
      // remove it so the new one appears immediately and doesn't tail
      // an old toast for an extra few seconds.
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: BigDoggTheme.teal800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          content: Row(
            children: [
              const Icon(Icons.notifications_active_rounded,
                  color: BigDoggTheme.gold500, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  latest['title']?.toString() ?? 'Nieuwe melding',
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Bekijk',
            textColor: BigDoggTheme.gold500,
            onPressed: () {
              // Tapping action just opens the bell sheet — same UX as
              // tapping the bell icon directly.
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) {
                  final isNl = context.read<AppProvider>().language == 'nl';
                  return _NotificationsSheet(isNl: isNl);
                },
              ).then((_) => _refreshUnreadCount());
            },
          ),
        ),
      );
    }
  }

  void _completeWalkthrough() {
    context.read<AppProvider>().markWalkthroughSeen();
    // Return to invoices after tour completes
    setState(() {
      _currentIndex = 0;
      _welcomeShown = false;
    });
  }

  void _showWelcomeDialog(bool isNl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: BigDoggTheme.lightSurface,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      BigDoggTheme.teal800.withOpacity(0.08),
                      BigDoggTheme.gold500.withOpacity(0.14),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 64,
                  height: 64,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                isNl ? 'Welkom bij BigDogg!' : 'Welcome to BigDogg!',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: BigDoggTheme.teal800,
                  letterSpacing: -0.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isNl
                    ? 'Wat leuk dat je er bent! We nemen je nu mee op een korte rondleiding door alle functies — zo ben je binnen een paar minuten klaar om aan de slag te gaan.'
                    : 'Glad you\'re here! We\'ll take you on a quick tour of all the features — so you\'re ready to get started in just a few minutes.',
                style: const TextStyle(
                  fontSize: 14.5,
                  color: BigDoggTheme.lightTextSecondary,
                  height: 1.55,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _completeWalkthrough();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: BigDoggTheme.lightTextSecondary,
                      ),
                      child: Text(isNl ? 'Overslaan' : 'Skip'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        if (mounted) {
                          setState(() => _welcomeShown = true);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BigDoggTheme.teal800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        isNl ? 'Start rondleiding →' : 'Start the tour →',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Profile tab index — shifts by 1 when projects enabled
  int _profileTabIndex(bool projectsEnabled) => projectsEnabled ? 6 : 5;

  List<Widget> _getScreens(bool projectsEnabled) {
    final base = [
      const InvoicesScreen(),
      const ClientsScreen(),
      const ProductsScreen(),
      const ExpensesScreen(),
      const OverviewScreen(),
      const ProfileScreen(),
      const SettingsScreen(),
    ];
    if (projectsEnabled) base.insert(4, const ProjectsScreen());
    return base;
  }

  List<String> _getTitlesEn(bool projectsEnabled) {
    final base = ['Invoices', 'Clients', 'Products', 'Expenses', 'Overview', 'Profile', 'Settings'];
    if (projectsEnabled) base.insert(4, 'Projects');
    return base;
  }

  List<String> _getTitlesNl(bool projectsEnabled) {
    final base = ['Facturen', 'Klanten', 'Producten', 'Kosten', 'Overzicht', 'Profiel', 'Instellingen'];
    if (projectsEnabled) base.insert(4, 'Projecten');
    return base;
  }

  List<BottomNavigationBarItem> _getNavItems(bool isNl, bool projectsEnabled) {
    final base = [
      BottomNavigationBarItem(icon: const Icon(Icons.receipt_long_outlined), label: isNl ? 'Facturen' : 'Invoices'),
      BottomNavigationBarItem(icon: const Icon(Icons.people_outline), label: isNl ? 'Klanten' : 'Clients'),
      BottomNavigationBarItem(icon: const Icon(Icons.inventory_2_outlined), label: isNl ? 'Producten' : 'Products'),
      BottomNavigationBarItem(icon: const Icon(Icons.receipt_outlined), label: isNl ? 'Kosten' : 'Expenses'),
      BottomNavigationBarItem(icon: const Icon(Icons.bar_chart_outlined), label: isNl ? 'Overzicht' : 'Overview'),
      BottomNavigationBarItem(icon: const Icon(Icons.person_outline), label: isNl ? 'Profiel' : 'Profile'),
      BottomNavigationBarItem(icon: const Icon(Icons.settings_outlined), label: isNl ? 'Instellingen' : 'Settings'),
    ];
    if (projectsEnabled) base.insert(4, BottomNavigationBarItem(icon: const Icon(Icons.folder_outlined), label: isNl ? 'Projecten' : 'Projects'));
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final isNl = appProvider.language == 'nl';
    final projectsEnabled = appProvider.projectsEnabled;

    // Wait until SharedPreferences have loaded before deciding on walkthrough.
    // Default is hasSeenWalkthrough=true so nothing shows until prefs confirm otherwise.
    final showWalkthrough = appProvider.prefsLoaded && !appProvider.hasSeenWalkthrough;

    // When walkthrough becomes active for the first time this session,
    // jump to the Profile tab so step 1 makes sense, then show the welcome dialog.
    if (showWalkthrough && !_walkthroughStarted) {
      _walkthroughStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _currentIndex = _profileTabIndex(projectsEnabled));
          _showWelcomeDialog(isNl);
        }
      });
    }
    // Reset flags when walkthrough is dismissed so it can re-trigger on restart
    if (!showWalkthrough && _walkthroughStarted) {
      _walkthroughStarted = false;
      _welcomeShown = false;
    }

    // Consume any pending tab-navigation request (e.g. the user just enabled
    // Projects from Settings — jump them to the new Projects tab).
    final pendingTab = appProvider.navigateToTab;
    if (pendingTab != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        appProvider.consumeNavigateToTab();
        setState(() => _currentIndex = pendingTab);
      });
    }

    final screens = _getScreens(projectsEnabled);
    final titles = isNl ? _getTitlesNl(projectsEnabled) : _getTitlesEn(projectsEnabled);
    final safeIndex = _currentIndex.clamp(0, screens.length - 1);

    final scaffold = Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      appBar: AppBar(
        backgroundColor: BigDoggTheme.lightSurface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: BigDoggTheme.lightBorder, height: 1),
        ),
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', width: 56, height: 56),
            const SizedBox(width: 10),
            Text(
              titles[safeIndex],
              style: const TextStyle(
                color: BigDoggTheme.lightTextPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 17,
              ),
            ),
          ],
        ),
        actions: [
          AnimatedBuilder(
            animation: OfflineState.instance,
            builder: (context, _) {
              if (!OfflineState.instance.offline) {
                return const SizedBox.shrink();
              }
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: BigDoggTheme.warningBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: BigDoggTheme.warning.withOpacity(0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined,
                        size: 12, color: Color(0xFF92400E)),
                    const SizedBox(width: 4),
                    Text(
                      isNl ? 'Offline' : 'Offline',
                      style: const TextStyle(
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          GestureDetector(
            onTap: () => appProvider.setLanguage(isNl ? 'en' : 'nl'),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: BigDoggTheme.gold500.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: BigDoggTheme.gold500.withOpacity(0.4)),
              ),
              child: Text(
                isNl ? 'EN' : 'NL',
                style: const TextStyle(
                  color: BigDoggTheme.gold600,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          if (_pendingOffline > 0)
            _OfflineQueueChip(
              count: _pendingOffline,
              isNl: isNl,
              onTap: _drainOfflineQueue,
            ),
          _NotificationsBell(
            unreadCount: _unreadCount,
            isNl: isNl,
            onChanged: _refreshUnreadCount,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: BigDoggTheme.lightTextSecondary),
            onPressed: () async {
              // Unregister this device's push token first — the
              // access_token is still around so the backend call works.
              await PushService.unregisterFromBackend();
              await AuthService.logout();
              if (!mounted) return;
              context.go('/login');
            },
            tooltip: isNl ? 'Uitloggen' : 'Log out',
          ),
        ],
      ),
      body: Column(
        children: [
          // Mutually exclusive banner stack: active-trial warning fires
          // for trial users at <= 7 days left; trial-ended takes over
          // once read-only mode is on. Both auto-hide while the paywall
          // modal is up (see AppProvider.paywallVisible).
          if (appProvider.showTrialWarningBanner)
            _TrialWarningBanner(
              isNl: isNl,
              daysLeft: appProvider.subscriptionDaysLeft ?? 0,
              onDismiss: () => appProvider.dismissTrialWarningBanner(),
              onReferFriends: () {
                // Jump to Settings (its tab index depends on whether
                // Projects is enabled) and scroll to the referral
                // section once that screen builds.
                final settingsIdx =
                    appProvider.projectsEnabled ? 7 : 6;
                appProvider.requestNavigateToTab(settingsIdx);
                appProvider.requestScrollToReferral();
              },
            )
          else if (appProvider.showTrialBanner)
            _TrialEndedBanner(
              isNl: isNl,
              onDismiss: () => appProvider.dismissTrialBanner(),
            ),
          Expanded(child: screens[safeIndex]),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: BigDoggTheme.teal800,
          border: const Border(top: BorderSide(color: BigDoggTheme.teal900, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: safeIndex,
          onTap: (index) {
            if (!showWalkthrough) setState(() => _currentIndex = index);
          },
          backgroundColor: Colors.transparent,
          selectedItemColor: BigDoggTheme.gold500,
          unselectedItemColor: BigDoggTheme.teal400,
          selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 11, fontFamily: 'PlusJakartaSans'),
          unselectedLabelStyle: const TextStyle(
              fontSize: 11, fontFamily: 'PlusJakartaSans'),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: _getNavItems(isNl, projectsEnabled),
        ),
      ),
    );

    return WalkthroughOverlay(
      isNl: isNl,
      active: showWalkthrough && _welcomeShown,
      onComplete: _completeWalkthrough,
      onTabChange: (idx) => setState(() => _currentIndex = idx),
      currentTabIndex: safeIndex,
      projectsEnabled: projectsEnabled,
      quotesEnabled: appProvider.quotesEnabled,
      child: scaffold,
    );
  }
}


// ─── Trial-warning banner (active trial, <= 7 days left) ────────
/// Two visual tiers driven by daysLeft:
///   - daysLeft <= 3: red, urgency copy
///   - daysLeft <= 7: amber, friendly nudge
///
/// On iOS (reader-mode) we drop the Subscribe CTA — only Refer-friends
/// remains (referrals aren't a payment flow, so they're App Store-safe).
class _TrialWarningBanner extends StatelessWidget {
  final bool isNl;
  final int daysLeft;
  final VoidCallback onDismiss;
  final VoidCallback onReferFriends;

  const _TrialWarningBanner({
    required this.isNl,
    required this.daysLeft,
    required this.onDismiss,
    required this.onReferFriends,
  });

  @override
  Widget build(BuildContext context) {
    final urgent = daysLeft <= 3;
    final bg = urgent ? const Color(0xFFB91C1C) : const Color(0xFFD97706);

    final fullCopyNl = urgent
        ? 'Nog $daysLeft dagen! Daarna worden functies geblokkeerd · Start je abonnement of verwijs vrienden'
        : 'Nog $daysLeft dagen gratis · Verwijs 2 vrienden voor een gratis maand · Abonneer op bigdogg.nl';
    final fullCopyEn = urgent
        ? '$daysLeft days left! Features will be blocked after this · Start your subscription or refer friends'
        : '$daysLeft days left on trial · Refer 2 friends for a free month · Subscribe at bigdogg.nl';
    final readerCopyNl = urgent
        ? 'Nog $daysLeft dagen · Verwijs 2 vrienden voor een gratis maand'
        : 'Nog $daysLeft dagen gratis · Verwijs 2 vrienden voor een gratis maand';
    final readerCopyEn = urgent
        ? '$daysLeft days left · Refer 2 friends for a free month'
        : '$daysLeft days left on trial · Refer 2 friends for a free month';

    final copy = kIsReaderMode
        ? (isNl ? readerCopyNl : readerCopyEn)
        : (isNl ? fullCopyNl : fullCopyEn);

    return Material(
      color: bg,
      child: SafeArea(
        bottom: false,
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    urgent
                        ? Icons.error_outline_rounded
                        : Icons.access_time_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      copy,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: isNl ? 'Sluiten' : 'Dismiss',
                    icon: const Icon(Icons.close,
                        color: Colors.white70, size: 16),
                    visualDensity: VisualDensity.compact,
                    onPressed: onDismiss,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (!kIsReaderMode) ...[
                    Expanded(
                      child: _bannerButton(
                        label: isNl ? 'Abonneren' : 'Subscribe',
                        filled: true,
                        accent: bg,
                        onTap: () => showPaywallModal(context, isNl),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: _bannerButton(
                      label:
                          isNl ? 'Vrienden uitnodigen' : 'Refer friends',
                      filled: kIsReaderMode,
                      accent: bg,
                      onTap: onReferFriends,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bannerButton({
    required String label,
    required bool filled,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: filled ? Colors.white : Colors.white70,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? accent : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}


// ─── Trial-ended banner ──────────────────────────────────────────
/// Slim, full-width tappable banner. Whole row launches the paywall
/// modal so the conversion path is one tap away. The close button
/// dismisses for the session (banner only — modal can still re-open
/// via FABs or settings).
class _TrialEndedBanner extends StatelessWidget {
  final bool isNl;
  final VoidCallback onDismiss;

  const _TrialEndedBanner({required this.isNl, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    // iOS / reader-mode: neutral copy, no price, no Subscribe-like
    // verbiage. Web / Android: conversion-focused.
    final label = kIsReaderMode
        ? (isNl
            ? 'Beheer je account op bigdogg.nl'
            : 'Manage your account at bigdogg.nl')
        : (isNl
            ? 'Proefperiode afgelopen · Abonneer op bigdogg.nl · vanaf €9,99/maand'
            : 'Trial ended · Subscribe at bigdogg.nl · from €9.99/month');
    return Material(
      color: BigDoggTheme.teal800,
      child: SafeArea(
        bottom: false,
        top: false,
        child: InkWell(
          onTap: () => showPaywallModal(context, isNl),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            child: Row(
              children: [
                Icon(
                  kIsReaderMode
                      ? Icons.public_rounded
                      : Icons.workspace_premium_rounded,
                  color: BigDoggTheme.gold500,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.white70, size: 18),
                IconButton(
                  tooltip: isNl ? 'Sluiten' : 'Dismiss',
                  icon: const Icon(Icons.close,
                      color: Colors.white60, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: onDismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ─── Pending-offline-writes chip ─────────────────────────────────
class _OfflineQueueChip extends StatelessWidget {
  final int count;
  final bool isNl;
  final VoidCallback onTap;

  const _OfflineQueueChip({
    required this.count,
    required this.isNl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isNl
          ? '$count offline wijziging${count == 1 ? '' : 'en'} wachten op verzenden — tik om opnieuw te proberen'
          : '$count offline change${count == 1 ? '' : 's'} pending — tap to retry',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined,
                size: 18, color: BigDoggTheme.warning),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: BigDoggTheme.warning,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}


// ─── Notifications bell + sheet ──────────────────────────────────
class _NotificationsBell extends StatelessWidget {
  final int unreadCount;
  final bool isNl;
  final VoidCallback onChanged;

  const _NotificationsBell({
    required this.unreadCount,
    required this.isNl,
    required this.onChanged,
  });

  Future<void> _open(BuildContext context) async {
    // Pulling up the notifications sheet implicitly acknowledges the
    // toast snackbar — kill it so it does not linger over the sheet.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotificationsSheet(isNl: isNl),
    );
    // Refresh badge after the sheet is closed; the sheet may have
    // marked items as read.
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: isNl ? 'Meldingen' : 'Notifications',
          icon: const Icon(Icons.notifications_none_rounded,
              color: BigDoggTheme.lightTextSecondary),
          onPressed: () => _open(context),
        ),
        if (unreadCount > 0)
          Positioned(
            top: 8,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: BigDoggTheme.error,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: BigDoggTheme.lightSurface, width: 1.5),
              ),
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}


class _NotificationsSheet extends StatefulWidget {
  final bool isNl;
  const _NotificationsSheet({required this.isNl});

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Paint instantly from the last-fetched list; the refresh lands silently.
    final cached = NotificationsService.peek();
    if (cached != null) {
      _items = cached;
      _loading = false;
    }
    _load();
  }

  Future<void> _load() async {
    final list = await NotificationsService.list(limit: 50);
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _markAllRead() async {
    await NotificationsService.markAllRead();
    if (!mounted) return;
    setState(() {
      _items = _items.map((n) {
        final m = Map<String, dynamic>.from(n as Map);
        m['read_at'] ??= DateTime.now().toUtc().toIso8601String();
        return m;
      }).toList();
    });
  }

  Future<void> _onTap(Map<String, dynamic> item) async {
    if (item['read_at'] == null) {
      await NotificationsService.markRead(item['id'].toString());
      if (!mounted) return;
      setState(() {
        item['read_at'] = DateTime.now().toUtc().toIso8601String();
      });
    }
    // Deep-link routing per notification type. Bank links go to the
    // Transactions screen (with tx_id deep-link if known); invoice /
    // quote / client notifications switch the dashboard tab to where
    // the user can act on them.
    final type = item['type']?.toString() ?? '';
    final data = (item['data'] as Map?) ?? const {};
    final appProvider = context.read<AppProvider>();

    void closeAndJump(int tab, {int? invoicesSub}) {
      Navigator.of(context).pop();
      Future.microtask(() {
        if (!mounted) return;
        if (invoicesSub != null) appProvider.setInvoicesSubTab(invoicesSub);
        appProvider.requestNavigateToTab(tab);
      });
    }

    if (type == 'bank_auto_link' || type == 'bank_suggest') {
      if (!mounted) return;
      final txId = data['tx_id']?.toString() ?? '';
      final url = txId.isEmpty ? '/transactions' : '/transactions?tx=$txId';
      Navigator.of(context).pop();
      Future.microtask(() {
        if (!mounted) return;
        context.push(url);
      });
    } else if (type == 'invoice_paid') {
      // Invoices tab, Facturen sub-tab.
      closeAndJump(0, invoicesSub: 0);
    } else if (type == 'quote_accepted' || type == 'quote_declined') {
      // Invoices tab, Offertes sub-tab.
      closeAndJump(0, invoicesSub: 1);
    } else if (type == 'client_onboarded') {
      // Clients tab.
      closeAndJump(1);
    }
  }

  Future<void> _delete(String id) async {
    await NotificationsService.deleteNotification(id);
    if (!mounted) return;
    setState(() => _items.removeWhere((n) => n['id'].toString() == id));
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'invoice_paid':     return Icons.payments_rounded;
      case 'quote_accepted':   return Icons.check_circle_rounded;
      case 'quote_declined':   return Icons.cancel_rounded;
      case 'client_onboarded': return Icons.person_add_rounded;
      case 'bank_auto_link':   return Icons.link_rounded;
      case 'bank_suggest':     return Icons.bolt_rounded;
      default:                 return Icons.notifications_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'invoice_paid':     return BigDoggTheme.success;
      case 'quote_accepted':   return BigDoggTheme.success;
      case 'quote_declined':   return BigDoggTheme.error;
      case 'client_onboarded': return BigDoggTheme.teal700;
      case 'bank_auto_link':   return BigDoggTheme.success;
      case 'bank_suggest':     return BigDoggTheme.warning;
      default:                 return BigDoggTheme.teal700;
    }
  }

  String _formatTime(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) {
        return widget.isNl ? 'zojuist' : 'just now';
      }
      if (diff.inMinutes < 60) {
        return widget.isNl ? '${diff.inMinutes} min geleden' : '${diff.inMinutes}m ago';
      }
      if (diff.inHours < 24) {
        return widget.isNl ? '${diff.inHours} u geleden' : '${diff.inHours}h ago';
      }
      if (diff.inDays < 7) {
        return widget.isNl ? '${diff.inDays} d geleden' : '${diff.inDays}d ago';
      }
      String two(int v) => v.toString().padLeft(2, '0');
      return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNl = widget.isNl;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isNl ? 'Meldingen' : 'Notifications',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: BigDoggTheme.teal800,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                  ),
                  if (_items.any((n) => n['read_at'] == null))
                    TextButton(
                      onPressed: _markAllRead,
                      child: Text(
                        isNl ? 'Alles gelezen' : 'Mark all read',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_off_outlined,
                                  size: 56,
                                  color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text(
                                isNl
                                    ? 'Nog geen meldingen.'
                                    : 'No notifications yet.',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: BigDoggTheme.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 64),
                          itemBuilder: (_, i) {
                            final n = Map<String, dynamic>.from(
                                _items[i] as Map);
                            final type = (n['type'] ?? '').toString();
                            final unread = n['read_at'] == null;
                            final color = _colorFor(type);
                            return InkWell(
                              onTap: () => _onTap(n),
                              child: Container(
                                color: unread
                                    ? color.withOpacity(0.05)
                                    : Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.12),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Icon(_iconFor(type),
                                          color: color, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  n['title']?.toString() ??
                                                      '',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: unread
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                    color: BigDoggTheme
                                                        .teal800,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                _formatTime(n['created_at']
                                                    ?.toString()),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: BigDoggTheme
                                                      .lightTextHint,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if ((n['body'] ?? '')
                                              .toString()
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              n['body'].toString(),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: BigDoggTheme
                                                    .lightTextSecondary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.close,
                                          size: 16,
                                          color: BigDoggTheme.lightTextHint),
                                      onPressed: () =>
                                          _delete(n['id'].toString()),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
