import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/feature_flags.dart';
import '../services/subscription_service.dart';
import '../services/local_storage_service.dart';
import '../services/invoices_service.dart';
import '../services/expenses_service.dart';
import '../services/overview_service.dart';
import '../widgets/subscription_web_widget.dart';
import '../services/auth_service.dart';
import '../services/referral_service.dart';
import '../services/banking_service.dart';
import '../services/expenses_service.dart';
import '../services/accountants_service.dart';
import '../services/api_config.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../services/payments_service.dart';
import '../services/profile_service.dart';
import '../services/web_io.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Anchor for the trial-banner "Refer friends" CTA, which jumps to
  // Settings and auto-scrolls to the referral section.
  final GlobalKey _referralAnchor = GlobalKey();

  Map<String, dynamic>? _subscription;
  bool _loading = true;
  bool _stripeFeeExpanded = false;

  Map<String, dynamic>? _stripeStatus;
  bool _loadingStripe = false;
  bool _connectingStripe = false;
  bool _openingDashboard = false;

  // Bank (TrueLayer) state
  Map<String, dynamic>? _bankStatus;
  bool _loadingBank = true;
  bool _connectingBank = false;
  bool _disconnectingBank = false;
  bool _importingStatement = false;
  bool _parsingStatement = false;

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

  // Accountant access-link state (links the owner created to grant
  // accountants temporary read-only access — no accountant account needed).
  List<Map<String, dynamic>> _accountantLinks = [];
  bool _loadingAccountants = true;
  bool _invitingAccountant = false;

  // Invoice send preferences — currently just one toggle for whether the
  // Stripe payment link is included by default.
  bool _defaultExcludePaymentLink = false;
  bool _savingPaymentPref = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _loadStripeStatus();
    _loadReferralStats();
    _loadBankStatus();
    _loadAccountants();
    _loadInvoicePrefs();
  }

  Future<void> _loadInvoicePrefs() async {
    final result = await ProfileService.getProfile();
    if (!mounted) return;
    if (result['success'] == true && result['profile'] is Map) {
      final p = result['profile'] as Map;
      setState(() {
        _defaultExcludePaymentLink =
            p['default_exclude_payment_link'] == true;
      });
    }
  }

  Future<void> _setDefaultExcludePaymentLink(bool value, bool isNl) async {
    setState(() {
      _defaultExcludePaymentLink = value;
      _savingPaymentPref = true;
    });
    final result =
        await ProfileService.saveProfile(defaultExcludePaymentLink: value);
    if (!mounted) return;
    setState(() => _savingPaymentPref = false);
    if (result['success'] != true) {
      // Revert on failure so the UI doesn't lie about what's saved.
      setState(() => _defaultExcludePaymentLink = !value);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: BigDoggTheme.error,
        content: Text(isNl
            ? 'Voorkeur opslaan mislukt'
            : 'Failed to save preference'),
      ));
    }
  }

  Future<void> _loadAccountants() async {
    setState(() => _loadingAccountants = true);
    final all = await AccountantsService.listInvites();
    if (!mounted) return;
    final now = DateTime.now();
    // Active = not revoked, not expired.
    final active = all.where((r) {
      if (r['used'] == true) return false;
      final expStr = r['expires_at']?.toString();
      if (expStr == null) return true;
      try {
        return DateTime.parse(expStr).isAfter(now);
      } catch (_) {
        return true;
      }
    }).toList();
    setState(() {
      _accountantLinks = active;
      _loadingAccountants = false;
    });
  }

  Future<void> _inviteAccountant(bool isNl) async {
    final emailController = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isNl ? 'Accountant toegang geven' : 'Grant accountant access'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isNl
                  ? 'Vul het e-mailadres van je accountant in. Hij of zij krijgt een mail met een directe link naar een leesbare portal — 14 dagen geldig, geen BigDogg-account nodig.'
                  : 'Enter your accountant\'s email. They get a direct link to a read-only portal — 14 days valid, no BigDogg account needed.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: isNl ? 'E-mailadres' : 'Email',
                hintText: 'naam@boekhouder.nl',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isNl ? 'Annuleren' : 'Cancel')),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, emailController.text.trim()),
            child: Text(isNl ? 'Versturen' : 'Send'),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty) return;
    if (!email.contains('@')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: BigDoggTheme.error,
        content: Text(isNl ? 'Ongeldig e-mailadres' : 'Invalid email'),
      ));
      return;
    }
    setState(() => _invitingAccountant = true);
    final result = await AccountantsService.invite(email);
    if (!mounted) return;
    setState(() => _invitingAccountant = false);
    if (result['ok'] == true) {
      _loadAccountants();
      final emailSent = result['email_sent'] == true;
      final acceptUrl = (result['accept_url'] ?? '').toString();
      await _showInviteResultDialog(
        isNl: isNl,
        email: email,
        acceptUrl: acceptUrl,
        emailSent: emailSent,
      );
    } else {
      // Long duration + an action so the user actually sees what broke —
      // common case is the SQL migration not yet run in Supabase, which
      // returns a postgrest "table not found" error.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: BigDoggTheme.error,
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
        content: Text(isNl
            ? 'Kon uitnodiging niet versturen: ${result['error']}'
            : 'Could not send invitation: ${result['error']}'),
      ));
    }
  }

  Future<void> _showInviteResultDialog({
    required bool isNl,
    required String email,
    required String acceptUrl,
    required bool emailSent,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(
            emailSent ? Icons.check_circle : Icons.warning_amber_rounded,
            color: emailSent ? BigDoggTheme.success : BigDoggTheme.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(emailSent
                ? (isNl ? 'Uitnodiging verstuurd' : 'Invitation sent')
                : (isNl ? 'Uitnodiging aangemaakt' : 'Invitation created')),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              emailSent
                  ? (isNl
                      ? 'We hebben een e-mail gestuurd naar $email met een knop om de uitnodiging te accepteren.'
                      : 'We sent an email to $email with a button to accept the invitation.')
                  : (isNl
                      ? 'De uitnodiging is aangemaakt, maar de e-mail kon niet verstuurd worden. Deel de onderstaande link direct met je accountant:'
                      : 'The invitation was created, but the email could not be sent. Share the link below directly with your accountant:'),
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: BigDoggTheme.lightBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: BigDoggTheme.lightBorder),
              ),
              child: Row(children: [
                Expanded(
                  child: SelectableText(
                    acceptUrl,
                    style: const TextStyle(
                        fontSize: 12,
                        color: BigDoggTheme.teal800,
                        fontFamily: 'monospace'),
                  ),
                ),
                IconButton(
                  tooltip: isNl ? 'Kopiëren' : 'Copy',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: acceptUrl));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      backgroundColor: BigDoggTheme.success,
                      duration: const Duration(seconds: 2),
                      content: Text(isNl ? 'Link gekopieerd' : 'Link copied'),
                    ));
                  },
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Text(
              isNl
                  ? 'De link is 14 dagen geldig.'
                  : 'The link is valid for 14 days.',
              style: const TextStyle(
                  fontSize: 11, color: BigDoggTheme.lightTextSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isNl ? 'Sluiten' : 'Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _revokeAccountantLink(
      String token, String emailLabel, bool isNl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isNl ? 'Link intrekken?' : 'Revoke link?'),
        content: Text(
          isNl
              ? 'De portal-link naar $emailLabel werkt hierna niet meer. Deze actie kan niet ongedaan gemaakt worden — geef opnieuw toegang door een nieuwe uitnodiging te versturen.'
              : 'The portal link to $emailLabel will stop working. This cannot be undone — send a fresh invite to grant access again.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isNl ? 'Annuleren' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: BigDoggTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isNl ? 'Intrekken' : 'Revoke'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    // Optimistic UI: drop the row from local state immediately so the
    // user sees it disappear. If the backend call later fails, we
    // restore the row and surface an error.
    final removedRow = _accountantLinks.firstWhere(
      (r) => r['token']?.toString() == token,
      orElse: () => <String, dynamic>{},
    );
    final removedIndex = _accountantLinks.indexOf(removedRow);
    if (removedIndex >= 0) {
      setState(() => _accountantLinks.removeAt(removedIndex));
    }
    final ok = await AccountantsService.cancelInvite(token);
    if (!mounted) return;
    if (ok) {
      _loadAccountants();
    } else {
      // Restore the row at its original position and tell the user.
      if (removedIndex >= 0 && removedRow.isNotEmpty) {
        setState(() => _accountantLinks.insert(removedIndex, removedRow));
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: BigDoggTheme.error,
        content: Text(isNl ? 'Intrekken mislukt' : 'Revoke failed'),
      ));
    }
  }

  Future<void> _extendAccountantLink(String token, bool isNl) async {
    final ok = await AccountantsService.extendInvite(token);
    if (!mounted) return;
    if (ok) {
      _loadAccountants();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: BigDoggTheme.success,
        duration: const Duration(seconds: 2),
        content: Text(
            isNl ? 'Link verlengd met 14 dagen' : 'Link extended by 14 days'),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: BigDoggTheme.error,
        content: Text(isNl ? 'Verlengen mislukt' : 'Extend failed'),
      ));
    }
  }

  Future<void> _copyAccountantLink(String url, bool isNl) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: BigDoggTheme.success,
      duration: const Duration(seconds: 2),
      content: Text(isNl ? 'Link gekopieerd' : 'Link copied'),
    ));
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
    final result = await ReferralService.generateCode();
    if (!mounted) return;
    if (result.ok) {
      final code = result.code!;
      final stats = await ReferralService.getStats();
      if (!mounted) return;
      setState(() {
        _referralStats = stats['code'] != null
            ? stats
            : {..._referralStats ?? const {}, 'code': code};
        _loadingReferral = false;
      });
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
      final detail = result.error ?? 'Unknown error';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isNl
            ? 'Kon link niet aanmaken: $detail'
            : 'Could not create link: $detail'),
        duration: const Duration(seconds: 8),
        backgroundColor: BigDoggTheme.error,
      ));
      // ignore: avoid_print
      print('[referral] generate failed: $detail');
    }
  }

  Future<void> _copyReferralLink(bool isNl) async {
    final code = _referralStats?['code'] as String?;
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

  Future<void> _loadBankStatus() async {
    setState(() => _loadingBank = true);
    final result = await BankingService.getStatus();
    if (!mounted) return;
    setState(() {
      _loadingBank = false;
      _bankStatus = result;
    });
  }

  Future<void> _connectBank(bool isNl) async {
    setState(() => _connectingBank = true);
    final result = await BankingService.connect();
    setState(() => _connectingBank = false);
    if (!mounted) return;

    if (result['success'] == true && result['link_url'] != null) {
      final url = Uri.parse(result['link_url']);
      // canLaunchUrl returns false-negatives on web for valid https URLs, so
      // we skip the gate and call launchUrl directly. On web we use
      // platformDefault (same tab) — externalApplication can be popup-blocked.
      try {
        await launchUrl(
          url,
          mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
          webOnlyWindowName: kIsWeb ? '_self' : null,
        );
      } catch (e) {
        if (!mounted) return;
        await Clipboard.setData(ClipboardData(text: url.toString()));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(isNl
              ? 'Kon de bankpagina niet openen — link is gekopieerd, plak in browser'
              : 'Could not open the bank page — link copied, paste in your browser'),
          backgroundColor: BigDoggTheme.error,
        ));
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(result['message']?.toString() ??
            (isNl
                ? 'Kan bank koppeling niet starten'
                : 'Could not start bank connection')),
        backgroundColor: BigDoggTheme.error,
      ));
    }
  }

  Future<void> _disconnectBank(bool isNl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isNl ? 'Koppeling verwijderen?' : 'Remove connection?'),
        content: Text(isNl
            ? 'Je bankrekening wordt losgekoppeld van BigDogg. Bestaande gegevens blijven bewaard.'
            : 'Your bank account will be disconnected from BigDogg. Existing data is kept.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isNl ? 'Annuleren' : 'Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: BigDoggTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isNl ? 'Verwijderen' : 'Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _disconnectingBank = true);
    final result = await BankingService.disconnect();
    if (!mounted) return;
    setState(() => _disconnectingBank = false);
    if (result['success'] == true) {
      _loadBankStatus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isNl ? 'Loskoppelen mislukt' : 'Disconnect failed'),
        backgroundColor: BigDoggTheme.error,
      ));
    }
  }

  Future<void> _importBankStatement(bool isNl) async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isNl
            ? 'Importeren werkt momenteel via bigdogg.nl op je computer'
            : 'Import currently works via bigdogg.nl on your computer'),
      ));
      return;
    }
    final picked = await pickFiles(
      accept: '.sta,.940,.mt940,.txt,.xml,.camt,.pdf,application/xml,text/plain,application/pdf',
      multiple: false,
    );
    if (picked == null || picked.isEmpty) return;
    final file = picked.first;

    setState(() => _importingStatement = true);
    final result = await BankingService.importStatement(
      fileBytes: file.bytes,
      fileName: file.name,
    );
    if (!mounted) return;
    setState(() => _importingStatement = false);

    if (result['success'] == true) {
      final imported = result['imported'] ?? 0;
      final autoLinked = result['auto_linked'] ?? 0;
      final suggested = result['suggested'] ?? 0;
      final fmt = (result['format'] ?? '').toString().toUpperCase();
      final summary = isNl
          ? '$fmt geïmporteerd: $imported transacties, $autoLinked automatisch gekoppeld, $suggested voorstellen'
          : '$fmt imported: $imported transactions, $autoLinked auto-linked, $suggested suggestions';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: BigDoggTheme.success,
        duration: const Duration(seconds: 6),
        content: Text(summary),
      ));
      _loadBankStatus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: BigDoggTheme.error,
        duration: const Duration(seconds: 6),
        content: Text(result['message']?.toString() ??
            (isNl ? 'Import mislukt' : 'Import failed')),
      ));
    }
  }

  // ── Bank statement PDF → Claude parse → import selected as expenses ──
  Future<void> _parseStatementPdf(bool isNl) async {
    final picked = await pickFiles(
      accept: '.pdf,application/pdf',
      multiple: false,
    );
    if (picked == null || picked.isEmpty) return;
    final file = picked.first;

    setState(() => _parsingStatement = true);
    final result = await BankingService.parseStatement(
      fileBytes: file.bytes,
      fileName: file.name,
    );
    if (!mounted) return;
    setState(() => _parsingStatement = false);

    final count = (result['count'] as int?) ?? 0;
    if (result['success'] != true || count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: BigDoggTheme.error,
        duration: const Duration(seconds: 6),
        content: Text(isNl
            ? 'Geen transacties gevonden. Controleer of dit een bankafschrift is.'
            : 'No transactions found. Check that this is a bank statement.'),
      ));
      return;
    }

    final transactions = ((result['transactions'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
    final bank = (result['bank'] ?? 'unknown').toString();
    if (!mounted) return;
    _showStatementSheet(transactions, bank, isNl);
  }

  void _showStatementSheet(
      List<Map<String, dynamic>> transactions, String bank, bool isNl) {
    // Pre-select outgoing (negative) lines — those are the expenses.
    final selected = <int>{
      for (var i = 0; i < transactions.length; i++)
        if (((transactions[i]['amount'] as num?) ?? 0) < 0) i,
    };
    bool importing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          Future<void> importSelected() async {
            if (selected.isEmpty) return;
            setSheet(() => importing = true);
            int ok = 0;
            for (final i in selected) {
              final tx = transactions[i];
              final amount = ((tx['amount'] as num?) ?? 0).toDouble().abs();
              if (amount <= 0) continue;
              final res = await ExpensesService.createExpense(
                description: (tx['description'] ?? '').toString().isEmpty
                    ? (isNl ? 'Banktransactie' : 'Bank transaction')
                    : tx['description'].toString(),
                // Bank lines are gross; treat as ex-BTW with 0% so the
                // figure isn't silently inflated. The user can adjust the
                // BTW per expense afterwards.
                amountExBtw: amount,
                btwRate: 0,
                category: 'general',
                expenseDate: (tx['date'] ?? '').toString().isEmpty
                    ? null
                    : tx['date'].toString(),
              );
              if (res['success'] == true || res['offline'] == true) ok++;
            }
            if (!mounted) return;
            Navigator.pop(sheetCtx);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              backgroundColor: BigDoggTheme.success,
              duration: const Duration(seconds: 4),
              content: Text(isNl
                  ? '$ok kosten geïmporteerd'
                  : '$ok expenses imported'),
            ));
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, scrollController) => Container(
              decoration: const BoxDecoration(
                color: BigDoggTheme.lightSurface,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: BigDoggTheme.lightBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                    child: Row(children: [
                      const Icon(Icons.account_balance_outlined,
                          size: 20, color: BigDoggTheme.teal800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isNl
                                  ? '${transactions.length} transacties gevonden'
                                  : '${transactions.length} transactions found',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: BigDoggTheme.teal800),
                            ),
                            if (bank.isNotEmpty && bank != 'unknown')
                              Text(bank,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color:
                                          BigDoggTheme.lightTextSecondary)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: transactions.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 4),
                      itemBuilder: (_, i) {
                        final tx = transactions[i];
                        final amount =
                            ((tx['amount'] as num?) ?? 0).toDouble();
                        final isOut = amount < 0;
                        final checked = selected.contains(i);
                        return InkWell(
                          onTap: () => setSheet(() {
                            if (checked) {
                              selected.remove(i);
                            } else {
                              selected.add(i);
                            }
                          }),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            decoration: BoxDecoration(
                              color: checked
                                  ? BigDoggTheme.teal800.withOpacity(0.06)
                                  : null,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: checked,
                                  visualDensity: VisualDensity.compact,
                                  onChanged: (_) => setSheet(() {
                                    if (checked) {
                                      selected.remove(i);
                                    } else {
                                      selected.add(i);
                                    }
                                  }),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (tx['description'] ?? '').toString(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: BigDoggTheme
                                              .lightTextPrimary),
                                    ),
                                    Text(
                                      (tx['date'] ?? '').toString(),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: BigDoggTheme
                                              .lightTextSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${isOut ? '-' : '+'} € ${amount.abs().toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isOut
                                      ? BigDoggTheme.error
                                      : BigDoggTheme.success,
                                ),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                    decoration: const BoxDecoration(
                      border: Border(
                          top: BorderSide(
                              color: BigDoggTheme.lightBorder)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            (selected.isEmpty || importing)
                                ? null
                                : importSelected,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BigDoggTheme.teal800,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: importing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(
                                isNl
                                    ? 'Importeer geselecteerde (${selected.length})'
                                    : 'Import selected (${selected.length})',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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

  void _restartWalkthrough() async {
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
Het abonnement bedraagt €11,99 per maand of €119,88 per jaar (€9,99 effectief per maand). Na een gratis proefperiode van 30 dagen wordt er overgegaan op een betaald abonnement, tenzij je vóór het einde van de proefperiode opzegt. Opzegging kan op elk moment via de instellingen in de app. Je behoudt toegang tot het einde van de lopende betaalperiode.

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
The subscription fee is €11.99 per month or €119.88 per year (effectively €9.99 / month). After a 30-day free trial, a paid subscription begins unless cancelled before the end of the trial. You may cancel at any time via the settings in the app.

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

  String _formatConnectedAt(String? raw, bool isNl) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      String two(int v) => v.toString().padLeft(2, '0');
      return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
    } catch (_) {
      return raw;
    }
  }

  Widget _buildAccountantCard(bool isNl) {
    return Container(
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.support_agent_outlined,
                size: 18, color: BigDoggTheme.teal800),
            const SizedBox(width: 8),
            Text(isNl ? 'Mijn accountant' : 'My accountant',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: BigDoggTheme.teal800)),
          ]),
          const SizedBox(height: 4),
          Text(
            isNl
                ? 'Stuur je accountant een directe portal-link — geen BigDogg-account nodig, 14 dagen geldig, alleen-lezen toegang tot facturen, kosten en BTW.'
                : 'Send your accountant a direct portal link — no BigDogg account needed, 14 days valid, read-only access to invoices, expenses and VAT.',
            style: const TextStyle(
                fontSize: 13, color: BigDoggTheme.lightTextSecondary),
          ),
          const SizedBox(height: 12),
          if (_loadingAccountants)
            const Center(child: CircularProgressIndicator())
          else ...[
            if (_accountantLinks.isNotEmpty) ...[
              Text(
                isNl ? 'Actieve toegangslinks' : 'Active access links',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: BigDoggTheme.lightTextSecondary),
              ),
              const SizedBox(height: 6),
              ..._accountantLinks.map((link) =>
                  _accountantLinkTile(link, isNl)),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _invitingAccountant
                    ? null
                    : () => _inviteAccountant(isNl),
                icon: _invitingAccountant
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.person_add_alt_1,
                        size: 16, color: Colors.white),
                label: Text(
                  isNl
                      ? 'Accountant toegang geven'
                      : 'Grant accountant access',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BigDoggTheme.teal800,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _accountantLinkTile(Map<String, dynamic> link, bool isNl) {
    final email = (link['email'] ?? '').toString();
    final token = (link['token'] ?? '').toString();
    final expRaw = link['expires_at']?.toString();
    String daysLabel = '';
    if (expRaw != null && expRaw.isNotEmpty) {
      try {
        final exp = DateTime.parse(expRaw);
        final diff = exp.difference(DateTime.now()).inDays;
        if (diff < 0) {
          daysLabel = isNl ? 'Verlopen' : 'Expired';
        } else if (diff == 0) {
          daysLabel = isNl ? 'Verloopt vandaag' : 'Expires today';
        } else {
          daysLabel = isNl
              ? 'Nog $diff dag${diff == 1 ? '' : 'en'}'
              : '$diff day${diff == 1 ? '' : 's'} left';
        }
      } catch (_) {}
    }
    final portalUrl = '${ApiConfig.baseUrl}/a/$token';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: BigDoggTheme.lightBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.link, size: 16, color: BigDoggTheme.teal700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                email,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: BigDoggTheme.lightTextPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (daysLabel.isNotEmpty)
              Text(daysLabel,
                  style: const TextStyle(
                      fontSize: 11,
                      color: BigDoggTheme.lightTextSecondary)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            TextButton.icon(
              onPressed: () => _copyAccountantLink(portalUrl, isNl),
              style: TextButton.styleFrom(
                  foregroundColor: BigDoggTheme.teal700,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              icon: const Icon(Icons.copy, size: 14),
              label: Text(isNl ? 'Kopieer' : 'Copy',
                  style: const TextStyle(fontSize: 11)),
            ),
            TextButton.icon(
              onPressed: () => _extendAccountantLink(token, isNl),
              style: TextButton.styleFrom(
                  foregroundColor: BigDoggTheme.teal700,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              icon: const Icon(Icons.schedule, size: 14),
              label: Text(isNl ? '+14d' : '+14d',
                  style: const TextStyle(fontSize: 11)),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () =>
                  _revokeAccountantLink(token, email, isNl),
              style: TextButton.styleFrom(
                  foregroundColor: BigDoggTheme.error,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              icon: const Icon(Icons.block, size: 14),
              label: Text(isNl ? 'Intrekken' : 'Revoke',
                  style: const TextStyle(fontSize: 11)),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildBankCard(bool isNl) {
    final connected = _bankStatus?['connected'] == true;
    final connectedAt = _bankStatus?['connected_at']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.account_balance_outlined,
                size: 18, color: BigDoggTheme.teal800),
            const SizedBox(width: 8),
            Text(isNl ? 'Bankrekening' : 'Bank account',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: BigDoggTheme.teal800)),
          ]),
          const SizedBox(height: 4),
          Text(
            isNl
                ? 'Koppel je Nederlandse bankrekening om transacties automatisch in te lezen.'
                : 'Connect your Dutch bank account to import transactions automatically.',
            style: const TextStyle(
                fontSize: 13, color: BigDoggTheme.lightTextSecondary),
          ),
          const SizedBox(height: 12),
          // Bank-connect is live for everyone. (Previously dimmed +
          // tap-blocked behind a "coming soon" pill during beta.)
          Opacity(
            opacity: 1.0,
            child: AbsorbPointer(
              absorbing: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_loadingBank)
                    const Center(child: CircularProgressIndicator())
                  else if (connected) ...[
            Row(children: [
              const Icon(Icons.check_circle,
                  color: BigDoggTheme.success, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isNl
                          ? 'Bankrekening gekoppeld'
                          : 'Bank account connected',
                      style: const TextStyle(
                          color: BigDoggTheme.success,
                          fontWeight: FontWeight.w600),
                    ),
                    if (connectedAt != null && connectedAt.isNotEmpty)
                      Text(
                        '${isNl ? 'Sinds' : 'Since'} ${_formatConnectedAt(connectedAt, isNl)}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: BigDoggTheme.lightTextSecondary),
                      ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/transactions'),
                icon: const Icon(Icons.receipt_long, size: 16, color: Colors.white),
                label: Text(
                  isNl ? 'Bekijk transacties' : 'View transactions',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BigDoggTheme.teal800,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _disconnectingBank
                    ? null
                    : () => _disconnectBank(isNl),
                icon: _disconnectingBank
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.link_off, size: 16),
                label: Text(
                    isNl ? 'Verwijder koppeling' : 'Remove connection'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BigDoggTheme.error,
                  side: const BorderSide(color: BigDoggTheme.error),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _connectingBank ? null : () => _connectBank(isNl),
                icon: _connectingBank
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.account_balance, color: Colors.white),
                label: Text(
                    isNl
                        ? 'Koppel je bankrekening'
                        : 'Connect your bank account',
                    style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: BigDoggTheme.teal800),
              ),
            ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isNl
                ? 'Beveiligd via TrueLayer (PSD2). BigDogg krijgt alleen leestoegang tot je transacties.'
                : 'Secured via TrueLayer (PSD2). BigDogg only gets read access to your transactions.',
            style: const TextStyle(
                fontSize: 11, color: BigDoggTheme.lightTextHint),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: BigDoggTheme.lightBorder),
          const SizedBox(height: 14),
          Row(children: [
            const Icon(Icons.upload_file_outlined,
                size: 16, color: BigDoggTheme.teal800),
            const SizedBox(width: 6),
            Text(
              isNl ? 'Of importeer een bankafschrift' : 'Or import a bank statement',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: BigDoggTheme.teal800,
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            isNl
                ? 'PDF, MT940 of CAMT.053 — direct te downloaden vanuit je internetbankieren.'
                : 'PDF, MT940 or CAMT.053 — downloadable from your bank\'s online portal.',
            style: const TextStyle(
                fontSize: 12, color: BigDoggTheme.lightTextSecondary),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _importingStatement ? null : () => _importBankStatement(isNl),
              icon: _importingStatement
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.attach_file, size: 16),
              label: Text(isNl ? 'Bestand kiezen' : 'Choose file'),
              style: OutlinedButton.styleFrom(
                foregroundColor: BigDoggTheme.teal800,
                side: const BorderSide(color: BigDoggTheme.teal700),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // PDF → Claude parse → pick which lines to import as expenses.
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _parsingStatement ? null : () => _parseStatementPdf(isNl),
              icon: _parsingStatement
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
              label: Text(
                _parsingStatement
                    ? (isNl ? 'PDF wordt gelezen…' : 'Reading PDF…')
                    : (isNl ? 'PDF afschrift inlezen (AI)' : 'Scan PDF statement (AI)'),
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: BigDoggTheme.teal800,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNl = context.watch<AppProvider>().language == 'nl';
    final appProvider = context.watch<AppProvider>();

    // Consume a pending "scroll to referrals" request — comes from the
    // dashboard trial-warning banner's "Refer friends" CTA.
    if (appProvider.scrollToReferralPending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appProvider.consumeScrollToReferral();
        final ctx = _referralAnchor.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            alignment: 0.1,
          );
        }
      });
    }

    if (_loading) return const Center(child: CircularProgressIndicator());

    final sub = _subscription;
    final status = sub?['status'] ?? '';
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: BigDoggTheme.teal800, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(statusText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(statusDetail, style: TextStyle(color: statusColor, fontSize: 13)),
              ])),
              _buildTrialChip(isNl, status, (daysLeft as num).toInt()),
            ]),
          ),

          const SizedBox(height: 8),
          _buildSubscriptionActionRow(isNl, status),

          const SizedBox(height: 16),

          // ── 2a. QUOTES TOGGLE ─────────────────────────────────────
          Container(
            decoration: BoxDecoration(color: BigDoggTheme.lightSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: BigDoggTheme.lightBorder)),
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isNl ? 'Offertes' : 'Quotes',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: BigDoggTheme.lightTextPrimary)),
                const SizedBox(height: 2),
                Text(isNl ? 'Toon de offertes-tab naast je facturen.' : 'Show the quotes tab next to your invoices.',
                    style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextSecondary)),
              ])),
              Switch(value: appProvider.quotesEnabled, onChanged: (val) => appProvider.setQuotesEnabled(val), activeColor: BigDoggTheme.teal800),
            ]),
          ),

          const SizedBox(height: 16),

          // ── 2b. PROJECTS TOGGLE ───────────────────────────────────
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
                const SizedBox(height: 14),
                const Divider(height: 1, color: BigDoggTheme.lightBorder),
                const SizedBox(height: 8),
                // Global default for the per-send "Verstuur zonder
                // betaallink" checkbox. Stored on the profile.
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isNl
                                ? 'Standaard geen betaallink meesturen'
                                : 'Exclude payment link by default',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: BigDoggTheme.teal800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isNl
                                ? 'Per factuur kun je dit alsnog aan- of uitzetten.'
                                : 'You can still toggle it per invoice before sending.',
                            style: const TextStyle(
                                fontSize: 11,
                                color: BigDoggTheme.lightTextSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (_savingPaymentPref)
                      const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      Switch(
                        value: _defaultExcludePaymentLink,
                        onChanged: (v) =>
                            _setDefaultExcludePaymentLink(v, isNl),
                        activeColor: BigDoggTheme.teal800,
                      ),
                  ],
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

          // ── 3b. BANK CONNECTION (TrueLayer) ────────────────────────
          // The live PSD2 connect is dimmed + disabled with a subtle
          // "Binnenkort" pill (see _buildBankCard); the PDF/statement
          // import below it stays fully usable.
          _buildBankCard(isNl),

          const SizedBox(height: 16),

          // ── 3c. ACCOUNTANT PORTAL ─────────────────────────────────
          _buildAccountantCard(isNl),

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
          KeyedSubtree(
            key: _referralAnchor,
            child: _buildReferralSection(isNl),
          ),

          const SizedBox(height: 16),

          // ── 5b. LOCAL DATA / LAST SYNC ────────────────────────────
          _buildLastSyncRow(isNl),

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
                onPressed: () => _restartWalkthrough(),
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
          Center(child: Text('BigDogg v1.0 · info@bigdogg.nl',
              style: const TextStyle(fontSize: 11, color: BigDoggTheme.lightTextHint))),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  bool _refreshingLocalData = false;

  /// "Local data — Updated at HH:MM" with a refresh button that
  /// re-pulls invoices / expenses / clients / dashboard from the
  /// server in parallel. Reads the oldest lastSync across all keys so
  /// the row reflects the worst-case cache freshness.
  Widget _buildLastSyncRow(bool isNl) {
    final oldest = LocalStorageService.oldestLastSync();
    final value = _formatLastSync(oldest, isNl);
    return Container(
      decoration: BoxDecoration(
        color: BigDoggTheme.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BigDoggTheme.lightBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isNl ? 'Lokale gegevens' : 'Local data',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: BigDoggTheme.lightTextPrimary),
                ),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 12,
                        color: BigDoggTheme.lightTextSecondary)),
              ],
            ),
          ),
          IconButton(
            tooltip: isNl ? 'Nu vernieuwen' : 'Refresh now',
            icon: _refreshingLocalData
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            BigDoggTheme.teal800)),
                  )
                : const Icon(Icons.refresh_rounded,
                    color: BigDoggTheme.teal800),
            onPressed: _refreshingLocalData
                ? null
                : () => _forceRefreshLocalData(isNl),
          ),
        ],
      ),
    );
  }

  String _formatLastSync(DateTime? t, bool isNl) {
    if (t == null) {
      return isNl ? 'Nog geen offline gegevens' : 'No offline data yet';
    }
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 60) {
      return isNl ? 'Zojuist bijgewerkt' : 'Just updated';
    }
    final sameDay = t.year == now.year &&
        t.month == now.month &&
        t.day == now.day;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    if (sameDay) {
      return isNl ? 'Bijgewerkt om $hh:$mm' : 'Updated at $hh:$mm';
    }
    final monthsNl = const [
      'jan', 'feb', 'mrt', 'apr', 'mei', 'jun',
      'jul', 'aug', 'sep', 'okt', 'nov', 'dec',
    ];
    final monthsEn = const [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final mon = (isNl ? monthsNl : monthsEn)[t.month - 1];
    return isNl
        ? 'Bijgewerkt op ${t.day} $mon'
        : 'Updated on ${t.day} $mon';
  }

  Future<void> _forceRefreshLocalData(bool isNl) async {
    setState(() => _refreshingLocalData = true);
    // Drop in-memory caches so the service calls hit the network. The
    // persistent Hive cache stays intact until each fetch overwrites it.
    LocalStorageService.remove('dashboard');
    final results = await Future.wait([
      InvoicesService.getInvoices(),
      ExpensesService.getExpenses(),
      OverviewService.getQuarterlyOverview(),
    ]);
    // Persist on success; the screen-level refresh logic already does
    // this on its own reload, but doing it here too keeps Settings'
    // "last synced" honest even if the user doesn't visit those tabs.
    if (results[0]['success'] == true) {
      await LocalStorageService.save(
          'invoices', results[0]['invoices'] ?? const []);
      await LocalStorageService.saveLastSync('invoices', DateTime.now());
    }
    if (results[1]['success'] == true) {
      await LocalStorageService.save(
          'expenses', results[1]['expenses'] ?? const []);
      await LocalStorageService.saveLastSync('expenses', DateTime.now());
    }
    if (results[2]['success'] == true) {
      await LocalStorageService.save(
          'dashboard', results[2]['overview']);
      await LocalStorageService.saveLastSync('dashboard', DateTime.now());
    }
    if (!mounted) return;
    setState(() => _refreshingLocalData = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: BigDoggTheme.success,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      content: Text(isNl ? 'Lokale gegevens bijgewerkt' : 'Local data refreshed'),
    ));
  }

  /// Trial countdown / status chip rendered inside the subscription
  /// card. Colour-coded by urgency:
  ///   - active paid:        teal
  ///   - trial, > 7 days:    teal
  ///   - trial, <= 7 days:   orange
  ///   - trial, <= 3 days:   red
  ///   - trial expired:      red (tappable → paywall)
  Widget _buildTrialChip(bool isNl, String status, int daysLeft) {
    if (status == 'active') {
      return _chip(
        label: isNl ? 'Actief abonnement' : 'Active subscription',
        bg: BigDoggTheme.teal700,
      );
    }
    if (status == 'trial' && daysLeft > 0) {
      Color bg;
      if (daysLeft <= 3) {
        bg = const Color(0xFFF44336);
      } else if (daysLeft <= 7) {
        bg = const Color(0xFFFF9800);
      } else {
        bg = BigDoggTheme.teal700;
      }
      return _chip(
        label: isNl
            ? 'Proefperiode: nog $daysLeft dagen'
            : 'Trial: $daysLeft days remaining',
        bg: bg,
      );
    }
    // Trial expired or no subscription — tappable, opens paywall.
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => showPaywallModal(context, isNl),
      child: _chip(
        label: isNl ? 'Proefperiode verlopen' : 'Trial expired',
        bg: const Color(0xFFF44336),
      ),
    );
  }

  Widget _chip({required String label, required Color bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Permanent, non-intrusive path to the user's billing on bigdogg.nl.
  /// Active users get the Stripe customer portal; trial/expired users
  /// get the pricing page (both with email pre-filled). Always visible
  /// in Settings so the user never has to hunt for it.
  Widget _buildSubscriptionActionRow(bool isNl, String status) {
    final isActive = status == 'active';
    final label = isActive
        ? (isNl ? 'Abonnement beheren' : 'Manage subscription')
        : (kIsReaderMode
            ? (isNl
                ? 'Beheer je account op bigdogg.nl'
                : 'Manage your account at bigdogg.nl')
            : (isNl ? 'Abonnement starten' : 'Start subscription'));
    final subtitle = isActive
        ? (isNl
            ? 'Wijzig je betaalmethode of zeg op'
            : 'Change payment method or cancel')
        : (kIsReaderMode
            ? (isNl
                ? 'Maak je account online compleet'
                : 'Complete your account online')
            : (isNl
                ? 'Vanaf €9,99 / maand · 30 dagen gratis'
                : 'From €9.99 / month · 30-day free trial'));
    final icon = isActive
        ? Icons.tune_rounded
        : (kIsReaderMode
            ? Icons.public_rounded
            : Icons.workspace_premium_rounded);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (isActive) {
          openManageSubscription(context, isNl);
        } else {
          showPaywallModal(context, isNl);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BigDoggTheme.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BigDoggTheme.lightBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: BigDoggTheme.teal800.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: BigDoggTheme.teal800, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: BigDoggTheme.lightTextPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12,
                          color: BigDoggTheme.lightTextSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: BigDoggTheme.lightTextHint, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralSection(bool isNl) {
    final code = _referralStats?['code'] as String?;
    final hasCode = code != null;
    final signups = (_referralStats?['signups'] as int?) ?? 0;
    final bonusEarned = (_referralStats?['bonus_months_earned'] as int?) ?? 0;
    final bonusMax = (_referralStats?['bonus_months_max'] as int?) ?? 3;
    final nextThreshold = (bonusEarned >= bonusMax) ? null : ((bonusEarned + 1) * 2);
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
                ? '2 vrienden aangemeld = 1 maand BigDogg Pro gratis. Tot maximaal 3 maanden.'
                : '2 friends signed up = 1 free month of BigDogg Pro. Up to 3 months total.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),

          if (hasCode) ...[
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
                  value: '$bonusEarned / $bonusMax',
                  label: isNl ? 'Gratis maanden' : 'Free months',
                  gold: true,
                )),
              ],
            ),
            if (nextThreshold != null) ...[
              const SizedBox(height: 10),
              Text(
                isNl
                    ? 'Nog ${nextThreshold - signups} aanmelding${(nextThreshold - signups) == 1 ? "" : "en"} tot je volgende gratis maand.'
                    : '${nextThreshold - signups} more signup${(nextThreshold - signups) == 1 ? "" : "s"} until your next free month.',
                style: const TextStyle(
                  color: BigDoggTheme.gold400,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Text(
                isNl
                    ? 'Maximum bereikt — bedankt voor het delen!'
                    : 'Maximum reached — thanks for sharing!',
                style: const TextStyle(
                  color: BigDoggTheme.gold400,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ] else ...[
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
