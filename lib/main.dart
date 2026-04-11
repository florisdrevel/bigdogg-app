import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/client_onboarding_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/reset_password_screen.dart';
import 'theme.dart';
import 'providers/app_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://gjmjdzzhvniufcryuott.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqbWpkenpodm5pdWZjcnl1b3R0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU2NjE1NDYsImV4cCI6MjA5MTIzNzU0Nn0.0i9o_-IpaFTQtAyU12ObPYSCa071MRbZ0rpJLvBUThA',
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const BigdoggApp(),
    ),
  );
}

final _router = GoRouter(
  initialLocation: '/',
  errorBuilder: (context, state) {
    // Handle Supabase auth callbacks that come as URL fragments
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
    GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
    GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
    GoRoute(path: '/reset-password', builder: (context, state) => const ResetPasswordScreen()),
    GoRoute(
      path: '/onboard/:token',
      builder: (context, state) {
        final token = state.pathParameters['token'] ?? '';
        return ClientOnboardingScreen(token: token);
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