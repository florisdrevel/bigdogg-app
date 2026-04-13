import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../services/profile_service.dart';
import '../services/invoices_service.dart';
import '../providers/app_provider.dart';
import '../theme.dart';

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

  // Imported invoices list
  List<dynamic> _importedInvoices = [];
  bool _loadingImported = false;

  String? _success;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadImportedInvoices();
  }

  bool _isMobile() {
    if (!kIsWeb) return true;
    final ua = html.window.navigator.userAgent.toLowerCase();
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
      }
    });
  }

  Future<void> _loadImportedInvoices() async {
    setState(() => _loadingImported = true);
    final result = await InvoicesService.getImportedInvoices();
    setState(() {
      _loadingImported = false;
      if (result['success']) _importedInvoices = result['invoices'];
    });
  }

  Future<void> _deleteImportedInvoice(String id, bool isNl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isNl ? 'Verwijderen?' : 'Delete?'),
        content: Text(isNl
            ? 'Weet je zeker dat je deze geïmporteerde factuur wilt verwijderen?'
            : 'Are you sure you want to delete this imported invoice?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isNl ? 'Annuleren' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: BigDoggTheme.error),
            child: Text(isNl ? 'Verwijderen' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await InvoicesService.deleteImportedInvoice(id);
      _loadImportedInvoices();
    }
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
    if (kIsWeb) {
      final completer = Completer<void>();
      final input = html.FileUploadInputElement();
      if (camera) {
        input.accept = 'image/*';
        input.setAttribute('capture', 'environment');
      } else {
        input.accept =
            'application/pdf,.pdf,image/*,.jpg,.jpeg,.png,.webp,.heic';
      }
      input.multiple = true;
      input.click();
      input.onChange.listen((event) async {
        final files = input.files;
        if (files != null && files.isNotEmpty) {
          final names = <String>[];
          final bytes = <Uint8List>[];
          for (final file in files) {
            final reader = html.FileReader();
            reader.readAsArrayBuffer(file);
            await reader.onLoad.first;
            bytes.add(Uint8List.fromList(reader.result as List<int>));
            names.add(file.name);
          }
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
        completer.complete();
      });
      await completer.future;
    }
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
    _loadImportedInvoices();
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
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: BigDoggTheme.teal800)),
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

          // Business details
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

          // Tax & Payment
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

          // Import invoices
          _importSection(
            isNl: isNl,
            title: isNl ? 'Oude facturen importeren' : 'Import old invoices',
            description: isNl
                ? 'Upload PDF facturen of screenshots van je vorige boekhoudprogramma. Ze worden toegevoegd aan je jaaroverzicht.'
                : 'Upload PDF invoices or screenshots from your previous accounting tool. They will be added to your annual overview.',
            isMobile: isMobile,
            importing: _importingInvoices,
            fileNames: _invoiceFileNames,
            importResult: _invoiceImportResult,
            forExpenses: false,
            onImport: () => _runInvoiceImport(isNl),
          ),
          const SizedBox(height: 12),

          // Import expenses
          _importSection(
            isNl: isNl,
            title: isNl ? 'Oude kosten importeren' : 'Import old expenses',
            description: isNl
                ? 'Upload PDF bonnen of screenshots van oude zakelijke kosten. Ze worden toegevoegd aan je kostenregistratie.'
                : 'Upload PDF receipts or screenshots of old business expenses. They will be added to your expense records.',
            isMobile: isMobile,
            importing: _importingExpenses,
            fileNames: _expenseFileNames,
            importResult: _expenseImportResult,
            forExpenses: true,
            onImport: () => _runExpenseImport(isNl),
          ),
          const SizedBox(height: 12),

          // View/delete imported invoices
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isNl
                            ? 'Geïmporteerde facturen'
                            : 'Imported invoices',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: BigDoggTheme.teal800),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: BigDoggTheme.teal700),
                      onPressed: _loadImportedInvoices,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_loadingImported)
                  const Center(child: CircularProgressIndicator())
                else if (_importedInvoices.isEmpty)
                  Text(
                    isNl
                        ? 'Geen geïmporteerde facturen.'
                        : 'No imported invoices.',
                    style: const TextStyle(
                        fontSize: 13,
                        color: BigDoggTheme.lightTextSecondary),
                  )
                else
                  ...(_importedInvoices.map((inv) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: BigDoggTheme.lightBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: BigDoggTheme.lightBorder),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    inv['invoice_number'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: BigDoggTheme.teal800),
                                  ),
                                  Text(
                                    '${inv['client_name'] ?? ''} · ${inv['invoice_date'] ?? ''}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: BigDoggTheme.lightTextSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '€${inv['total_incl_btw']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: BigDoggTheme.teal800),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: BigDoggTheme.error, size: 18),
                              onPressed: () =>
                                  _deleteImportedInvoice(inv['id'], isNl),
                            ),
                          ],
                        ),
                      ))),
              ],
            ),
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
}