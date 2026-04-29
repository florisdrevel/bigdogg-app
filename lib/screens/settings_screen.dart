import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/subscription_service.dart';
import '../services/auth_service.dart';
import '../services/referral_service.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
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
  bool _subscriptionExpanded = false;
  bool _stripeFeeExpanded = false;

  Map<String, dynamic>? _stripeStatus;
  bool _loadingStripe = false;
  bool _connectingStripe = false;
  bool _openingDashboard = false;

  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _changingPassword = false;
  String? _passwordError;
  String? _passwordSuccess;

  // Referral state
  Map<String, dynamic>? _referralStats;
  bool _loadingReferral = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _loadStripeStatus();
    _loadReferralStats();
  }

  Future<void> _loadReferralStats() async {
    setState(() => _loadingReferral = true);
    final stats = await ReferralService.getStats();
    if (!mounted) return;
    setState(() {
      _referralStats = stats;
      _loadingReferral = false;
    });
  }

  Future<void> _generateReferralLink(bool isNl) async {
    setState(() => _loadingReferral = true);
    final code = await ReferralService.generateCode();
    if (!mounted) return;
    if (code != null) {
      // Refresh stats too so the counts come along
      final stats = await ReferralService.getStats();
      if (!mounted) return;
      setState(() {
        _referralStats = stats['code'] != null
            ? stats
            : {..._referralStats ?? const {}, 'code': code};
        _loadingReferral = false;
      });
      // Also copy straight to clipboard so the click feels productive
      final link = 'https://bigdogg.nl/#/register?ref=$code';
      await Clipboard.setData(ClipboardData(text: link));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isNl
            ? 'Je link is aangemaakt en gekopieerd!'
            : 'Your link is ready and copied!'),
        duration: const Duration(seconds: 3),
        backgroundColor: BigDoggTheme.success,
      ));
    } else {
      setState(() => _loadingReferral = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isNl
            ? 'Kon je link niet aanmaken. Probeer het later opnieuw.'
            : 'Couldn\'t create your link. Please try again later.'),
        duration: const Duration(seconds: 4),
        backgroundColor: BigDoggTheme.error,
      ));
    }
  }

  Future<void> _copyReferralLink(bool isNl) async {
    final code = _referralStats?['code'] as String?;
    // No code yet → generate one (which also copies on success)
    if (code == null) {
      await _generateReferralLink(isNl);
      return;
    }
    final link = 'https://bigdogg.nl/#/register?ref=$code';
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isNl ? 'Link gekopieerd!' : 'Link copied!'),
      duration: const Duration(seconds: 2),
      backgroundColor: BigDoggTheme.success,
    ));
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
      if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? 'Error'),
          backgroundColor: BigDoggTheme.error,
        ));
      }
    }
  }

  Future<void> _openStripeDashboard(bool isNl) async {
    setState(() => _openingDashboard = true);
    final result = await PaymentsService.getDashboardLink();
    setState(() => _openingDashboard = false);
    if (result['success']) {
      final url = Uri.parse(result['url']);
      if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isNl ? 'Kan Stripe dashboard niet openen' : 'Could not open Stripe dashboard'),
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
      if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? 'Something went wrong'),
          backgroundColor: BigDoggTheme.error,
        ));
      }
    }
  }

  bool get _pwHasLength => _newPasswordController.text.length >= 8;
  bool get _pwHasUpper => _newPasswordController.text.contains(RegExp(r'[A-Z]'));
  bool get _pwHasNumber => _newPasswordController.text.contains(RegExp(r'[0-9]'));
  bool get _pwMatches =>
      _newPasswordController.text == _confirmPasswordController.text &&
      _confirmPasswordController.text.isNotEmpty;

  Future<void> _changePassword(bool isNl) async {
    setState(() { _passwordError = null; _passwordSuccess = null; });
    final newPw = _newPasswordController.text;
    final confirmPw = _confirmPasswordController.text;
    if (newPw.isEmpty) { setState(() => _passwordError = isNl ? 'Vul een nieuw wachtwoord in' : 'Enter a new password'); return; }
    if (!_pwHasLength) { setState(() => _passwordError = isNl ? 'Minimaal 8 tekens' : 'At least 8 characters'); return; }
    if (!_pwHasUpper) { setState(() => _passwordError = isNl ? 'Minimaal één hoofdletter' : 'At least one uppercase letter'); return; }
    if (!_pwHasNumber) { setState(() => _passwordError = isNl ? 'Minimaal één cijfer' : 'At least one number'); return; }
    if (newPw != confirmPw) { setState(() => _passwordError = isNl ? 'Wachtwoorden komen niet overeen' : 'Passwords do not match'); return; }
    setState(() => _changingPassword = true);
    final result = await AuthService.changePassword(newPw);
    setState(() {
      _changingPassword = false;
      if (result['success']) {
        _passwordSuccess = isNl ? 'Wachtwoord gewijzigd' : 'Password changed successfully';
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(isNl ? 'Annuleren' : 'Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: BigDoggTheme.error),
            child: Text(isNl ? 'Verwijderen' : 'Delete', style: const TextStyle(color: Colors.white)),
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
          content: Text(result['message'] ?? (isNl ? 'Verwijderen mislukt' : 'Delete failed')),
          backgroundColor: BigDoggTheme.error,
        ));
      }
    }
  }

  void _restartWalkthrough(bool isNl) async {
    await context.read<AppProvider>().resetWalkthrough();
  }

  void _showTerms(BuildContext context, bool isNl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 600),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: BigDoggTheme.teal800,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(isNl ? 'Algemene Voorwaarden' : 'Terms & Conditions',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Text(_termsText(isNl),
                    style: const TextStyle(fontSize: 13, color: BigDoggTheme.lightTextPrimary, height: 1.7)),
              )),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: BigDoggTheme.lightBorder))),
                child: SizedBox(width: double.infinity,
                    child: ElevatedButton(onPressed: () => Navigator.pop(context), child: Text(isNl ? 'Sluiten' : 'Close'))),
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

Wij raden je nadrukkelijk aan om regelmatig lokale back-ups te maken van al je facturen, rapporten en financiële documenten door deze te downloaden en op te slaan op een eigen, veilige locatie. BigDogg is niet aansprakelijk voor verlies van gegevens als gevolg van technische storingen, beëindiging van het account of andere omstandigheden buiten onze directe controle.

5. GEGEVENSVERWERKING EN PRIVACY
Wij verwerken persoonsgegevens in overeenstemming met de Algemene Verordening Gegevensbescherming (AVG). Je gegevens worden uitsluitend gebruikt voor het leveren van de dienst en worden niet verkocht aan derden.

6. AANSPRAKELIJKHEIDSBEPERKING
BigDogg is niet aansprakelijk voor indirecte schade, gederfde inkomsten, gemiste belastingvoordelen of schade voortvloeiend uit onjuist gebruik van het platform.

7. INTELLECTUEEL EIGENDOM
Alle inhoud, functionaliteiten en technologie van BigDogg zijn eigendom van BigDogg en mogen niet worden gekopieerd, verspreid of gebruikt zonder schriftelijke toestemming.

8. WIJZIGINGEN
Wij behouden het recht voor deze voorwaarden te wijzigen. Wezenlijke wijzigingen worden ten minste 30 dagen van tevoren per e-mail aangekondigd.

9. TOEPASSELIJK RECHT
Op deze voorwaarden is Nederlands recht van toepassing. Geschillen worden voorgelegd aan de bevoegde rechter in Nederland.

10. CONTACT
Voor vragen over deze voorwaarden: info@bigdogg.nl''';
    } else {
      return '''Terms & Conditions — BigDogg
Version 1.0 | Effective date: 1 January 2026

1. ABOUT BIGDOGG
BigDogg is an online accounting and invoicing service for freelancers in the Netherlands, provided by BigDogg. By using our services, you agree to these terms.

2. SERVICES
BigDogg provides tools for invoicing, expense management, VAT overviews and financial reporting. We strive for accuracy and availability but make no guarantees regarding completeness or suitability for specific tax or legal purposes.

3. SUBSCRIPTION AND PAYMENT
The subscription fee is €9.99 per month. After a 30-day free trial, a paid subscription begins unless cancelled before the end of the trial. You may cancel at any time via the settings in the app.

4. RESPONSIBILITY FOR YOUR ADMINISTRATION
Full responsibility for the accuracy, completeness and timely submission of your tax returns rests with you as the user. We strongly encourage you to regularly create local backups of all your invoices and financial documents.

5. DATA PROCESSING AND PRIVACY
We process personal data in accordance with the GDPR. Your data is used solely to provide the service and is not sold to third parties.

6. LIMITATION OF LIABILITY
BigDogg is not liable for indirect damages, lost revenue or damage resulting from improper use of the platform.

7. INTELLECTUAL PROPERTY
All content, features and technology of BigDogg are owned by BigDogg and may not be copied or used without written permission.

8. CHANGES
We reserve the right to amend these terms. Material changes will be announced by email at least 30 days in advance.

9. GOVERNING LAW
These terms are governed by Dutch law.

10. CONTACT
For questions: info@bigdogg.nl''';
    }
  }

  Widget _reqRow(bool met, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Icon(met ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 14, color: met ? BigDoggTheme.success : BigDoggTheme.lightTextHint),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, color: met ? BigDoggTheme.success : BigDoggTheme.lightTextSecondary)),
    ]),
  );

  Widget _feeRow(IconData icon, String method, String fee, String note, {Color? feeColor}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Container(width: 32, height: 32,
          decoration: BoxDecoration(color: BigDoggTheme.teal800.withOpacity(0.07), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: BigDoggTheme.teal700)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(method, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: BigDoggTheme.lightTextPrimary)),
        Text(note, style: const TextStyle(fontSize: 11, color: BigDoggTheme.lightTextSecondary)),
      ])),
      Text(fee, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: feeColor ?? BigDoggTheme.teal800)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final isNl = context.watch<AppProvider>().language == 'nl';
    final appProvider = context.watch<AppProvider>();

    if (_loading) return const Center(child: CircularProgressIndicator());

    final sub = _subscription;
    final status = sub?['status'] ?? '';
    final isActive = sub?['is_active'] ?? false;
    final daysLeft = sub?['days_left'] ?? 0;

    Color statusColor;
    String statusText;
    String statusDetail;
    if (status == 'trial') {
      statusColor = daysLeft > 5 ? BigDoggTheme.success : BigDoggTheme.warning;
      statusText = isNl ? 'Gratis proefperiode' : 'Free Trial';
      statusDetail = daysLeft > 0
          ? (isNl ? '$daysLeft dagen resterend' : '$daysLeft days remaining')
          : (isNl ? 'Proefperiode verlopen' : 'Trial expired');
    } else if (status == 'active') {
      statusColor = BigDoggTheme.success;
      statusText = isNl ? 'Actief' : 'Active';
      statusDetail = isNl ? 'Betaald abonnement actief' : 'Paid subscription active';
    } else {
      statusColor = BigDoggTheme.error;
      statusText = isNl ? 'Verlopen' : 'Expired';
      statusDetail = isNl ? 'Verleng je abonnement' : 'Please renew your subscription';
    }

    final stripeConnected = _stripeStatus?['connected'] == true && _stripeStatus?['enabled'] == true;
    final stripeConnectedNotEnabled = _stripeStatus?['connected'] == true && _stripeStatus?['enabled'] == false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── 1. SUBSCRIPTION ───────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _subscriptionExpanded = !_subscriptionExpanded),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: BigDoggTheme.teal800, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(statusText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(statusDetail, style: TextStyle(color: statusColor, fontSize: 13)),
                ])),
                if (!isActive || status == 'trial')
                  ElevatedButton(
                    onPressed: _checkingOut ? null : _startCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white, foregroundColor: BigDoggTheme.teal800,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: _checkingOut
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(isNl ? 'Abonneren' : 'Subscribe',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                const SizedBox(width: 8),
                Icon(_subscriptionExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.white70, size: 20),
              ]),
            ),
          ),

          if (_subscriptionExpanded) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: BigDoggTheme.lightSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: BigDoggTheme.lightBorder)),
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('BigDogg Pro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: BigDoggTheme.teal800)),
                    Text('Alles voor de moderne ZZP\'er', style: TextStyle(color: BigDoggTheme.lightTextSecondary, fontSize: 13)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text('\u20ac9,99', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26, color: BigDoggTheme.teal800)),
                    Text(isNl ? 'per maand' : 'per month', style: const TextStyle(color: BigDoggTheme.lightTextSecondary, fontSize: 12)),
                  ]),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: BigDoggTheme.gold500.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(isNl ? '30 dagen gratis proberen' : '30-day free trial',
                      style: const TextStyle(color: BigDoggTheme.gold600, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                _feature('\u2713 ${isNl ? 'Onbeperkt facturen' : 'Unlimited invoices'}'),
                _feature('\u2713 ${isNl ? 'AI factuur assistent' : 'AI invoice assistant'}'),
                _feature('\u2713 ${isNl ? 'Historische factuurimport' : 'Historical invoice import'}'),
                _feature('\u2713 ${isNl ? 'Klantenbeheer' : 'Client management'}'),
                _feature('\u2713 ${isNl ? 'Uitgaven bijhouden' : 'Expense tracking'}'),
                _feature('\u2713 ${isNl ? 'Kwartaal BTW overzicht' : 'Quarterly VAT overview'}'),
                _feature('\u2713 ${isNl ? 'Jaaroverzicht financiën' : 'Annual financial overview'}'),
                _feature('\u2713 ${isNl ? 'Bonnen scannen' : 'Receipt scanning'}'),
                _feature('\u2713 ${isNl ? 'Betalen via Stripe (iDEAL, creditcard)' : 'Pay via Stripe (iDEAL, credit card)'}'),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, height: 46,
                  child: ElevatedButton(
                    onPressed: _checkingOut ? null : _startCheckout,
                    child: _checkingOut
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(isNl ? 'Start abonnement — \u20ac9,99/maand' : 'Start subscription — \u20ac9.99/month',
                            style: const TextStyle(fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 8),
                Center(child: Text(
                  isNl ? 'Altijd opzegbaar \u00b7 iDEAL en creditcard via Stripe' : 'Cancel anytime \u00b7 iDEAL and credit card via Stripe',
                  style: const TextStyle(color: BigDoggTheme.lightTextHint, fontSize: 12),
                )),
              ]),
            ),
          ],

          const SizedBox(height: 16),

          // ── 2. PROJECTS TOGGLE ────────────────────────────────────
          Container(
            decoration: BoxDecoration(color: BigDoggTheme.lightSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: BigDoggTheme.lightBorder)),
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isNl ? 'Projecten' : 'Projects',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: BigDoggTheme.lightTextPrimary)),
                const SizedBox(height: 2),
                Text(isNl ? 'Koppel facturen en kosten aan projecten.' : 'Link invoices and expenses to projects.',
                    style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextSecondary)),
              ])),
              Switch(value: appProvider.projectsEnabled, onChanged: (val) => appProvider.setProjectsEnabled(val), activeColor: BigDoggTheme.teal800),
            ]),
          ),

          const SizedBox(height: 16),

          // ── 3. STRIPE CONNECT ─────────────────────────────────────
          Container(
            decoration: BoxDecoration(color: BigDoggTheme.lightSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: BigDoggTheme.lightBorder)),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isNl ? 'Stripe betaalaccount' : 'Stripe payment account',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: BigDoggTheme.teal800)),
              const SizedBox(height: 4),
              Text(
                isNl
                    ? 'Koppel je Stripe account om betaallinks en QR-codes te genereren op je facturen.'
                    : 'Connect your Stripe account to generate payment links and QR codes on your invoices.',
                style: const TextStyle(fontSize: 13, color: BigDoggTheme.lightTextSecondary),
              ),
              const SizedBox(height: 12),
              if (_loadingStripe)
                const Center(child: CircularProgressIndicator())
              else if (stripeConnected) ...[
                Row(children: [
                  const Icon(Icons.check_circle, color: BigDoggTheme.success, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    isNl ? 'Stripe account gekoppeld en actief' : 'Stripe account connected and active',
                    style: const TextStyle(color: BigDoggTheme.success, fontWeight: FontWeight.w600),
                  )),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openingDashboard ? null : () => _openStripeDashboard(isNl),
                    icon: _openingDashboard
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.open_in_new, size: 16),
                    label: Text(isNl ? 'Stripe instellingen openen' : 'Open Stripe settings'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BigDoggTheme.teal800,
                      side: const BorderSide(color: BigDoggTheme.teal800),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isNl
                      ? 'Bekijk je uitbetalingen, transacties en accountgegevens via het Stripe Express dashboard. Betaalmethoden worden centraal beheerd via het BigDogg platform.'
                      : 'View your payouts, transactions and account details via the Stripe Express dashboard. Payment methods are managed centrally via the BigDogg platform.',
                  style: const TextStyle(fontSize: 11, color: BigDoggTheme.lightTextSecondary),
                ),
              ] else if (stripeConnectedNotEnabled) ...[
                Row(children: [
                  const Icon(Icons.warning_amber, color: BigDoggTheme.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    isNl ? 'Account gekoppeld maar onboarding nog niet voltooid.' : 'Account connected but onboarding not complete.',
                    style: const TextStyle(color: BigDoggTheme.warning, fontSize: 13),
                  )),
                ]),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: OutlinedButton(
                  onPressed: _connectingStripe ? null : () => _connectStripe(isNl),
                  child: Text(isNl ? 'Onboarding afronden' : 'Complete onboarding'),
                )),
              ] else
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  onPressed: _connectingStripe ? null : () => _connectStripe(isNl),
                  icon: _connectingStripe
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.link, color: Colors.white),
                  label: Text(isNl ? 'Koppel Stripe account' : 'Connect Stripe account',
                      style: const TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: BigDoggTheme.teal800),
                )),

              const SizedBox(height: 12),

              // ── Stripe fees dropdown ─────────────────────────────
              GestureDetector(
                onTap: () => setState(() => _stripeFeeExpanded = !_stripeFeeExpanded),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(color: BigDoggTheme.lightBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: BigDoggTheme.lightBorder)),
                  child: Row(children: [
                    const Icon(Icons.info_outline, size: 15, color: BigDoggTheme.lightTextSecondary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      isNl ? 'Stripe transactiekosten — tik om te bekijken' : 'Stripe transaction fees — tap to view',
                      style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextSecondary, fontWeight: FontWeight.w500),
                    )),
                    Icon(_stripeFeeExpanded ? Icons.expand_less : Icons.expand_more, size: 16, color: BigDoggTheme.lightTextSecondary),
                  ]),
                ),
              ),

              if (_stripeFeeExpanded) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: BigDoggTheme.lightBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: BigDoggTheme.lightBorder)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(isNl ? 'Kosten per betaalmethode (Stripe NL)' : 'Fees per payment method (Stripe NL)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: BigDoggTheme.teal800)),
                    const SizedBox(height: 10),
                    _feeRow(Icons.account_balance_outlined, 'iDEAL', '€0,29', isNl ? 'Vaste vergoeding per transactie' : 'Fixed fee per transaction', feeColor: BigDoggTheme.success),
                    const Divider(height: 12),
                    _feeRow(Icons.credit_card_outlined, isNl ? 'Creditcard (NL/EU)' : 'Credit card (NL/EU)', '1,5% + €0,25', 'Visa, Mastercard, AmEx'),
                    const Divider(height: 12),
                    _feeRow(Icons.credit_card_outlined, isNl ? 'Creditcard (internationaal)' : 'Credit card (international)', '1,5% + 3,25% + €0,25', isNl ? 'Kaart van buiten NL/EU' : 'Card issued outside NL/EU', feeColor: BigDoggTheme.warning),
                    const Divider(height: 12),
                    _feeRow(Icons.phone_iphone_outlined, 'Apple Pay / Google Pay', isNl ? 'Zelfde als creditcard' : 'Same as credit card', isNl ? 'Tarief hangt af van onderliggende kaart' : 'Rate depends on the underlying card'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: BigDoggTheme.warningBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: BigDoggTheme.warning.withOpacity(0.3))),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.info_outline, size: 14, color: BigDoggTheme.warning),
                        const SizedBox(width: 6),
                        Expanded(child: Text(
                          isNl
                              ? 'Deze kosten zijn van Stripe, niet van BigDogg. Je ontvangt het factuurbedrag minus de transactiekosten op je Stripe account. Tarieven kunnen wijzigen — check stripe.com/pricing voor de meest actuele informatie.'
                              : 'These fees are charged by Stripe, not BigDogg. You receive the invoice amount minus transaction fees in your Stripe account. Rates may change — check stripe.com/pricing for the most up-to-date information.',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.5),
                        )),
                      ]),
                    ),
                  ]),
                ),
              ],
            ]),
          ),

          const SizedBox(height: 16),

          // ── 4. CHANGE PASSWORD ────────────────────────────────────
          Container(
            decoration: BoxDecoration(color: BigDoggTheme.lightSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: BigDoggTheme.lightBorder)),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isNl ? 'Wachtwoord wijzigen' : 'Change password',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: BigDoggTheme.teal800)),
              const SizedBox(height: 12),
              if (_passwordError != null)
                Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: BigDoggTheme.errorBg, borderRadius: BorderRadius.circular(8)),
                    child: Text(_passwordError!, style: const TextStyle(color: BigDoggTheme.error, fontSize: 13))),
              if (_passwordSuccess != null)
                Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: BigDoggTheme.successBg, borderRadius: BorderRadius.circular(8)),
                    child: Text(_passwordSuccess!, style: const TextStyle(color: BigDoggTheme.success, fontSize: 13))),
              TextField(
                controller: _newPasswordController, obscureText: _obscureNew, onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: isNl ? 'Nieuw wachtwoord' : 'New password',
                  suffixIcon: ExcludeFocus(child: IconButton(
                    icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  )),
                ),
              ),
              const SizedBox(height: 12),
              if (_newPasswordController.text.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: BigDoggTheme.lightBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: BigDoggTheme.lightBorder)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _reqRow(_pwHasLength, isNl ? 'Minimaal 8 tekens' : 'At least 8 characters'),
                    _reqRow(_pwHasUpper, isNl ? 'Minimaal één hoofdletter' : 'At least one uppercase letter'),
                    _reqRow(_pwHasNumber, isNl ? 'Minimaal één cijfer' : 'At least one number'),
                    if (_confirmPasswordController.text.isNotEmpty)
                      _reqRow(_pwMatches, isNl ? 'Wachtwoorden komen overeen' : 'Passwords match'),
                  ]),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _confirmPasswordController, obscureText: _obscureConfirm, onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: isNl ? 'Wachtwoord bevestigen' : 'Confirm password',
                  suffixIcon: ExcludeFocus(child: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  )),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: _changingPassword ? null : () => _changePassword(isNl),
                child: _changingPassword
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(isNl ? 'Wachtwoord opslaan' : 'Save password'),
              )),
            ]),
          ),

          const SizedBox(height: 16),

          // ── 5a. INVITE A FRIEND ───────────────────────────────────
          _buildReferralSection(isNl),

          const SizedBox(height: 16),

          // ── 5. RESTART WALKTHROUGH ────────────────────────────────
          Container(
            decoration: BoxDecoration(color: BigDoggTheme.lightSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: BigDoggTheme.lightBorder)),
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isNl ? 'Rondleiding' : 'App tour',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: BigDoggTheme.lightTextPrimary)),
                const SizedBox(height: 2),
                Text(isNl ? 'Bekijk de rondleiding van alle functies opnieuw.' : 'Watch the walkthrough of all features again.',
                    style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextSecondary)),
              ])),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _restartWalkthrough(isNl),
                icon: const Icon(Icons.play_circle_outline, size: 16),
                label: Text(isNl ? 'Starten' : 'Start'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BigDoggTheme.teal800,
                  side: const BorderSide(color: BigDoggTheme.teal800),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          // ── 6. DELETE ACCOUNT ─────────────────────────────────────
          Container(
            decoration: BoxDecoration(color: BigDoggTheme.lightSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: BigDoggTheme.error.withOpacity(0.3))),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isNl ? 'Account verwijderen' : 'Delete account',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: BigDoggTheme.error)),
              const SizedBox(height: 6),
              Text(isNl ? 'Verwijder je account en alle bijbehorende gegevens permanent.' : 'Permanently delete your account and all associated data.',
                  style: const TextStyle(fontSize: 13, color: BigDoggTheme.lightTextSecondary)),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: OutlinedButton(
                onPressed: () => _deleteAccount(isNl),
                style: OutlinedButton.styleFrom(foregroundColor: BigDoggTheme.error, side: const BorderSide(color: BigDoggTheme.error)),
                child: Text(isNl ? 'Account verwijderen' : 'Delete my account'),
              )),
            ]),
          ),

          const SizedBox(height: 24),

          // ── 7. TERMS ──────────────────────────────────────────────
          Center(child: TextButton.icon(
            onPressed: () => _showTerms(context, isNl),
            icon: const Icon(Icons.description_outlined, size: 16, color: BigDoggTheme.lightTextSecondary),
            label: Text(isNl ? 'Algemene Voorwaarden' : 'Terms & Conditions',
                style: const TextStyle(color: BigDoggTheme.lightTextSecondary, fontSize: 13)),
          )),
          const SizedBox(height: 8),
          Center(child: Text('BigDogg v1.0 \u00b7 info@bigdogg.nl',
              style: const TextStyle(fontSize: 11, color: BigDoggTheme.lightTextHint))),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _feature(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 14, color: BigDoggTheme.lightTextPrimary)),
  );

  Widget _buildReferralSection(bool isNl) {
    final code = _referralStats?['code'] as String?;
    final hasCode = code != null;
    final signups = (_referralStats?['signups'] as int?) ?? 0;
    final converted = (_referralStats?['converted'] as int?) ?? 0;
    final link = hasCode ? 'https://bigdogg.nl/#/register?ref=$code' : null;

    return Container(
      decoration: BoxDecoration(
        color: BigDoggTheme.teal800,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: BigDoggTheme.gold500,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.card_giftcard_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isNl ? 'Nodig een vriend uit' : 'Invite a friend',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isNl
                ? 'Stuur een vriend. Zij krijgen 30 dagen gratis. Jij ook.'
                : 'Send a friend. They get 30 days free. So do you.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),

          if (hasCode) ...[
            // Link box + copy button
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      link!,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed:
                        _loadingReferral ? null : () => _copyReferralLink(isNl),
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: Text(isNl ? 'Kopieer' : 'Copy',
                        style: const TextStyle(fontSize: 12.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BigDoggTheme.gold500,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _referralStat(
                  value: signups.toString(),
                  label: isNl ? 'Vrienden aangemeld' : 'Friends signed up',
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _referralStat(
                  value: converted.toString(),
                  label: isNl ? 'Actief abonnement' : 'Paid subscription',
                  gold: true,
                )),
              ],
            ),
          ] else ...[
            // No code yet — single big actionable button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loadingReferral
                    ? null
                    : () => _generateReferralLink(isNl),
                icon: _loadingReferral
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.link_rounded, size: 18),
                label: Text(
                  _loadingReferral
                      ? (isNl ? 'Bezig…' : 'Working…')
                      : (isNl
                          ? 'Maak mijn uitnodigingslink'
                          : 'Create my invite link'),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BigDoggTheme.gold500,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _referralStat({
    required String value,
    required String label,
    bool gold = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: gold ? BigDoggTheme.gold400 : Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}