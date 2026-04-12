import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/clients_service.dart';
import '../services/invoices_service.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import 'invoice_detail_screen.dart';

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

  void _openClientDetail(bool isNl, Map<String, dynamic> client) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClientDetailScreen(client: client, isNl: isNl),
      ),
    ).then((_) => _loadClients());
  }

  void _showClientDialog(bool isNl, {Map<String, dynamic>? existing}) {
    final contactController = TextEditingController(text: existing?['contact_name'] ?? '');
    final emailController = TextEditingController(text: existing?['email'] ?? '');
    final companyController = TextEditingController(text: existing?['company_name'] ?? '');
    final phoneController = TextEditingController(text: existing?['phone'] ?? '');
    final addressController = TextEditingController(text: existing?['address'] ?? '');
    final postcodeController = TextEditingController(text: existing?['postcode'] ?? '');
    final cityController = TextEditingController(text: existing?['city'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing != null
            ? (isNl ? 'Klant bewerken' : 'Edit Client')
            : (isNl ? 'Klant toevoegen' : 'Add Client')),
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
              if (existing != null) {
                await ClientsService.updateClient(
                  clientId: existing['id'],
                  contactName: contactController.text.trim(),
                  email: emailController.text.trim(),
                  companyName: companyController.text.trim(),
                  phone: phoneController.text.trim(),
                  address: addressController.text.trim(),
                  postcode: postcodeController.text.trim(),
                  city: cityController.text.trim(),
                );
              } else {
                await ClientsService.createClient(
                  contactName: contactController.text.trim(),
                  email: emailController.text.trim(),
                  companyName: companyController.text.trim(),
                  phone: phoneController.text.trim(),
                  address: addressController.text.trim(),
                  postcode: postcodeController.text.trim(),
                  city: cityController.text.trim(),
                );
              }
              _loadClients();
            },
            child: Text(existing != null
                ? (isNl ? 'Opslaan' : 'Save')
                : (isNl ? 'Toevoegen' : 'Add')),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteClient(bool isNl, Map<String, dynamic> client) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isNl ? 'Klant verwijderen' : 'Delete Client'),
        content: Text(isNl
            ? 'Weet je zeker dat je ${client['contact_name']} wilt verwijderen? Dit kan niet ongedaan worden gemaakt.'
            : 'Are you sure you want to delete ${client['contact_name']}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isNl ? 'Annuleren' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: BigDoggTheme.error),
            child: Text(isNl ? 'Verwijderen' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final result = await ClientsService.deleteClient(client['id']);
      if (result['success']) {
        _loadClients();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? (isNl ? 'Verwijderen mislukt' : 'Delete failed')),
              backgroundColor: BigDoggTheme.error,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _showInviteLink(bool isNl) async {
    final result = await ClientsService.createInvite();
    if (result['success'] && mounted) {
      final inviteUrl = result['invite_url'] as String;
      bool copied = false;
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(isNl ? 'Uitnodigingslink' : 'Invite Link'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isNl ? 'Stuur deze link naar je klant:' : 'Send this link to your client:',
                  style: const TextStyle(color: BigDoggTheme.lightTextSecondary, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BigDoggTheme.lightBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: BigDoggTheme.lightBorder),
                  ),
                  child: SelectableText(
                    inviteUrl,
                    style: const TextStyle(fontSize: 12, color: BigDoggTheme.teal800, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: inviteUrl));
                      setDialogState(() => copied = true);
                    },
                    icon: Icon(copied ? Icons.check : Icons.copy, size: 16),
                    label: Text(copied
                        ? (isNl ? 'Gekopieerd!' : 'Copied!')
                        : (isNl ? 'Kopieer link' : 'Copy link')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: copied ? BigDoggTheme.success : BigDoggTheme.teal800,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isNl ? 'Sluiten' : 'Close'),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNl = context.watch<AppProvider>().language == 'nl';

    return Stack(
      children: [
        _loading
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
                          onTap: () => _openClientDetail(isNl, client),
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: BigDoggTheme.teal800),
                                onPressed: () => _showClientDialog(isNl, existing: client),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: BigDoggTheme.error),
                                onPressed: () => _deleteClient(isNl, client),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        Positioned(
          bottom: 88,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'invite_fab',
            onPressed: () => _showInviteLink(isNl),
            backgroundColor: BigDoggTheme.teal800,
            elevation: 2,
            child: const Icon(Icons.share_outlined, color: Colors.white),
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'add_fab',
            onPressed: () => _showClientDialog(isNl),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}


// ─── Client Detail Screen ─────────────────────────────────────────────────────

class ClientDetailScreen extends StatefulWidget {
  final Map<String, dynamic> client;
  final bool isNl;

  const ClientDetailScreen({super.key, required this.client, required this.isNl});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  List<dynamic> _invoices = [];
  bool _loading = true;
  String? _filterStatus;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _loading = true);
    final result = await InvoicesService.getInvoices();
    setState(() {
      _loading = false;
      if (result['success']) {
        _invoices = (result['invoices'] as List)
            .where((inv) => inv['client_id'] == widget.client['id'])
            .toList();
      }
    });
  }

  List<dynamic> get _filtered {
    List<dynamic> list = List.from(_invoices);
    if (_filterStatus != null) {
      list = list.where((inv) => inv['status'] == _filterStatus).toList();
    }
    if (_dateRange != null) {
      list = list.where((inv) {
        final dateStr = inv['invoice_date'] as String?;
        if (dateStr == null) return false;
        final date = DateTime.tryParse(dateStr);
        if (date == null) return false;
        return date.isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
            date.isBefore(_dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }
    list.sort((a, b) => (b['invoice_date'] ?? '').compareTo(a['invoice_date'] ?? ''));
    return list;
  }

  double get _totalRevenue => _filtered
      .where((inv) => inv['status'] == 'paid')
      .fold(0.0, (sum, inv) => sum + (double.tryParse(inv['total_incl_btw'].toString()) ?? 0));

  double get _outstanding => _filtered
      .where((inv) => inv['status'] == 'sent' || inv['status'] == 'overdue')
      .fold(0.0, (sum, inv) => sum + (double.tryParse(inv['total_incl_btw'].toString()) ?? 0));

  Color _statusColor(String status) {
    switch (status) {
      case 'paid': return BigDoggTheme.success;
      case 'sent': return BigDoggTheme.info;
      case 'overdue': return BigDoggTheme.error;
      default: return BigDoggTheme.lightTextSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid': return widget.isNl ? 'Betaald' : 'Paid';
      case 'sent': return widget.isNl ? 'Verstuurd' : 'Sent';
      case 'overdue': return widget.isNl ? 'Verlopen' : 'Overdue';
      default: return widget.isNl ? 'Concept' : 'Draft';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNl = widget.isNl;
    final client = widget.client;
    final name = client['contact_name'] ?? '';
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        backgroundColor: BigDoggTheme.teal800,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: BigDoggTheme.teal800,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (client['company_name'] != null && client['company_name'].toString().isNotEmpty)
                        Text(client['company_name'],
                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(client['email'] ?? '',
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _statBox(
                              isNl ? 'Betaald ontvangen' : 'Total received',
                              '€${_totalRevenue.toStringAsFixed(2)}',
                              BigDoggTheme.success,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _statBox(
                              isNl ? 'Openstaand' : 'Outstanding',
                              '€${_outstanding.toStringAsFixed(2)}',
                              BigDoggTheme.warning,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _statBox(
                              isNl ? 'Facturen' : 'Invoices',
                              '${filtered.length}',
                              Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: BigDoggTheme.lightSurface,
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _chip(isNl ? 'Alle' : 'All', _filterStatus == null,
                                  () => setState(() => _filterStatus = null)),
                              const SizedBox(width: 6),
                              _chip(isNl ? 'Betaald' : 'Paid', _filterStatus == 'paid',
                                  () => setState(() => _filterStatus = 'paid')),
                              const SizedBox(width: 6),
                              _chip(isNl ? 'Verstuurd' : 'Sent', _filterStatus == 'sent',
                                  () => setState(() => _filterStatus = 'sent')),
                              const SizedBox(width: 6),
                              _chip(isNl ? 'Verlopen' : 'Overdue', _filterStatus == 'overdue',
                                  () => setState(() => _filterStatus = 'overdue')),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.date_range,
                            color: _dateRange != null ? BigDoggTheme.teal800 : BigDoggTheme.lightTextSecondary),
                        onPressed: () async {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            initialDateRange: _dateRange,
                          );
                          if (range != null) setState(() => _dateRange = range);
                        },
                      ),
                      if (_dateRange != null)
                        IconButton(
                          icon: const Icon(Icons.clear, color: BigDoggTheme.error, size: 18),
                          onPressed: () => setState(() => _dateRange = null),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            isNl ? 'Geen facturen gevonden' : 'No invoices found',
                            style: const TextStyle(color: BigDoggTheme.lightTextSecondary),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final inv = filtered[index];
                            final status = inv['status'] ?? 'draft';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: BigDoggTheme.lightSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: BigDoggTheme.lightBorder),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => InvoiceDetailScreen(invoiceId: inv['id']),
                                  ),
                                ).then((_) => _loadInvoices()),
                                title: Row(
                                  children: [
                                    Text(inv['invoice_number'],
                                        style: const TextStyle(fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _statusLabel(status),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: _statusColor(status),
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(inv['invoice_date'] ?? '',
                                    style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextHint)),
                                trailing: Text('€${inv['total_incl_btw']}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: BigDoggTheme.teal800)),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _statBox(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? BigDoggTheme.teal800 : BigDoggTheme.lightBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? BigDoggTheme.teal800 : BigDoggTheme.lightBorder),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : BigDoggTheme.lightTextSecondary)),
      ),
    );
  }
}