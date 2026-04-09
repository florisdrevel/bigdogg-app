import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/clients_service.dart';
import '../app_theme.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  List<dynamic> _clients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() => _loading = true);
    final result = await ClientsService.getClients();
    setState(() {
      _loading = false;
      if (result['success']) _clients = result['clients'];
    });
  }

  Future<void> _deleteClient(String id) async {
    await ClientsService.deleteClient(id);
    _loadClients();
  }

  Future<void> _generateInviteLink() async {
    final result = await ClientsService.createInvite();
    if (result['success']) {
      final url = result['invite_url'];
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite link copied to clipboard!')),
        );
      }
    }
  }

  void _showAddClient() {
    final contactController = TextEditingController();
    final emailController = TextEditingController();
    final companyController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final postcodeController = TextEditingController();
    final cityController = TextEditingController();
    final btwController = TextEditingController();
    final kvkController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Client'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: contactController,
                decoration: const InputDecoration(labelText: 'Contact name *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email *'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: companyController,
                decoration: const InputDecoration(labelText: 'Company name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: postcodeController,
                      decoration: const InputDecoration(labelText: 'Postcode'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: cityController,
                      decoration: const InputDecoration(labelText: 'City'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: btwController,
                decoration: const InputDecoration(labelText: 'BTW number'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: kvkController,
                decoration: const InputDecoration(labelText: 'KVK number'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (contactController.text.isEmpty ||
                  emailController.text.isEmpty)
                return;
              Navigator.pop(context);
              await ClientsService.createClient(
                contactName: contactController.text.trim(),
                email: emailController.text.trim(),
                companyName: companyController.text.trim(),
                phone: phoneController.text.trim(),
                address: addressController.text.trim(),
                postcode: postcodeController.text.trim(),
                city: cityController.text.trim(),
                btwNumber: btwController.text.trim(),
                kvkNumber: kvkController.text.trim(),
              );
              _loadClients();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddClient,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildInviteBanner(),
                Expanded(
                  child: _clients.isEmpty
                      ? const EmptyState(
                          icon: Icons.people_outline_rounded,
                          title: 'No clients yet',
                          subtitle: 'Tap + to add or use the invite link above',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: _clients.length,
                          itemBuilder: (context, index) {
                            final c = _clients[index];
                            return _ClientCard(
                              client: c,
                              onDelete: () => _deleteClient(c['id']),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildInviteBanner() {
    return GestureDetector(
      onTap: _generateInviteLink,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.navy.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.link_rounded,
                color: AppColors.navy,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invite client',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Copy onboarding link to clipboard',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.copy_outlined,
              color: AppColors.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  final dynamic client;
  final VoidCallback onDelete;

  const _ClientCard({required this.client, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name = client['contact_name'] as String;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card,
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppGradients.navySubtle,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (client['company_name'] != null &&
                    client['company_name'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      client['company_name'],
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    client['email'],
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.danger,
              size: 20,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
