import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  final List<String> _titles = const [
    'Invoices',
    'Clients',
    'Products',
    'Expenses',
    'Overview',
    'Profile',
    'Subscription',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(_titles[_currentIndex], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => context.go('/login'),
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF1A1A2E),
        unselectedItemColor: const Color(0xFF6B7280),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: 'Invoices'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Clients'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), label: 'Products'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_outlined), label: 'Expenses'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), label: 'Overview'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.credit_card_outlined), label: 'Plan'),
        ],
      ),
    );
  }
}