import 'package:flutter/material.dart';
import '../services/profile_service.dart';

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

  Future<void> _saveProfile() async {
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
        _success = 'Profile saved successfully';
      } else {
        _error = result['message'];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Business Profile', style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This information appears on your invoices.',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626))),
                    ),
                  if (_success != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_success!, style: const TextStyle(color: Color(0xFF065F46))),
                    ),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Business details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 16),
                          _inputField(_businessNameController, 'Business name'),
                          const SizedBox(height: 12),
                          _inputField(_fullNameController, 'Full name'),
                          const SizedBox(height: 12),
                          _inputField(_addressController, 'Address'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _inputField(_postcodeController, 'Postcode')),
                              const SizedBox(width: 12),
                              Expanded(flex: 2, child: _inputField(_cityController, 'City')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tax & Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 16),
                          _inputField(_kvkController, 'KVK number'),
                          const SizedBox(height: 12),
                          _inputField(_btwController, 'BTW number'),
                          const SizedBox(height: 12),
                          _inputField(_ibanController, 'IBAN'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1A2E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save Profile', style: TextStyle(fontSize: 16)),
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
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1A1A2E), width: 2),
        ),
      ),
    );
  }
}