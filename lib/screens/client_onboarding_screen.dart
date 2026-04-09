import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_config.dart';

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
    if (_contactNameController.text.isEmpty || _emailController.text.isEmpty) {
      setState(() => _error = 'Name and email are required');
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/clients/onboarding/${widget.token}'),
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
      backgroundColor: const Color(0xFFF8F9FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
        const Icon(Icons.check_circle, color: Color(0xFF059669), size: 80),
        const SizedBox(height: 24),
        const Text('You\'re all set!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'Your details have been submitted successfully. The freelancer will be in touch soon.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Bigdogg', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        const SizedBox(height: 8),
        const Text('Please fill in your details', style: TextStyle(fontSize: 16, color: Color(0xFF6B7280))),
        const SizedBox(height: 24),
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
            child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626))),
          ),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Personal details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                _field(_contactNameController, 'Full name *'),
                const SizedBox(height: 12),
                _field(_emailController, 'Email address *', keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _field(_phoneController, 'Phone number', keyboardType: TextInputType.phone),
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
                const Text('Business details (optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
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
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A2E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Submit', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _field(TextEditingController controller, String label, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
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