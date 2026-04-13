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
  bool _importing = false;
  List<String> _importFileNames = [];
  List<Uint8List> _importFilesBytes = [];
  Map<String, dynamic>? _importResult;
  String? _success;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
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

  Future<void> _pickFiles(bool isNl, {bool camera = false}) async {
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
            _importFilesBytes = bytes;
            _importFileNames = names;
            _importResult = null;
          });
        }
        completer.complete();
      });
      await completer.future;
    }
  }

  Future<void> _runImport(bool isNl) async {
    if (_importFilesBytes.isEmpty) return;
    setState(() {
      _importing = true;
      _importResult = null;
      _error = null;
    });

    final result = await InvoicesService.importInvoices(
      filesBytes: _importFilesBytes,
      fileNames: _importFileNames,
    );

    setState(() {
      _importing = false;
      if (result['success']) {
        _importResult = result;
        _importFilesBytes = [];
        _importFileNames = [];
      } else {
        _error = result['message'];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isNl = context.watch<AppProvider>().language == 'nl';

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
                Text(
                    isNl ? 'Bedrijfsgegevens' : 'Business details',
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
                _inputField(
                    _addressController, isNl ? 'Adres' : 'Address'),
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

          // Import old invoices
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
                  isNl
                      ? 'Oude facturen importeren'
                      : 'Import old invoices',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: BigDoggTheme.teal800),
                ),
                const SizedBox(height: 4),
                Text(
                  isNl
                      ? 'Upload PDF facturen of screenshots van je vorige boekhoudprogramma. Ze worden toegevoegd aan je jaaroverzicht.'
                      : 'Upload PDF invoices or screenshots from your previous accounting tool. They will be added to your annual overview.',
                  style: const TextStyle(
                      fontSize: 13, color: BigDoggTheme.lightTextSecondary),
                ),
                const SizedBox(height: 12),

                // Two buttons — camera and files
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _importing
                            ? null
                            : () => _pickFiles(isNl, camera: true),
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: Text(isNl ? 'Camera' : 'Camera',
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _importing
                            ? null
                            : () => _pickFiles(isNl, camera: false),
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: Text(isNl ? 'Bestanden' : 'Files',
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ),

                if (_importFileNames.isNotEmpty) ...[
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
                          '${_importFileNames.length} ${isNl ? 'bestand(en) geselecteerd' : 'file(s) selected'}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: BigDoggTheme.teal800),
                        ),
                        const SizedBox(height: 6),
                        ..._importFileNames.map((name) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.insert_drive_file,
                                      size: 14, color: BigDoggTheme.teal700),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color:
                                              BigDoggTheme.lightTextSecondary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
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
                      onPressed:
                          _importing ? null : () => _runImport(isNl),
                      icon: _importing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.cloud_upload),
                      label: Text(_importing
                          ? (isNl ? 'Importeren...' : 'Importing...')
                          : (isNl ? 'Importeren' : 'Import')),
                    ),
                  ),
                ],

                if (_importResult != null) ...[
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
                              '${_importResult!['total_imported']} ${isNl ? 'facturen geïmporteerd' : 'invoices imported'}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: BigDoggTheme.success),
                            ),
                          ],
                        ),
                        if ((_importResult!['total_failed'] as int) > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${_importResult!['total_failed']} ${isNl ? 'mislukt' : 'failed'}',
                            style: const TextStyle(
                                color: BigDoggTheme.error, fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 8),
                        ...(_importResult!['imported'] as List)
                            .map((inv) => Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    '• ${inv['client_name']} — €${inv['total']} (${inv['date']})',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color:
                                            BigDoggTheme.lightTextSecondary),
                                  ),
                                )),
                      ],
                    ),
                  ),
                ],
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