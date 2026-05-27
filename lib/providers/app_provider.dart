import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bump this when a release should re-show the welcome tour to everyone
/// (a "big update"). The tour shows when the user's stored
/// walkthrough_seen_version is below this number — so first-ever launch
/// (stored 0) shows it, and bumping this to 2, 3, … re-shows it once
/// after that release. Logging out does NOT reset it (see
/// AuthService.logout, which preserves device-level prefs).
const int kWalkthroughVersion = 1;

class AppProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  String _language = 'en';
  bool _projectsEnabled = false;
  bool _quotesEnabled = true;
  bool _hasSeenWalkthrough = true; // default true — only false once prefs confirm it
  bool _prefsLoaded = false;

  // One-shot navigation request consumed by DashboardScreen.
  // Used so e.g. enabling Projects via the Settings toggle takes the user
  // straight to the new Projects tab.
  int? _navigateToTab;

  // Sub-tab requests consumed by InvoicesScreen and ExpensesScreen.
  // Lets the walkthrough land on Offertes (1) inside Invoices, or
  // Investeringen (1) inside Expenses, instead of always the first sub-tab.
  int _invoicesSubTab = 0;
  int _expensesSubTab = 0;

  // Monotonically increasing counter screens watch to know when their
  // cached/local data is stale. Bumped every time a notification lands
  // (so the bell-icon ping reflects in client lists, invoice lists,
  // etc. without the user having to pull-to-refresh).
  int _dataVersion = 0;
  int get dataVersion => _dataVersion;
  void bumpDataVersion() {
    _dataVersion++;
    notifyListeners();
  }

  ThemeMode get themeMode => _themeMode;
  String get language => _language;
  bool get isDark => _themeMode == ThemeMode.dark;
  bool get projectsEnabled => _projectsEnabled;
  bool get quotesEnabled => _quotesEnabled;
  bool get hasSeenWalkthrough => _hasSeenWalkthrough;
  bool get prefsLoaded => _prefsLoaded;
  int? get navigateToTab => _navigateToTab;
  int get invoicesSubTab => _invoicesSubTab;
  int get expensesSubTab => _expensesSubTab;

  AppProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('theme') ?? 'light';
    final lang = prefs.getString('language') ?? 'en';
    final projects = prefs.getBool('projects_enabled') ?? false;
    final quotes = prefs.getBool('quotes_enabled') ?? true;
    _themeMode = theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
    _language = lang;
    _projectsEnabled = projects;
    _quotesEnabled = quotes;
    _hasSeenWalkthrough = _resolveSeen(prefs);
    _prefsLoaded = true;
    notifyListeners();
  }

  /// Walkthrough is "seen" when the stored version is at least the
  /// current one. Migrates the legacy boolean: a user who completed the
  /// old tour counts as having seen version 1.
  bool _resolveSeen(SharedPreferences prefs) {
    final storedVersion = prefs.getInt('walkthrough_seen_version');
    if (storedVersion != null) {
      return storedVersion >= kWalkthroughVersion;
    }
    final legacySeen = prefs.getBool('has_seen_walkthrough') ?? false;
    return legacySeen && kWalkthroughVersion <= 1;
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', _themeMode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
    notifyListeners();
  }

  Future<void> setProjectsEnabled(bool enabled) async {
    final wasEnabled = _projectsEnabled;
    _projectsEnabled = enabled;
    // Off -> on: take the user straight to the new Projects tab. The list
    // shifts (Projects inserts at index 4) so without this nudge the user
    // would silently land on whatever screen now sits at their old index.
    // On -> off: do nothing — the dashboard already clamps the index back
    // to Settings.
    if (!wasEnabled && enabled) {
      _navigateToTab = 4;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('projects_enabled', enabled);
    notifyListeners();
  }

  void consumeNavigateToTab() {
    _navigateToTab = null;
  }

  /// Externally request a tab change — used by deep-links from the
  /// notifications sheet so a tap on "Factuur betaald" lands on the
  /// Invoices tab without the user having to find it.
  void requestNavigateToTab(int idx) {
    _navigateToTab = idx;
    notifyListeners();
  }

  // Always notify even if value is unchanged, so screens whose internal
  // TabController has drifted (user manually swiped) can re-snap to the
  // walkthrough's intended sub-tab.
  void setInvoicesSubTab(int idx) {
    _invoicesSubTab = idx;
    notifyListeners();
  }

  void setExpensesSubTab(int idx) {
    _expensesSubTab = idx;
    notifyListeners();
  }

  Future<void> setQuotesEnabled(bool enabled) async {
    _quotesEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('quotes_enabled', enabled);
    notifyListeners();
  }

  Future<void> markWalkthroughSeen() async {
    _hasSeenWalkthrough = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('walkthrough_seen_version', kWalkthroughVersion);
    notifyListeners();
  }

  Future<void> resetWalkthrough() async {
    _hasSeenWalkthrough = false;
    final prefs = await SharedPreferences.getInstance();
    // 0 = never seen → tour shows again. Used by the "restart tour"
    // option in Settings.
    await prefs.setInt('walkthrough_seen_version', 0);
    notifyListeners();
  }
}
