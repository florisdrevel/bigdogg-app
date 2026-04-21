import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/app_provider.dart';
import 'products_screen.dart';
import 'clients_screen.dart';
import 'invoices_screen.dart';
import 'expenses_screen.dart';
import 'overview_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'projects_screen.dart';
import 'walkthrough_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  void _completeWalkthrough() {
    context.read<AppProvider>().markWalkthroughSeen();
  }

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

    // Walkthrough is active whenever hasSeenWalkthrough is false.
    // This reacts both on first login AND when "Start tour" resets the flag.
    final showWalkthrough = !appProvider.hasSeenWalkthrough;

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
          IconButton(
            icon: const Icon(Icons.logout, color: BigDoggTheme.lightTextSecondary),
            onPressed: () => context.go('/login'),
            tooltip: isNl ? 'Uitloggen' : 'Log out',
          ),
        ],
      ),
      body: screens[safeIndex],
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
      active: showWalkthrough,
      onComplete: _completeWalkthrough,
      onTabChange: (idx) => setState(() => _currentIndex = idx),
      currentTabIndex: safeIndex,
      projectsEnabled: projectsEnabled,
      child: scaffold,
    );
  }
}