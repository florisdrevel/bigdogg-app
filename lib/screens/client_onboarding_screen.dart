import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_config.dart';
import '../app_theme.dart';

class ClientOnboardingScreen extends StatefulWidget {
  final String token;
  const ClientOnboardingScreen({super.key, required this.token});

  @override
  State<ClientOnboardingScreen> createState() => _ClientOnboardingScreenState();
}

class _ClientOnboardingScreenState extends State<ClientOnboardingScreen> {
  final _contactNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _postcodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _btwController = TextEditingController();
  final _kvkController = TextEditingController();
  bool _loading = false;
  bool _submitted = false;
  String? _error;

  Future<void> _submit() async {
    if (_contactNameController.text.isEmpty ||
        _emailController.text.isEmpty) {
      setState(() => _error = 'Name and email are required');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/v1/clients/onboarding/${widget.token}',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contact_name': _contactNameController.text.trim(),
          'email': _emailController.text.trim(),
          'company_name': _companyController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'postcode': _postcodeController.text.trim(),
          'city': _cityController.text.trim(),
          'btw_number': _btwController.text.trim(),
          'kvk_number': _kvkController.text.trim(),
        }),
      );

      setState(() => _loading = false);

      if (response.statusCode == 200) {
        setState(() => _submitted = true);
      } else {
        final data = jsonDecode(response.body);
        setState(() => _error = data['detail'] ?? 'Something went wrong');
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Connection error. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _submitted ? _buildSuccess() : _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: AppColors.success,
            size: 44,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "You're all set!",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Your details have been submitted successfully.\nThe freelancer will be in touch soon.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo
        const Text(
          'Bigdogg',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Please fill in your details below',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 28),

        if (_error != null) ErrorBox(_error!),

        // Personal details
        _FormSection(
          title: 'Personal details',
          icon: Icons.person_outline_rounded,
          children: [
            _field(_contactNameController, 'Full name *'),
            const SizedBox(height: 12),
            _field(
              _emailController,
              'Email address *',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _field(
              _phoneController,
              'Phone number',
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Business details
        _FormSection(
          title: 'Business details',
          icon: Icons.business_outlined,
          subtitle: 'Optional',
          children: [
            _field(_companyController, 'Company name'),
            const SizedBox(height: 12),
            _field(_addressController, 'Address'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _field(_postcodeController, 'Postcode')),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: _field(_cityController, 'City')),
              ],
            ),
            const SizedBox(height: 12),
            _field(_btwController, 'BTW number'),
            const SizedBox(height: 12),
            _field(_kvkController, 'KVK number'),
          ],
        ),
        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Submit details',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _FormSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  final List<Widget> children;

  const _FormSection({
    required this.title,
    required this.icon,
    this.subtitle,
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
              if (subtitle != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgPage,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}
