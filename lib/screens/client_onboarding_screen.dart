import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_config.dart';
import '../theme.dart';

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
      setState(() => _error = 'Naam en e-mailadres zijn verplicht');
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
        setState(() => _error = data['detail'] ?? 'Er is iets misgegaan');
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Verbindingsfout. Probeer het opnieuw.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
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
        Image.asset('assets/images/logo.png', width: 140, height: 140),
        const SizedBox(height: 24),
        const Icon(Icons.check_circle, color: BigDoggTheme.success, size: 64),
        const SizedBox(height: 16),
        const Text(
          'Gelukt!',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: BigDoggTheme.teal800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Je gegevens zijn succesvol ingediend. De freelancer neemt binnenkort contact met je op.',
          textAlign: TextAlign.center,
          style: TextStyle(color: BigDoggTheme.lightTextSecondary, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Image.asset('assets/images/logo.png', width: 140, height: 140),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Vul je gegevens in',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: BigDoggTheme.teal800),
          ),
        ),
        const SizedBox(height: 4),
        const Center(
          child: Text(
            'Je freelancer heeft je uitgenodigd via BigDogg',
            style: TextStyle(color: BigDoggTheme.lightTextSecondary, fontSize: 14),
          ),
        ),
        const SizedBox(height: 24),
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
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BigDoggTheme.lightSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BigDoggTheme.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Persoonlijke gegevens',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: BigDoggTheme.teal800)),
              const SizedBox(height: 16),
              _field(_contactNameController, 'Volledige naam *'),
              const SizedBox(height: 12),
              _field(_emailController, 'E-mailadres *', keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _field(_phoneController, 'Telefoonnummer', keyboardType: TextInputType.phone),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BigDoggTheme.lightSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BigDoggTheme.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bedrijfsgegevens (optioneel)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: BigDoggTheme.teal800)),
              const SizedBox(height: 16),
              _field(_companyController, 'Bedrijfsnaam'),
              const SizedBox(height: 12),
              _field(_addressController, 'Adres'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _field(_postcodeController, 'Postcode')),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: _field(_cityController, 'Stad')),
                ],
              ),
              const SizedBox(height: 12),
              _field(_btwController, 'BTW-nummer'),
              const SizedBox(height: 12),
              _field(_kvkController, 'KVK-nummer'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Gegevens indienen', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Powered by BigDogg · bigdogg.nl',
            style: const TextStyle(color: BigDoggTheme.lightTextHint, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _field(TextEditingController controller, String label, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
    );
  }
}