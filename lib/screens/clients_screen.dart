import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/clients_service.dart';

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
          SnackBar(
            content: const Text('Invite link copied to clipboard!'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
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
              TextField(controller: contactController, decoration: const InputDecoration(labelText: 'Contact name *')),
              const SizedBox(height: 12),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email *'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              TextField(controller: companyController, decoration: const InputDecoration(labelText: 'Company name')),
              const SizedBox(height: 12),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 12),
              TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: postcodeController, decoration: const InputDecoration(labelText: 'Postcode'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: cityController, decoration: const InputDecoration(labelText: 'City'))),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: btwController, decoration: const InputDecoration(labelText: 'BTW number')),
              const SizedBox(height: 12),
              TextField(controller: kvkController, decoration: const InputDecoration(labelText: 'KVK number')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (contactController.text.isEmpty || emailController.text.isEmpty) return;
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A2E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Clients', style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: _generateInviteLink,
            icon: const Icon(Icons.link, color: Colors.white),
            label: const Text('Invite link', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddClient,
        backgroundColor: const Color(0xFF1A1A2E),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _clients.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Color(0xFFD1D5DB)),
                      SizedBox(height: 16),
                      Text('No clients yet', style: TextStyle(fontSize: 18, color: Color(0xFF6B7280))),
                      SizedBox(height: 8),
                      Text('Tap + to add or use invite link', style: TextStyle(color: Color(0xFF9CA3AF))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _clients.length,
                  itemBuilder: (context, index) {
                    final c = _clients[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF1A1A2E),
                          child: Text(
                            (c['contact_name'] as String).substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(c['contact_name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (c['company_name'] != null && c['company_name'].toString().isNotEmpty)
                              Text(c['company_name'], style: const TextStyle(color: Color(0xFF6B7280))),
                            Text(c['email'], style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                          onPressed: () => _deleteClient(c['id']),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}