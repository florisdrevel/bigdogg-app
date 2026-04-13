import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/subscription_service.dart';
import '../services/auth_service.dart';
import '../providers/app_provider.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _subscription;
  bool _loading = true;
  bool _checkingOut = false;

  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _changingPassword = false;
  String? _passwordError;
  String? _passwordSuccess;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    setState(() => _loading = true);
    final result = await SubscriptionService.getStatus();
    setState(() {
      _loading = false;
      if (result['success']) _subscription = result['subscription'];
    });
  }

  Future<void> _startCheckout() async {
    setState(() => _checkingOut = true);
    final result = await SubscriptionService.createCheckout();
    setState(() => _checkingOut = false);
    if (result['success']) {
      final url = Uri.parse(result['checkout_url']);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? 'Something went wrong'),
          backgroundColor: BigDoggTheme.error,
        ));
      }
    }
  }

  Future<void> _changePassword(bool isNl) async {
    setState(() {
      _passwordError = null;
      _passwordSuccess = null;
    });

    final newPw = _newPasswordController.text;
    final confirmPw = _confirmPasswordController.text;

    if (newPw.isEmpty) {
      setState(() => _passwordError =
          isNl ? 'Vul een nieuw wachtwoord in' : 'Enter a new password');
      return;
    }
    if (newPw.length < 8) {
      setState(() => _passwordError =
          isNl ? 'Minimaal 8 tekens' : 'At least 8 characters');
      return;
    }
    if (!newPw.contains(RegExp(r'[A-Z]'))) {
      setState(() => _passwordError = isNl
          ? 'Minimaal één hoofdletter'
          : 'At least one uppercase letter');
      return;
    }
    if (!newPw.contains(RegExp(r'[0-9]'))) {
      setState(() => _passwordError =
          isNl ? 'Minimaal één cijfer' : 'At least one number');
      return;
    }
    if (newPw != confirmPw) {
      setState(() => _passwordError = isNl
          ? 'Wachtwoorden komen niet overeen'
          : 'Passwords do not match');
      return;
    }

    setState(() => _changingPassword = true);
    final result = await AuthService.changePassword(newPw);
    setState(() {
      _changingPassword = false;
      if (result['success']) {
        _passwordSuccess = isNl
            ? 'Wachtwoord gewijzigd'
            : 'Password changed successfully';
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } else {
        _passwordError = result['message'];
      }
    });
  }

  Future<void> _deleteAccount(bool isNl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isNl ? 'Account verwijderen' : 'Delete account'),
        content: Text(isNl
            ? 'Weet je zeker dat je je account wilt verwijderen? Al je gegevens worden permanent verwijderd. Dit kan niet ongedaan worden gemaakt.'
            : 'Are you sure you want to delete your account? All your data will be permanently deleted. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isNl ? 'Annuleren' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: BigDoggTheme.error),
            child: Text(
                isNl ? 'Verwijderen' : 'Delete',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final result = await AuthService.deleteAccount();
      if (result['success'] && mounted) {
        context.go('/login');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ??
              (isNl ? 'Verwijderen mislukt' : 'Delete failed')),
          backgroundColor: BigDoggTheme.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNl = context.watch<AppProvider>().language == 'nl';
    final appProvider = context.watch<AppProvider>();

    if (_loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Subscription ──────────────────────────────────────────
          _sectionHeader(isNl ? 'Abonnement' : 'Subscription'),
          const SizedBox(height: 8),
          _buildStatusCard(isNl),
          const SizedBox(height: 8),
          _buildPlanCard(isNl),
          const SizedBox(height: 24),

          // ── Security ──────────────────────────────────────────────
          _sectionHeader(isNl ? 'Beveiliging' : 'Security'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: BigDoggTheme.lightSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BigDoggTheme.lightBorder),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isNl ? 'Wachtwoord wijzigen' : 'Change password',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: BigDoggTheme.teal800),
                ),
                const SizedBox(height: 12),
                if (_passwordError != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: BigDoggTheme.errorBg,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(_passwordError!,
                        style: const TextStyle(
                            color: BigDoggTheme.error, fontSize: 13)),
                  ),
                if (_passwordSuccess != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: BigDoggTheme.successBg,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(_passwordSuccess!,
                        style: const TextStyle(
                            color: BigDoggTheme.success, fontSize: 13)),
                  ),
                TextField(
                  controller: _newPasswordController,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    labelText:
                        isNl ? 'Nieuw wachtwoord' : 'New password',
                    suffixIcon: ExcludeFocus(
                      child: IconButton(
                        icon: Icon(_obscureNew
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(
                            () => _obscureNew = !_obscureNew),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: isNl
                        ? 'Wachtwoord bevestigen'
                        : 'Confirm password',
                    suffixIcon: ExcludeFocus(
                      child: IconButton(
                        icon: Icon(_obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _changingPassword
                        ? null
                        : () => _changePassword(isNl),
                    child: _changingPassword
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : Text(isNl
                            ? 'Wachtwoord opslaan'
                            : 'Save password'),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  isNl ? 'Account verwijderen' : 'Delete account',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: BigDoggTheme.error),
                ),
                const SizedBox(height: 6),
                Text(
                  isNl
                      ? 'Verwijder je account en alle bijbehorende gegevens permanent.'
                      : 'Permanently delete your account and all associated data.',
                  style: const TextStyle(
                      fontSize: 13,
                      color: BigDoggTheme.lightTextSecondary),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _deleteAccount(isNl),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BigDoggTheme.error,
                      side: const BorderSide(color: BigDoggTheme.error),
                    ),
                    child: Text(isNl
                        ? 'Account verwijderen'
                        : 'Delete my account'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── View settings ─────────────────────────────────────────
          _sectionHeader(
              isNl ? 'Weergave-instellingen' : 'View settings'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: BigDoggTheme.lightSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BigDoggTheme.lightBorder),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isNl ? 'Projecten' : 'Projects',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: BigDoggTheme.lightTextPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isNl
                                ? 'Koppel facturen en kosten aan projecten voor een beter overzicht.'
                                : 'Link invoices and expenses to projects for a better overview.',
                            style: const TextStyle(
                                fontSize: 12,
                                color: BigDoggTheme.lightTextSecondary),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: appProvider.projectsEnabled,
                      onChanged: (val) =>
                          appProvider.setProjectsEnabled(val),
                      activeColor: BigDoggTheme.teal800,
                    ),
                  ],
                ),
                if (appProvider.projectsEnabled) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: BigDoggTheme.teal100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 16, color: BigDoggTheme.teal800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isNl
                                ? 'Projecten zijn ingeschakeld. Projectbeheer komt binnenkort beschikbaar.'
                                : 'Projects are enabled. Project management is coming soon.',
                            style: const TextStyle(
                                fontSize: 12,
                                color: BigDoggTheme.teal800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: BigDoggTheme.teal800),
    );
  }

  Widget _buildStatusCard(bool isNl) {
    if (_subscription == null) return const SizedBox();
    final status = _subscription!['status'];
    final isActive = _subscription!['is_active'] ?? false;
    final daysLeft = _subscription!['days_left'];

    Color statusColor;
    String statusText;
    String statusDetail;

    if (status == 'trial') {
      statusColor =
          daysLeft > 5 ? BigDoggTheme.success : BigDoggTheme.warning;
      statusText = isNl ? 'Gratis proefperiode' : 'Free Trial';
      statusDetail = daysLeft > 0
          ? isNl
              ? '$daysLeft dagen resterend'
              : '$daysLeft days remaining'
          : isNl
              ? 'Proefperiode verlopen'
              : 'Trial expired';
    } else if (status == 'active') {
      statusColor = BigDoggTheme.success;
      statusText = isNl ? 'Actief' : 'Active';
      statusDetail =
          isNl ? 'Abonnement actief' : 'Subscription active';
    } else {
      statusColor = BigDoggTheme.error;
      statusText = isNl ? 'Verlopen' : 'Expired';
      statusDetail = isNl
          ? 'Verleng je abonnement om door te gaan'
          : 'Please subscribe to continue';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BigDoggTheme.teal800,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(statusText,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                Text(statusDetail,
                    style:
                        TextStyle(color: statusColor, fontSize: 14)),
              ],
            ),
          ),
          if (!isActive || status == 'trial')
            ElevatedButton(
              onPressed: _checkingOut ? null : _startCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: BigDoggTheme.teal800,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: _checkingOut
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2))
                  : Text(isNl ? 'Abonneren' : 'Subscribe',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(bool isNl) {
    return Container(
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('BigDogg Pro',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: BigDoggTheme.teal800)),
                    Text(
                      isNl
                          ? 'Alles wat je nodig hebt als ZZP\'er'
                          : 'Everything you need as a freelancer',
                      style: const TextStyle(
                          color: BigDoggTheme.lightTextSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('€7,99',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                          color: BigDoggTheme.teal800)),
                  Text(isNl ? 'per maand' : 'per month',
                      style: const TextStyle(
                          color: BigDoggTheme.lightTextSecondary,
                          fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: BigDoggTheme.gold500.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isNl ? '30 dagen gratis proberen' : '30-day free trial',
              style: const TextStyle(
                  color: BigDoggTheme.gold600,
                  fontWeight: FontWeight.w600,
                  fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          _feature(isNl
              ? '✓ Onbeperkt facturen'
              : '✓ Unlimited invoices'),
          _feature(isNl
              ? '✓ AI factuur assistent'
              : '✓ AI invoice assistant'),
          _feature(isNl
              ? '✓ Klantenbeheer'
              : '✓ Client management'),
          _feature(isNl
              ? '✓ Uitgaven bijhouden'
              : '✓ Expense tracking'),
          _feature(isNl
              ? '✓ Kwartaal BTW overzicht'
              : '✓ Quarterly VAT overview'),
          _feature(isNl
              ? '✓ Jaaroverzicht financiën'
              : '✓ Annual financial overview'),
          _feature(
              isNl ? '✓ Bonnen scannen' : '✓ Receipt scanning'),
          _feature(isNl
              ? '✓ Betalen via Stripe (iDEAL, creditcard)'
              : '✓ Pay via Stripe (iDEAL, credit card)'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _checkingOut ? null : _startCheckout,
              child: _checkingOut
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      isNl
                          ? 'Start abonnement — €7,99/maand'
                          : 'Start subscription — €7.99/month',
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              isNl
                  ? 'Altijd opzegbaar · iDEAL en creditcard via Stripe'
                  : 'Cancel anytime · iDEAL and credit card via Stripe',
              style: const TextStyle(
                  color: BigDoggTheme.lightTextHint, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _feature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 15,
              color: BigDoggTheme.lightTextPrimary)),
    );
  }
}