import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/profile_service.dart';
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
    setState(() { _saving = true; _error = null; _success = null; });
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

  @override
  Widget build(BuildContext context) {
    final isNl = context.watch<AppProvider>().language == 'nl';

    return Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      appBar: AppBar(
        backgroundColor: BigDoggTheme.lightSurface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(isNl ? 'Bedrijfsprofiel' : 'Business Profile',
            style: const TextStyle(color: BigDoggTheme.lightTextPrimary, fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: BigDoggTheme.lightBorder, height: 1)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isNl
                        ? 'Deze informatie verschijnt op je facturen.'
                        : 'This information appears on your invoices.',
                    style: const TextStyle(color: BigDoggTheme.lightTextSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: BigDoggTheme.errorBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_error!, style: const TextStyle(color: BigDoggTheme.error)),
                    ),
                  if (_success != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: BigDoggTheme.successBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_success!, style: const TextStyle(color: BigDoggTheme.success)),
                    ),
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: BigDoggTheme.teal800)),
                        const SizedBox(height: 16),
                        _inputField(_businessNameController, isNl ? 'Bedrijfsnaam' : 'Business name'),
                        const SizedBox(height: 12),
                        _inputField(_fullNameController, isNl ? 'Volledige naam' : 'Full name'),
                        const SizedBox(height: 12),
                        _inputField(_addressController, isNl ? 'Adres' : 'Address'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _inputField(_postcodeController, isNl ? 'Postcode' : 'Postcode')),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: _inputField(_cityController, isNl ? 'Stad' : 'City')),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: BigDoggTheme.teal800)),
                        const SizedBox(height: 16),
                        _inputField(_kvkController, isNl ? 'KVK-nummer' : 'KVK number'),
                        const SizedBox(height: 12),
                        _inputField(_btwController, isNl ? 'BTW-nummer' : 'BTW number'),
                        const SizedBox(height: 12),
                        _inputField(_ibanController, 'IBAN'),
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
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(isNl ? 'Profiel opslaan' : 'Save Profile', style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _inputField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
    );
  }
}