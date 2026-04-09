import 'package:flutter/material.dart';
import '../services/profile_service.dart';
import '../app_theme.dart';

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
        _success = 'Profile saved successfully';
      } else {
        _error = result['message'];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header info
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.navy.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.navy,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'This information appears on your invoices.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_error != null) ErrorBox(_error!),
                  if (_success != null) SuccessBox(_success!),

                  // Business details card
                  _FormCard(
                    title: 'Business details',
                    icon: Icons.business_outlined,
                    children: [
                      _inputField(_businessNameController, 'Business name'),
                      const SizedBox(height: 12),
                      _inputField(_fullNameController, 'Full name'),
                      const SizedBox(height: 12),
                      _inputField(_addressController, 'Address'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _inputField(
                              _postcodeController,
                              'Postcode',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _inputField(_cityController, 'City'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tax & Payment card
                  _FormCard(
                    title: 'Tax & Payment',
                    icon: Icons.account_balance_outlined,
                    children: [
                      _inputField(_kvkController, 'KVK number'),
                      const SizedBox(height: 12),
                      _inputField(_btwController, 'BTW number'),
                      const SizedBox(height: 12),
                      _inputField(_ibanController, 'IBAN'),
                    ],
                  ),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save profile',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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

class _FormCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _FormCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.navy.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.navy, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}
