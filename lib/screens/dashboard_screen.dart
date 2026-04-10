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
import 'subscription_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    InvoicesScreen(),
    ClientsScreen(),
    ProductsScreen(),
    ExpensesScreen(),
    OverviewScreen(),
    ProfileScreen(),
    SubscriptionScreen(),
  ];

  final List<String> _titlesEn = const [
    'Invoices', 'Clients', 'Products', 'Expenses', 'Overview', 'Profile', 'Plan',
  ];

  final List<String> _titlesNl = const [
    'Facturen', 'Klanten', 'Producten', 'Kosten', 'Overzicht', 'Profiel', 'Abonnement',
  ];

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final isDark = appProvider.isDark;
    final isNl = appProvider.language == 'nl';
    final titles = isNl ? _titlesNl : _titlesEn;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', width: 28, height: 28),
            const SizedBox(width: 10),
            Text(titles[_currentIndex]),
          ],
        ),
        actions: [
          // Language toggle
          GestureDetector(
            onTap: () => appProvider.setLanguage(isNl ? 'en' : 'nl'),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: BigDoggTheme.gold500.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: BigDoggTheme.gold500.withOpacity(0.4)),
              ),
              child: Text(
                isNl ? 'EN' : 'NL',
                style: const TextStyle(
                  color: BigDoggTheme.gold500,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          // Theme toggle
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: () => appProvider.toggleTheme(),
            tooltip: isDark ? 'Light mode' : 'Dark mode',
          ),
          // Logout
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.go('/login'),
            tooltip: isNl ? 'Uitloggen' : 'Log out',
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? BigDoggTheme.darkBorder : BigDoggTheme.lightBorder,
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: [
            BottomNavigationBarItem(icon: const Icon(Icons.receipt_long_outlined), label: isNl ? 'Facturen' : 'Invoices'),
            BottomNavigationBarItem(icon: const Icon(Icons.people_outline), label: isNl ? 'Klanten' : 'Clients'),
            BottomNavigationBarItem(icon: const Icon(Icons.inventory_2_outlined), label: isNl ? 'Producten' : 'Products'),
            BottomNavigationBarItem(icon: const Icon(Icons.receipt_outlined), label: isNl ? 'Kosten' : 'Expenses'),
            BottomNavigationBarItem(icon: const Icon(Icons.bar_chart_outlined), label: isNl ? 'Overzicht' : 'Overview'),
            BottomNavigationBarItem(icon: const Icon(Icons.person_outline), label: isNl ? 'Profiel' : 'Profile'),
            BottomNavigationBarItem(icon: const Icon(Icons.credit_card_outlined), label: isNl ? 'Abonnement' : 'Plan'),
          ],
        ),
      ),
    );
  }
}