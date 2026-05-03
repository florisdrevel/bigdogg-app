import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/web_io.dart';
import '../services/profile_service.dart';
import '../services/invoices_service.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../services/subscription_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _businessNameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _postcodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _kvkController = TextEditingController();
  final _btwController = TextEditingController();
  final _ibanController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  // Logo
  String? _logoUrl;
  bool _uploadingLogo = false;

  // Invoice colors — null means "use BigDogg defaults". Stored as #RRGGBB.
  static const String _defaultPrimary = '#1B3A4B';
  static const String _defaultAccent = '#C9A96E';
  String _invoicePrimary = _defaultPrimary;
  String _invoiceAccent = _defaultAccent;

  // Invoice import
  bool _importingInvoices = false;
  List<String> _invoiceFileNames = [];
  List<Uint8List> _invoiceFilesBytes = [];
  Map<String, dynamic>? _invoiceImportResult;

  // Expense import
  bool _importingExpenses = false;
  List<String> _expenseFileNames = [];
  List<Uint8List> _expenseFilesBytes = [];
  Map<String, dynamic>? _expenseImportResult;

  String? _success;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  bool _isMobile() {
    if (!kIsWeb) return true;
    final ua = getUserAgent().toLowerCase();
    return ua.contains('mobile') ||
        ua.contains('android') ||
        ua.contains('iphone') ||
        ua.contains('ipad');
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    final result = await ProfileService.getProfile();
    setState(() {
      _loading = false;
      if (result['success'] && result['profile'] != null) {
        final p = result['profile'];
        _businessNameController.text = p['business_name'] ?? '';
        _fullNameController.text = p['full_name'] ?? '';
        _addressController.text = p['address'] ?? '';
        _postcodeController.text = p['postcode'] ?? '';
        _cityController.text = p['city'] ?? '';
        _kvkController.text = p['kvk_number'] ?? '';
        _btwController.text = p['btw_number'] ?? '';
        _ibanController.text = p['iban'] ?? '';
        _logoUrl = p['logo_url'];
        _invoicePrimary = (p['invoice_primary_color']?.toString() ?? '').isNotEmpty
            ? p['invoice_primary_color']
            : _defaultPrimary;
        _invoiceAccent = (p['invoice_accent_color']?.toString() ?? '').isNotEmpty
            ? p['invoice_accent_color']
            : _defaultAccent;
      }
    });
  }

  Future<void> _pickAndUploadLogo(bool isNl) async {
    final picked = await pickFiles(
      accept: 'image/png,image/jpeg,image/jpg,image/webp',
    );
    if (picked == null || picked.isEmpty) return;
    final file = picked.first;
    setState(() => _uploadingLogo = true);
    final result = await ProfileService.uploadLogo(
      bytes: file.bytes,
      fileName: file.name,
    );
    setState(() {
      _uploadingLogo = false;
      if (result['success']) {
        _logoUrl = result['logo_url'];
        _success = isNl ? 'Logo opgeslagen' : 'Logo saved';
      } else {
        _error = result['message'];
      }
    });
  }

  Future<void> _saveProfile(bool isNl) async {
    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });
    final result = await ProfileService.saveProfile(
      businessName: _businessNameController.text.trim(),
      fullName: _fullNameController.text.trim(),
      address: _addressController.text.trim(),
      postcode: _postcodeController.text.trim(),
      city: _cityController.text.trim(),
      kvkNumber: _kvkController.text.trim(),
      btwNumber: _btwController.text.trim(),
      iban: _ibanController.text.trim(),
      onboardingComplete: true,
      invoicePrimaryColor: _invoicePrimary,
      invoiceAccentColor: _invoiceAccent,
    );
    setState(() {
      _saving = false;
      if (result['success']) {
        _success = isNl ? 'Profiel opgeslagen' : 'Profile saved successfully';
      } else {
        _error = result['message'];
      }
    });
  }

  Future<void> _pickFiles(bool isNl,
      {bool camera = false, required bool forExpenses}) async {
    if (!kIsWeb) return;
    final picked = await pickFiles(
      camera: camera,
      accept: camera
          ? 'image/*'
          : 'application/pdf,.pdf,image/*,.jpg,.jpeg,.png,.webp,.heic',
      multiple: true,
    );
    if (picked == null || picked.isEmpty) return;
    final names = picked.map((p) => p.name).toList();
    final bytes = picked.map((p) => p.bytes).toList();
    setState(() {
      if (forExpenses) {
        _expenseFilesBytes = bytes;
        _expenseFileNames = names;
        _expenseImportResult = null;
      } else {
        _invoiceFilesBytes = bytes;
        _invoiceFileNames = names;
        _invoiceImportResult = null;
      }
    });
  }

  Future<void> _runInvoiceImport(bool isNl) async {
    if (_invoiceFilesBytes.isEmpty) return;
    setState(() {
      _importingInvoices = true;
      _invoiceImportResult = null;
      _error = null;
    });

    final result = await InvoicesService.importInvoices(
      filesBytes: _invoiceFilesBytes,
      fileNames: _invoiceFileNames,
    );

    if (!result['success'] && result['message'] == 'paid_tier_required') {
      setState(() => _importingInvoices = false);
      if (mounted) _showPaywallDialog(isNl);
      return;
    }

    setState(() {
      _importingInvoices = false;
      if (result['success']) {
        _invoiceImportResult = result;
        _invoiceFilesBytes = [];
        _invoiceFileNames = [];
      } else {
        _error = result['message'];
      }
    });
  }

  Future<void> _runExpenseImport(bool isNl) async {
    if (_expenseFilesBytes.isEmpty) return;
    setState(() {
      _importingExpenses = true;
      _expenseImportResult = null;
      _error = null;
    });

    final result = await InvoicesService.importExpenses(
      filesBytes: _expenseFilesBytes,
      fileNames: _expenseFileNames,
    );

    if (!result['success'] && result['message'] == 'paid_tier_required') {
      setState(() => _importingExpenses = false);
      if (mounted) _showPaywallDialog(isNl);
      return;
    }

    setState(() {
      _importingExpenses = false;
      if (result['success']) {
        _expenseImportResult = result;
        _expenseFilesBytes = [];
        _expenseFileNames = [];
      } else {
        _error = result['message'];
      }
    });
  }

  void _showPaywallDialog(bool isNl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: BigDoggTheme.teal800.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded,
                  size: 36, color: BigDoggTheme.teal800),
            ),
            const SizedBox(height: 20),
            Text(
              isNl ? 'Betaald abonnement vereist' : 'Paid plan required',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: BigDoggTheme.teal800,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isNl
                  ? 'Facturen en kosten importeren is alleen beschikbaar voor gebruikers met een betaald abonnement.'
                  : 'Importing invoices and expenses is only available on a paid plan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 16),
            _paywallFeatureRow(Icons.upload_file_outlined,
                isNl ? 'Facturen importeren' : 'Import invoices'),
            _paywallFeatureRow(Icons.receipt_long_outlined,
                isNl ? 'Kosten importeren' : 'Import expenses'),
            _paywallFeatureRow(Icons.analytics_outlined,
                isNl ? 'Jaarlijkse financiële rapporten' : 'Annual financial reports'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final result = await SubscriptionService.createCheckout();
                  if (result['success']) {
                    final url = Uri.parse(result['checkout_url']);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: BigDoggTheme.gold500,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(isNl ? 'Upgraden' : 'Upgrade',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'PlusJakartaSans'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isNl ? 'Niet nu' : 'Not now',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paywallFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: BigDoggTheme.teal800.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: BigDoggTheme.teal800),
          ),
          const SizedBox(width: 12),
          Text(text,
              style: const TextStyle(
                  fontSize: 14, color: BigDoggTheme.lightTextPrimary)),
        ],
      ),
    );
  }

  Widget _importSection({
    required bool isNl,
    required String title,
    required String description,
    required bool isMobile,
    required bool importing,
    required List<String> fileNames,
    required Map<String, dynamic>? importResult,
    required bool forExpenses,
    required VoidCallback onImport,
  }) {
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
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: BigDoggTheme.teal800)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BigDoggTheme.gold500.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: BigDoggTheme.gold500.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspace_premium_outlined,
                        size: 12, color: BigDoggTheme.gold500),
                    const SizedBox(width: 4),
                    Text(
                      isNl ? 'Betaald' : 'Paid',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: BigDoggTheme.gold500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(description,
              style: const TextStyle(
                  fontSize: 13, color: BigDoggTheme.lightTextSecondary)),
          const SizedBox(height: 12),
          Row(
            children: [
              if (isMobile) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: importing
                        ? null
                        : () => _pickFiles(isNl,
                            camera: true, forExpenses: forExpenses),
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: Text(isNl ? 'Camera' : 'Camera',
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: importing
                      ? null
                      : () => _pickFiles(isNl,
                          camera: false, forExpenses: forExpenses),
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: Text(isNl ? 'Bestanden' : 'Files',
                      style: const TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 4),
            Text(
              isNl
                  ? 'Tik op "Bestanden" en kies "Bladeren" voor alle bestandstypen.'
                  : 'Tap "Files" then choose "Browse" to access all file types.',
              style: const TextStyle(
                  fontSize: 11, color: BigDoggTheme.lightTextHint),
            ),
          ],
          if (fileNames.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: BigDoggTheme.lightBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: BigDoggTheme.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${fileNames.length} ${isNl ? 'bestand(en) geselecteerd' : 'file(s) selected'}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: BigDoggTheme.teal800),
                  ),
                  const SizedBox(height: 6),
                  ...fileNames.map((name) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.insert_drive_file,
                                size: 14, color: BigDoggTheme.teal700),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(name,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: BigDoggTheme.lightTextSecondary),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: importing ? null : onImport,
                icon: importing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload),
                label: Text(importing
                    ? (isNl ? 'Importeren...' : 'Importing...')
                    : (isNl ? 'Importeren' : 'Import')),
              ),
            ),
          ],
          if (importResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BigDoggTheme.successBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: BigDoggTheme.success, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '${importResult['total_imported']} ${isNl ? 'geïmporteerd' : 'imported'}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: BigDoggTheme.success),
                      ),
                    ],
                  ),
                  if ((importResult['total_duplicates'] ?? 0) > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.warning_amber,
                            color: BigDoggTheme.warning, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${importResult['total_duplicates']} ${isNl ? 'dubbel — al aanwezig' : 'duplicate(s) — already exist'}',
                          style: const TextStyle(
                              color: BigDoggTheme.warning, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                  if ((importResult['total_failed'] ?? 0) > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${importResult['total_failed']} ${isNl ? 'mislukt' : 'failed'}',
                      style: const TextStyle(
                          color: BigDoggTheme.error, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNl = context.watch<AppProvider>().language == 'nl';
    final isMobile = _isMobile();

    if (_loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isNl
                ? 'Deze informatie verschijnt op je facturen.'
                : 'This information appears on your invoices.',
            style: const TextStyle(
                color: BigDoggTheme.lightTextSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: BigDoggTheme.errorBg,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(_error!,
                  style: const TextStyle(color: BigDoggTheme.error)),
            ),
          if (_success != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: BigDoggTheme.successBg,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(_success!,
                  style: const TextStyle(color: BigDoggTheme.success)),
            ),

          // ── Logo upload ──────────────────────────────────────────
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
                  isNl ? 'Bedrijfslogo' : 'Company logo',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: BigDoggTheme.teal800),
                ),
                const SizedBox(height: 4),
                Text(
                  isNl
                      ? 'Je logo verschijnt linksboven op al je facturen.'
                      : 'Your logo appears top-left on all your invoices.',
                  style: const TextStyle(
                      fontSize: 13, color: BigDoggTheme.lightTextSecondary),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: BigDoggTheme.lightBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: BigDoggTheme.lightBorder),
                      ),
                      child: _logoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: Image.network(
                                _logoUrl!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.broken_image_outlined,
                                    color: BigDoggTheme.lightTextHint),
                              ),
                            )
                          : const Icon(Icons.business_outlined,
                              size: 36, color: BigDoggTheme.lightTextHint),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _uploadingLogo
                                  ? null
                                  : () => _pickAndUploadLogo(isNl),
                              icon: _uploadingLogo
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white))
                                  : const Icon(Icons.upload_outlined,
                                      size: 18),
                              label: Text(
                                _uploadingLogo
                                    ? (isNl ? 'Uploaden...' : 'Uploading...')
                                    : _logoUrl != null
                                        ? (isNl
                                            ? 'Logo wijzigen'
                                            : 'Change logo')
                                        : (isNl
                                            ? 'Logo uploaden'
                                            : 'Upload logo'),
                                style: const TextStyle(fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: BigDoggTheme.teal800,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isNl
                                ? 'PNG, JPG of WEBP · max 2MB'
                                : 'PNG, JPG or WEBP · max 2MB',
                            style: const TextStyle(
                                fontSize: 11,
                                color: BigDoggTheme.lightTextHint),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Business details ─────────────────────────────────────
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
                Text(isNl ? 'Bedrijfsgegevens' : 'Business details',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: BigDoggTheme.teal800)),
                const SizedBox(height: 16),
                _inputField(_businessNameController,
                    isNl ? 'Bedrijfsnaam' : 'Business name'),
                const SizedBox(height: 12),
                _inputField(_fullNameController,
                    isNl ? 'Volledige naam' : 'Full name'),
                const SizedBox(height: 12),
                _inputField(_addressController, isNl ? 'Adres' : 'Address'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _inputField(_postcodeController,
                            isNl ? 'Postcode' : 'Postcode')),
                    const SizedBox(width: 12),
                    Expanded(
                        flex: 2,
                        child: _inputField(
                            _cityController, isNl ? 'Stad' : 'City')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Tax & Payment ────────────────────────────────────────
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
                Text(isNl ? 'BTW & Betaling' : 'Tax & Payment',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: BigDoggTheme.teal800)),
                const SizedBox(height: 16),
                _inputField(
                    _kvkController, isNl ? 'KVK-nummer' : 'KVK number'),
                const SizedBox(height: 12),
                _inputField(
                    _btwController, isNl ? 'BTW-nummer' : 'BTW number'),
                const SizedBox(height: 12),
                _inputField(_ibanController, 'IBAN'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Invoice colors ───────────────────────────────────────
          _invoiceColorsCard(isNl),
          const SizedBox(height: 12),

          // ── Import invoices ──────────────────────────────────────
          _importSection(
            isNl: isNl,
            title: isNl ? 'Oude facturen importeren' : 'Import old invoices',
            description: isNl
                ? 'Upload PDF facturen of screenshots van je vorige boekhoudprogramma.'
                : 'Upload PDF invoices or screenshots from your previous accounting tool.',
            isMobile: isMobile,
            importing: _importingInvoices,
            fileNames: _invoiceFileNames,
            importResult: _invoiceImportResult,
            forExpenses: false,
            onImport: () => _runInvoiceImport(isNl),
          ),
          const SizedBox(height: 12),

          // ── Import expenses ──────────────────────────────────────
          _importSection(
            isNl: isNl,
            title: isNl ? 'Oude kosten importeren' : 'Import old expenses',
            description: isNl
                ? 'Upload PDF bonnen of screenshots van oude zakelijke kosten.'
                : 'Upload PDF receipts or screenshots of old business expenses.',
            isMobile: isMobile,
            importing: _importingExpenses,
            fileNames: _expenseFileNames,
            importResult: _expenseImportResult,
            forExpenses: true,
            onImport: () => _runExpenseImport(isNl),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : () => _saveProfile(isNl),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(isNl ? 'Profiel opslaan' : 'Save Profile',
                      style: const TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField(TextEditingController controller, String label) {
    return TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label));
  }

  // ─── Invoice colors ─────────────────────────────────────────
  Color _hexToColor(String hex) {
    var s = hex.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 6) s = 'FF$s';
    return Color(int.parse(s, radix: 16));
  }

  static const _swatches = <String>[
    '#1B3A4B', // BigDogg teal (default primary)
    '#C9A96E', // BigDogg gold (default accent)
    '#0F172A', // slate near-black
    '#1E40AF', // blue
    '#0E7490', // cyan
    '#15803D', // green
    '#A16207', // amber
    '#B91C1C', // red
    '#9333EA', // purple
    '#DB2777', // pink
    '#475569', // grey
    '#000000', // black
  ];

  Future<void> _pickColor(bool isNl,
      {required String current, required void Function(String) onPicked}) async {
    final ctrl = TextEditingController(text: current);
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          String selected = ctrl.text.trim();
          return AlertDialog(
            title: Text(isNl ? 'Kies een kleur' : 'Pick a color'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _swatches.map((hex) {
                      final isSelected = hex.toLowerCase() == selected.toLowerCase();
                      return GestureDetector(
                        onTap: () {
                          setSt(() => ctrl.text = hex);
                          Navigator.pop(ctx, hex);
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _hexToColor(hex),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? Colors.black : Colors.black12,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(isNl ? 'Of voer een hex-code in' : 'Or enter a hex code',
                      style: const TextStyle(
                          fontSize: 12,
                          color: BigDoggTheme.lightTextSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: ctrl,
                    decoration: const InputDecoration(
                      hintText: '#1B3A4B',
                      isDense: true,
                    ),
                    onChanged: (v) => setSt(() {}),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: Text(isNl ? 'Annuleren' : 'Cancel')),
              ElevatedButton(
                onPressed: () {
                  var v = ctrl.text.trim();
                  if (v.isEmpty) {
                    Navigator.pop(ctx, null);
                    return;
                  }
                  if (!v.startsWith('#')) v = '#$v';
                  // accept #RRGGBB only (6 hex digits after #)
                  final ok = RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(v);
                  Navigator.pop(ctx, ok ? v.toUpperCase() : null);
                },
                child: Text(isNl ? 'Opslaan' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
    if (picked != null) {
      setState(() => onPicked(picked));
    }
  }

  Widget _colorSwatchRow({
    required bool isNl,
    required String label,
    required String currentHex,
    required void Function(String) onPick,
  }) {
    return InkWell(
      onTap: () => _pickColor(isNl, current: currentHex, onPicked: onPick),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _hexToColor(currentHex),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(currentHex,
                      style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: BigDoggTheme.lightTextSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: BigDoggTheme.lightTextHint),
          ],
        ),
      ),
    );
  }

  Widget _invoiceColorsCard(bool isNl) {
    final isCustom = _invoicePrimary.toUpperCase() != _defaultPrimary ||
        _invoiceAccent.toUpperCase() != _defaultAccent;
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
          Text(isNl ? 'Factuurkleuren' : 'Invoice colors',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: BigDoggTheme.teal800)),
          const SizedBox(height: 4),
          Text(
            isNl
                ? 'Pas de kleuren op je facturen en offertes aan. Standaard zijn dit de BigDogg kleuren.'
                : 'Customise the colors on your invoices and quotes. The defaults are the BigDogg colors.',
            style: const TextStyle(
                fontSize: 13, color: BigDoggTheme.lightTextSecondary),
          ),
          const SizedBox(height: 8),
          _colorSwatchRow(
            isNl: isNl,
            label: isNl ? 'Hoofdkleur (regels)' : 'Primary (lines & text)',
            currentHex: _invoicePrimary,
            onPick: (v) => _invoicePrimary = v,
          ),
          const Divider(height: 1),
          _colorSwatchRow(
            isNl: isNl,
            label: isNl ? 'Accentkleur (totaalstreep)' : 'Accent (totals line)',
            currentHex: _invoiceAccent,
            onPick: (v) => _invoiceAccent = v,
          ),
          if (isCustom) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _invoicePrimary = _defaultPrimary;
                  _invoiceAccent = _defaultAccent;
                }),
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(
                    isNl ? 'Herstel BigDogg kleuren' : 'Reset to BigDogg colors',
                    style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: BigDoggTheme.teal700,
                  minimumSize: const Size(0, 32),
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            isNl
                ? 'Kleuren gelden voor de PDF van je facturen en offertes. Wijzigingen verschijnen op nieuwe verzendingen.'
                : 'Colors apply to the PDF of your invoices and quotes. Changes show on the next send.',
            style: const TextStyle(
                fontSize: 11, color: BigDoggTheme.lightTextHint),
          ),
        ],
      ),
    );
  }
}
