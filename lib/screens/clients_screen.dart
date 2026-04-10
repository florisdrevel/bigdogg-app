import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/clients_service.dart';
import '../providers/app_provider.dart';
import '../theme.dart';

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

  void _showAddClient(bool isNl) {
    final contactController = TextEditingController();
    final emailController = TextEditingController();
    final companyController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final postcodeController = TextEditingController();
    final cityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isNl ? 'Klant toevoegen' : 'Add Client'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: contactController, decoration: InputDecoration(labelText: isNl ? 'Naam *' : 'Full name *')),
              const SizedBox(height: 12),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email *'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              TextField(controller: companyController, decoration: InputDecoration(labelText: isNl ? 'Bedrijfsnaam' : 'Company name')),
              const SizedBox(height: 12),
              TextField(controller: phoneController, decoration: InputDecoration(labelText: isNl ? 'Telefoonnummer' : 'Phone'), keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              TextField(controller: addressController, decoration: InputDecoration(labelText: isNl ? 'Adres' : 'Address')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: postcodeController, decoration: InputDecoration(labelText: isNl ? 'Postcode' : 'Postcode'))),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: TextField(controller: cityController, decoration: InputDecoration(labelText: isNl ? 'Stad' : 'City'))),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(isNl ? 'Annuleren' : 'Cancel')),
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
              );
              _loadClients();
            },
            child: Text(isNl ? 'Toevoegen' : 'Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyInviteLink(bool isNl) async {
    final result = await ClientsService.createInvite();
    if (result['success'] && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNl ? 'Link gekopieerd!' : 'Link copied!'),
          backgroundColor: BigDoggTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
        title: Text(isNl ? 'Klanten' : 'Clients', style: const TextStyle(color: BigDoggTheme.lightTextPrimary, fontWeight: FontWeight.w600)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: BigDoggTheme.lightBorder, height: 1)),
        actions: [
          TextButton.icon(
            onPressed: () => _copyInviteLink(isNl),
            icon: const Icon(Icons.link, color: BigDoggTheme.teal800, size: 18),
            label: Text(isNl ? 'Uitnodigen' : 'Invite link', style: const TextStyle(color: BigDoggTheme.teal800, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddClient(isNl),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _clients.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 64, color: BigDoggTheme.lightTextHint),
                      const SizedBox(height: 16),
                      Text(isNl ? 'Nog geen klanten' : 'No clients yet',
                          style: const TextStyle(fontSize: 18, color: BigDoggTheme.lightTextSecondary)),
                      const SizedBox(height: 8),
                      Text(isNl ? 'Tik + om een klant toe te voegen' : 'Tap + to add a client',
                          style: const TextStyle(color: BigDoggTheme.lightTextHint)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _clients.length,
                  itemBuilder: (context, index) {
                    final client = _clients[index];
                    final name = client['contact_name'] ?? '';
                    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: BigDoggTheme.lightSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: BigDoggTheme.lightBorder),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: BigDoggTheme.teal800,
                          child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: BigDoggTheme.lightTextPrimary)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (client['company_name'] != null && client['company_name'].toString().isNotEmpty)
                              Text(client['company_name'], style: const TextStyle(color: BigDoggTheme.lightTextSecondary, fontSize: 13)),
                            Text(client['email'] ?? '', style: const TextStyle(color: BigDoggTheme.lightTextHint, fontSize: 12)),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: BigDoggTheme.error),
                          onPressed: () async {
                            await ClientsService.deleteClient(client['id']);
                            _loadClients();
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}