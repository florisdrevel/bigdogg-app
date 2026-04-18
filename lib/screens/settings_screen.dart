import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/subscription_service.dart';
import '../services/auth_service.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/payments_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _subscription;
  bool _loading = true;
  bool _checkingOut = false;
  Map<String, dynamic>? _stripeStatus;
  bool _loadingStripe = false;
  bool _connectingStripe = false;

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
    _loadStripeStatus();
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
Future<void> _loadStripeStatus() async {
  setState(() => _loadingStripe = true);
  final result = await PaymentsService.getConnectStatus();
  setState(() {
    _loadingStripe = false;
    if (result['success']) _stripeStatus = result;
  });
}

Future<void> _connectStripe(bool isNl) async {
  setState(() => _connectingStripe = true);
  final result = await PaymentsService.createConnectLink();
  setState(() => _connectingStripe = false);
  if (result['success']) {
    final url = Uri.parse(result['url']);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  } else {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? 'Error'),
        backgroundColor: BigDoggTheme.error,
      ));
    }
  }
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
            child: Text(isNl ? 'Verwijderen' : 'Delete',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final result = await AuthService.deleteAccount();
      if (result['success'] && mounted) {
        context.go('/');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ??
              (isNl ? 'Verwijderen mislukt' : 'Delete failed')),
          backgroundColor: BigDoggTheme.error,
        ));
      }
    }
  }

  void _showTerms(BuildContext context, bool isNl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints:
              const BoxConstraints(maxWidth: 640, maxHeight: 600),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: BigDoggTheme.teal800,
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(15)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isNl
                            ? 'Algemene Voorwaarden'
                            : 'Terms & Conditions',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _termsText(isNl),
                    style: const TextStyle(
                        fontSize: 13,
                        color: BigDoggTheme.lightTextPrimary,
                        height: 1.7),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(
                          color: BigDoggTheme.lightBorder)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(isNl ? 'Sluiten' : 'Close'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _termsText(bool isNl) {
    if (isNl) {
      return '''Algemene Voorwaarden — BigDogg
Versie 1.0 | Ingangsdatum: 1 januari 2026

1. OVER BIGDOGG
BigDogg is een online boekhoud- en facturatiedienst voor zelfstandigen en ZZP'ers in Nederland, aangeboden door BigDogg (hierna: "BigDogg", "wij", "ons"). Door gebruik te maken van onze diensten ga je akkoord met deze voorwaarden.

2. DIENSTVERLENING
BigDogg biedt tools voor facturatie, uitgavenbeheer, BTW-overzichten en financiële rapportages. Wij streven naar correctheid en beschikbaarheid van onze diensten, maar bieden geen garanties met betrekking tot volledigheid of geschiktheid voor specifieke fiscale of juridische doeleinden.

3. ABONNEMENT EN BETALING
Het abonnement bedraagt €9,99 per maand. Na een gratis proefperiode van 30 dagen wordt er overgegaan op een betaald abonnement, tenzij je vóór het einde van de proefperiode opzegt. Opzegging kan op elk moment via de instellingen in de app. Je behoudt toegang tot het einde van de lopende betaalperiode.

4. VERANTWOORDELIJKHEID VOOR ADMINISTRATIE
BigDogg ondersteunt jou bij je administratie, maar de volledige verantwoordelijkheid voor de juistheid, volledigheid en tijdige indiening van je belastingaangiftes, facturen en overige administratieve verplichtingen ligt bij jou als gebruiker.

Wij raden je nadrukkelijk aan om regelmatig lokale back-ups te maken van al je facturen, rapporten en financiële documenten door deze te downloaden en op te slaan op een eigen, veilige locatie. BigDogg is niet aansprakelijk voor verlies van gegevens als gevolg van technische storingen, beëindiging van het account of andere omstandigheden buiten onze directe controle. De Belastingdienst vereist dat je zelf een volledige en toegankelijke administratie bijhoudt — BigDogg ondersteunt dit proces, maar vervangt deze verplichting niet.

5. GEGEVENSVERWERKING EN PRIVACY
Wij verwerken persoonsgegevens in overeenstemming met de Algemene Verordening Gegevensbescherming (AVG). Je gegevens worden uitsluitend gebruikt voor het leveren van de dienst en worden niet verkocht aan derden. Bij beëindiging van je account worden je gegevens verwijderd conform ons bewaarbeleid.

6. AANSPRAKELIJKHEIDSBEPERKING
BigDogg is niet aansprakelijk voor indirecte schade, gederfde inkomsten, gemiste belastingvoordelen of schade voortvloeiend uit onjuist gebruik van het platform. De totale aansprakelijkheid van BigDogg is beperkt tot het bedrag dat je in de afgelopen drie maanden aan ons hebt betaald.

7. INTELLECTUEEL EIGENDOM
Alle inhoud, functionaliteiten en technologie van BigDogg zijn eigendom van BigDogg en mogen niet worden gekopieerd, verspreid of gebruikt zonder schriftelijke toestemming.

8. WIJZIGINGEN
Wij behouden het recht voor deze voorwaarden te wijzigen. Wezenlijke wijzigingen worden ten minste 30 dagen van tevoren per e-mail aangekondigd. Voortgezet gebruik van de dienst na de ingangsdatum van de wijziging geldt als aanvaarding.

9. TOEPASSELIJK RECHT
Op deze voorwaarden is Nederlands recht van toepassing. Geschillen worden voorgelegd aan de bevoegde rechter in Nederland.

10. CONTACT
Voor vragen over deze voorwaarden: info@bigdogg.nl''';
    } else {
      return '''Terms & Conditions — BigDogg
Version 1.0 | Effective date: 1 January 2026

1. ABOUT BIGDOGG
BigDogg is an online accounting and invoicing service for freelancers in the Netherlands, provided by BigDogg (hereinafter: "BigDogg", "we", "us"). By using our services, you agree to these terms.

2. SERVICES
BigDogg provides tools for invoicing, expense management, VAT overviews and financial reporting. We strive for accuracy and availability of our services, but make no guarantees regarding completeness or suitability for specific tax or legal purposes.

3. SUBSCRIPTION AND PAYMENT
The subscription fee is €9.99 per month. After a 30-day free trial, a paid subscription begins unless cancelled before the end of the trial period. You may cancel at any time via the settings in the app. You retain access until the end of the current billing period.

4. RESPONSIBILITY FOR YOUR ADMINISTRATION
BigDogg supports you in managing your administration, but full responsibility for the accuracy, completeness and timely submission of your tax returns, invoices and other administrative obligations rests with you as the user.

We strongly encourage you to regularly create local backups of all your invoices, reports and financial documents by downloading and saving them to a secure location of your own. BigDogg is not liable for data loss resulting from technical failures, account termination or other circumstances beyond our direct control. The Dutch Tax Authority (Belastingdienst) requires you to maintain a complete and accessible administration yourself — BigDogg supports this process but does not replace this obligation.

5. DATA PROCESSING AND PRIVACY
We process personal data in accordance with the General Data Protection Regulation (GDPR). Your data is used solely to provide the service and is not sold to third parties. Upon account termination, your data will be deleted in accordance with our retention policy.

6. LIMITATION OF LIABILITY
BigDogg is not liable for indirect damages, lost revenue, missed tax benefits or damage resulting from improper use of the platform. BigDogg's total liability is limited to the amount you have paid us in the preceding three months.

7. INTELLECTUAL PROPERTY
All content, features and technology of BigDogg are owned by BigDogg and may not be copied, distributed or used without written permission.

8. CHANGES
We reserve the right to amend these terms. Material changes will be announced by email at least 30 days in advance. Continued use of the service after the effective date of the change constitutes acceptance.

9. GOVERNING LAW
These terms are governed by Dutch law. Disputes will be submitted to the competent court in the Netherlands.

10. CONTACT
For questions about these terms: info@bigdogg.nl''';
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
          const SizedBox(height: 24),
_sectionHeader(isNl ? 'Betalingen' : 'Payments'),
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
        isNl ? 'Stripe betaalaccount' : 'Stripe payment account',
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: BigDoggTheme.teal800),
      ),
      const SizedBox(height: 4),
      Text(
        isNl
            ? 'Koppel je Stripe account om betaallinks en QR codes te genereren op je facturen.'
            : 'Connect your Stripe account to generate payment links and QR codes on your invoices.',
        style: const TextStyle(
            fontSize: 13,
            color: BigDoggTheme.lightTextSecondary),
      ),
      const SizedBox(height: 12),
      if (_loadingStripe)
        const Center(child: CircularProgressIndicator())
      else if (_stripeStatus?['connected'] == true &&
          _stripeStatus?['enabled'] == true)
        Row(
          children: [
            const Icon(Icons.check_circle,
                color: BigDoggTheme.success, size: 18),
            const SizedBox(width: 8),
            Text(
              isNl
                  ? 'Stripe account gekoppeld en actief'
                  : 'Stripe account connected and active',
              style: const TextStyle(
                  color: BigDoggTheme.success,
                  fontWeight: FontWeight.w600),
            ),
          ],
        )
      else if (_stripeStatus?['connected'] == true &&
          _stripeStatus?['enabled'] == false)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber,
                    color: BigDoggTheme.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isNl
                        ? 'Account gekoppeld maar onboarding nog niet voltooid.'
                        : 'Account connected but onboarding not complete.',
                    style: const TextStyle(
                        color: BigDoggTheme.warning,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _connectingStripe
                    ? null
                    : () => _connectStripe(isNl),
                child: Text(isNl
                    ? 'Onboarding afronden'
                    : 'Complete onboarding'),
              ),
            ),
          ],
        )
      else
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _connectingStripe
                ? null
                : () => _connectStripe(isNl),
            icon: _connectingStripe
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.link, color: Colors.white),
            label: Text(
                isNl
                    ? 'Koppel Stripe account'
                    : 'Connect Stripe account',
                style: const TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: BigDoggTheme.teal800,
            ),
          ),
        ),
    ],
  ),
),
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
                            color: BigDoggTheme.error,
                            fontSize: 13)),
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
                            color: BigDoggTheme.success,
                            fontSize: 13)),
                  ),
                TextField(
                  controller: _newPasswordController,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    labelText: isNl
                        ? 'Nieuw wachtwoord'
                        : 'New password',
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
                        onPressed: () => setState(() =>
                            _obscureConfirm = !_obscureConfirm),
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
                      side: const BorderSide(
                          color: BigDoggTheme.error),
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
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            isNl ? 'Projecten' : 'Projects',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: BigDoggTheme
                                    .lightTextPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isNl
                                ? 'Koppel facturen en kosten aan projecten voor een beter overzicht.'
                                : 'Link invoices and expenses to projects for a better overview.',
                            style: const TextStyle(
                                fontSize: 12,
                                color: BigDoggTheme
                                    .lightTextSecondary),
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
                            size: 16,
                            color: BigDoggTheme.teal800),
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
          const SizedBox(height: 24),

          // ── Terms & Conditions ────────────────────────────────────
          Center(
            child: TextButton.icon(
              onPressed: () => _showTerms(context, isNl),
              icon: const Icon(Icons.description_outlined,
                  size: 16,
                  color: BigDoggTheme.lightTextSecondary),
              label: Text(
                isNl
                    ? 'Algemene Voorwaarden'
                    : 'Terms & Conditions',
                style: const TextStyle(
                    color: BigDoggTheme.lightTextSecondary,
                    fontSize: 13),
              ),
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
                  const Text('€9,99',
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
          _feature(isNl ? '✓ Onbeperkt facturen' : '✓ Unlimited invoices'),
          _feature(isNl ? '✓ AI factuur assistent' : '✓ AI invoice assistant'),
          _feature(isNl ? '✓ Historische factuurimport' : '✓ Historical invoice import'),
          _feature(isNl ? '✓ Klantenbeheer' : '✓ Client management'),
          _feature(isNl ? '✓ Uitgaven bijhouden' : '✓ Expense tracking'),
          _feature(isNl ? '✓ Kwartaal BTW overzicht' : '✓ Quarterly VAT overview'),
          _feature(isNl ? '✓ Jaaroverzicht financiën' : '✓ Annual financial overview'),
          _feature(isNl ? '✓ Bonnen scannen' : '✓ Receipt scanning'),
          _feature(isNl ? '✓ Betalen via Stripe (iDEAL, creditcard)' : '✓ Pay via Stripe (iDEAL, credit card)'),
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
                          ? 'Start abonnement — €9,99/maand'
                          : 'Start subscription — €9.99/month',
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
