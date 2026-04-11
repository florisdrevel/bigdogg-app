import 'package:flutter/material.dart';
import '../services/clients_service.dart';
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
  bool _loading = false;
  bool _submitted = false;
  bool _validating = true;
  bool _valid = false;
  bool _isNl = true;
  String? _error;

  String t(String nl, String en) => _isNl ? nl : en;

  @override
  void initState() {
    super.initState();
    _validateToken();
  }

  Future<void> _validateToken() async {
    final result = await ClientsService.validateInvite(widget.token);
    setState(() {
      _validating = false;
      _valid = result['valid'] == true;
    });
  }

  Future<void> _submit() async {
    if (_contactNameController.text.isEmpty || _emailController.text.isEmpty) {
      setState(() => _error = t('Naam en e-mail zijn verplicht', 'Name and email are required'));
      return;
    }
    setState(() { _loading = true; _error = null; });
    final result = await ClientsService.completeOnboarding(
      token: widget.token,
      contactName: _contactNameController.text.trim(),
      email: _emailController.text.trim(),
      companyName: _companyController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      postcode: _postcodeController.text.trim(),
      city: _cityController.text.trim(),
    );
    setState(() { _loading = false; });
    if (result['success']) {
      setState(() => _submitted = true);
    } else {
      setState(() => _error = result['message']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      body: _validating
          ? const Center(child: CircularProgressIndicator())
          : !_valid
              ? _buildInvalid()
              : _submitted
                  ? _buildSuccess()
                  : _buildForm(),
    );
  }

  Widget _buildInvalid() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', width: 120, height: 120),
            const SizedBox(height: 24),
            Text(
              t('Ongeldige uitnodigingslink', 'Invalid invite link'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: BigDoggTheme.teal800),
            ),
            const SizedBox(height: 8),
            Text(
              t('Deze link is verlopen of al gebruikt.', 'This link has expired or already been used.'),
              style: const TextStyle(color: BigDoggTheme.lightTextSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', width: 120, height: 120),
            const SizedBox(height: 24),
            const Icon(Icons.check_circle, color: BigDoggTheme.success, size: 64),
            const SizedBox(height: 16),
            Text(
              t('Gegevens ontvangen!', 'Details received!'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: BigDoggTheme.teal800),
            ),
            const SizedBox(height: 8),
            Text(
              t(
                'Je gegevens zijn succesvol doorgestuurd. Je wordt binnenkort toegevoegd als klant.',
                'Your details have been successfully submitted. You will be added as a client shortly.',
              ),
              style: const TextStyle(color: BigDoggTheme.lightTextSecondary, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: [
            // Language toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _isNl = !_isNl),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: BigDoggTheme.gold500.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: BigDoggTheme.gold500.withOpacity(0.4)),
                    ),
                    child: Text(
                      _isNl ? 'EN' : 'NL',
                      style: const TextStyle(color: BigDoggTheme.gold600, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Big logo
            Image.asset('assets/images/logo.png', width: 200, height: 200),
            const SizedBox(height: 8),
            const Text('BigDogg',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: BigDoggTheme.teal800)),
            const SizedBox(height: 24),
            // Form card
            Container(
              width: 420,
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: BigDoggTheme.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BigDoggTheme.lightBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('Jouw gegevens', 'Your details'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: BigDoggTheme.teal800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t('Vul je gegevens in zodat je aan de slag kunt.', 'Fill in your details to get started.'),
                    style: const TextStyle(color: BigDoggTheme.lightTextSecondary, fontSize: 14),
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
                  TextField(
                    controller: _contactNameController,
                    decoration: InputDecoration(labelText: t('Volledige naam *', 'Full name *')),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email *'),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _companyController,
                    decoration: InputDecoration(labelText: t('Bedrijfsnaam', 'Company name')),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    decoration: InputDecoration(labelText: t('Telefoonnummer', 'Phone number')),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _addressController,
                    decoration: InputDecoration(labelText: t('Adres', 'Address')),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _postcodeController,
                          decoration: InputDecoration(labelText: t('Postcode', 'Postcode')),
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _cityController,
                          decoration: InputDecoration(labelText: t('Stad', 'City')),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(t('Gegevens versturen', 'Submit details'),
                              style: const TextStyle(fontSize: 16)),
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
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}