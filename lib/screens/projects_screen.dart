import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_config.dart';
import '../providers/app_provider.dart';
import '../theme.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});
  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<dynamic> _projects = [];
  bool _loading = true;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final token = await _getToken();
      final r = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/projects/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        setState(() { _projects = data['projects'] ?? []; _loading = false; });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _createProject(String name, String desc, String color) async {
    final token = await _getToken();
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/projects/'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'description': desc, 'color': color}),
    );
    _load();
  }

  Future<void> _deleteProject(String id) async {
    final token = await _getToken();
    await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/projects/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _load();
  }

  Future<void> _addHoursToProject(String projectId, double hours, String date, String description) async {
    final token = await _getToken();
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/hours/'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'hours': hours, 'date': date, 'description': description, 'project_id': projectId}),
    );
    _load();
  }

  Future<List<dynamic>> _fetchInvoices() async {
    try {
      final token = await _getToken();
      final r = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/invoices/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (r.statusCode == 200) return jsonDecode(r.body)['invoices'] ?? [];
    } catch (_) {}
    return [];
  }

  Future<void> _linkInvoiceToProject(String invoiceId, String projectId) async {
    final token = await _getToken();
    await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/invoices/$invoiceId'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'project_id': projectId}),
    );
    _load();
  }

  @override
  void initState() { super.initState(); _load(); }

  void _showCreateDialog(bool isNl) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String color = '#1B3A4B';
    final colors = ['#1B3A4B', '#C9A96E', '#166534', '#1D4ED8', '#7C3AED', '#DC2626', '#EA580C'];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(isNl ? 'Nieuw project' : 'New project'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: InputDecoration(labelText: isNl ? 'Naam' : 'Name'), autofocus: true),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, decoration: InputDecoration(labelText: isNl ? 'Omschrijving' : 'Description')),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: colors.map((c) {
                  final col = Color(int.parse(c.replaceFirst('#', '0xFF')));
                  return GestureDetector(
                    onTap: () => setSt(() => color = c),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: col, shape: BoxShape.circle,
                        border: Border.all(color: color == c ? BigDoggTheme.gold500 : Colors.transparent, width: 3),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isNl ? 'Annuleren' : 'Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                _createProject(nameCtrl.text.trim(), descCtrl.text.trim(), color);
              },
              child: Text(isNl ? 'Aanmaken' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddHoursDialog(bool isNl, String projectId) {
    final hoursCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String date = DateTime.now().toIso8601String().substring(0, 10);

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(isNl ? 'Uren toevoegen' : 'Log hours'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: hoursCtrl,
                decoration: InputDecoration(labelText: isNl ? 'Aantal uren' : 'Hours'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx, initialDate: DateTime.now(),
                    firstDate: DateTime(2000), lastDate: DateTime.now(),
                  );
                  if (picked != null) setSt(() => date = picked.toIso8601String().substring(0, 10));
                },
                child: InputDecorator(
                  decoration: InputDecoration(labelText: isNl ? 'Datum' : 'Date'),
                  child: Text(date),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(labelText: isNl ? 'Omschrijving (optioneel)' : 'Description (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isNl ? 'Annuleren' : 'Cancel')),
            ElevatedButton(
              onPressed: () {
                final h = double.tryParse(hoursCtrl.text);
                if (h == null || h <= 0) return;
                Navigator.pop(ctx);
                _addHoursToProject(projectId, h, date, descCtrl.text.trim());
              },
              child: Text(isNl ? 'Opslaan' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLinkInvoiceDialog(bool isNl, String projectId) async {
    final invoices = await _fetchInvoices();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isNl ? 'Factuur koppelen' : 'Link invoice'),
        content: invoices.isEmpty
            ? Text(isNl ? 'Geen facturen gevonden.' : 'No invoices found.')
            : SizedBox(
                width: double.maxFinite,
                height: 300,
                child: ListView.builder(
                  itemCount: invoices.length,
                  itemBuilder: (_, i) {
                    final inv = invoices[i];
                    final clientName = inv['clients']?['contact_name'] ?? inv['client_name'] ?? '';
                    return ListTile(
                      title: Text(inv['invoice_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text('$clientName  \u00b7  \u20ac${inv['total_incl_btw'] ?? 0}', style: const TextStyle(fontSize: 12)),
                      trailing: inv['project_id'] != null
                          ? const Icon(Icons.link, color: BigDoggTheme.teal700, size: 16)
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        _linkInvoiceToProject(inv['id'], projectId);
                      },
                    );
                  },
                ),
              ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(isNl ? 'Annuleren' : 'Cancel')),
        ],
      ),
    );
  }

  void _showDetail(Map p, bool isNl) {
    final color = Color(int.parse((p['color'] ?? '#1B3A4B').replaceFirst('#', '0xFF')));
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65, minChildSize: 0.4, maxChildSize: 0.92, expand: false,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            children: [
              Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(p['name'] ?? '', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: BigDoggTheme.teal800))),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: BigDoggTheme.error),
                      onPressed: () { Navigator.pop(context); _deleteProject(p['id']); },
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              // Action buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddHoursDialog(isNl, p['id']),
                        icon: const Icon(Icons.access_time, size: 16),
                        label: Text(isNl ? 'Uren toevoegen' : 'Log hours', style: const TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BigDoggTheme.teal800,
                          side: const BorderSide(color: BigDoggTheme.teal800),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showLinkInvoiceDialog(isNl, p['id']),
                        icon: const Icon(Icons.receipt_long_outlined, size: 16),
                        label: Text(isNl ? 'Factuur koppelen' : 'Link invoice', style: const TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BigDoggTheme.teal800,
                          side: const BorderSide(color: BigDoggTheme.teal800),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: ctrl,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _row(isNl ? 'Facturen' : 'Invoices', '${p['invoice_count'] ?? 0}'),
                      _row(isNl ? 'Omzet ex BTW' : 'Revenue ex VAT', '\u20ac${_fmt(p['total_revenue'])}'),
                      _row(isNl ? 'Kosten ex BTW' : 'Expenses ex VAT', '\u20ac${_fmt(p['total_expenses'])}'),
                      const Divider(),
                      _row(isNl ? 'Winst' : 'Profit', '\u20ac${_fmt(p['profit'])}', bold: true),
                      _row(isNl ? 'Uren' : 'Hours', '${_fmt(p['total_hours'])} u'),
                      if ((p['description'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Align(alignment: Alignment.centerLeft,
                            child: Text(p['description'], style: const TextStyle(color: BigDoggTheme.lightTextSecondary, fontSize: 14))),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(dynamic v) => (v is num) ? v.toStringAsFixed(2) : (v?.toString() ?? '0');

  Widget _row(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: BigDoggTheme.lightTextSecondary, fontSize: 14)),
        Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 15 : 14, color: BigDoggTheme.teal800)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isNl = context.watch<AppProvider>().language == 'nl';
    return Stack(
      children: [
        _loading
            ? const Center(child: CircularProgressIndicator())
            : _projects.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.folder_outlined, size: 64, color: BigDoggTheme.lightTextHint),
                    const SizedBox(height: 16),
                    Text(isNl ? 'Nog geen projecten' : 'No projects yet',
                        style: const TextStyle(fontSize: 18, color: BigDoggTheme.lightTextSecondary)),
                    const SizedBox(height: 8),
                    Text(isNl ? 'Tik + om een project aan te maken' : 'Tap + to create a project',
                        style: const TextStyle(color: BigDoggTheme.lightTextHint)),
                  ]))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _projects.length,
                    itemBuilder: (_, i) {
                      final p = _projects[i];
                      final col = Color(int.parse((p['color'] ?? '#1B3A4B').replaceFirst('#', '0xFF')));
                      return GestureDetector(
                        onTap: () => _showDetail(p, isNl),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: BigDoggTheme.lightSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: BigDoggTheme.lightBorder),
                          ),
                          child: Row(
                            children: [
                              Container(width: 12, height: 12, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, color: BigDoggTheme.teal800)),
                                  Text('${p['invoice_count'] ?? 0} ${isNl ? 'facturen' : 'invoices'} \u00b7 \u20ac${_fmt(p['total_revenue'])} ${isNl ? 'omzet' : 'revenue'} \u00b7 ${_fmt(p['total_hours'])}u',
                                      style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextSecondary)),
                                ]),
                              ),
                              Text('\u20ac${_fmt(p['profit'])}', style: const TextStyle(fontWeight: FontWeight.bold, color: BigDoggTheme.teal800)),
                              const SizedBox(width: 6),
                              const Icon(Icons.chevron_right, color: BigDoggTheme.lightTextSecondary, size: 18),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        Positioned(bottom: 16, right: 16,
            child: FloatingActionButton(onPressed: () => _showCreateDialog(isNl), child: const Icon(Icons.add))),
      ],
    );
  }
}