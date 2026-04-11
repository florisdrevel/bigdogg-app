import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';

class AuthCallbackScreen extends StatefulWidget {
  const AuthCallbackScreen({super.key});

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  bool _isNl = true;

  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final uri = Uri.base;
    final fragment = uri.fragment;
    final params = Uri.splitQueryString(fragment.startsWith('/') ? fragment.substring(1) : fragment);
    final type = params['type'];

    if (type == 'recovery') {
      context.go('/reset-password?${fragment}');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', width: 100, height: 100),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _isNl ? 'Even geduld...' : 'Please wait...',
              style: const TextStyle(color: BigDoggTheme.lightTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}