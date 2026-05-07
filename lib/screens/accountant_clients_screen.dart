import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/accountants_service.dart';
import '../theme.dart';

/// "My clients" picker for the accountant. Lists every BigDogg user
/// who has linked this accountant. Tapping a client opens the read-only
/// view for that client.
class AccountantClientsScreen extends StatefulWidget {
  const AccountantClientsScreen({super.key});

  @override
  State<AccountantClientsScreen> createState() =>
      _AccountantClientsScreenState();
}

class _AccountantClientsScreenState extends State<AccountantClientsScreen> {
  List<Map<String, dynamic>> _clients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final clients = await AccountantsService.listClients();
    if (!mounted) return;
    setState(() {
      _clients = clients;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BigDoggTheme.lightBg,
      appBar: AppBar(
        backgroundColor: BigDoggTheme.teal800,
        foregroundColor: Colors.white,
        title: const Text('Mijn klanten'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Vernieuwen',
          ),
          IconButton(
            icon: const Icon(Icons.dashboard_outlined),
            onPressed: () => context.go('/dashboard'),
            tooltip: 'Mijn eigen BigDogg',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _clients.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.folder_open_outlined,
                            size: 64,
                            color: BigDoggTheme.lightTextSecondary),
                        const SizedBox(height: 16),
                        Text(
                          'Je hebt nog geen klanten',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: BigDoggTheme.teal800),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Zodra een BigDogg-gebruiker je uitnodigt en jij accepteert, verschijnt hij hier.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: BigDoggTheme.lightTextSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _clients.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final c = _clients[i];
                    final name = (c['display_name'] ?? '').toString();
                    final id = (c['user_id'] ?? '').toString();
                    return Material(
                      color: BigDoggTheme.lightSurface,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () =>
                            context.push('/accountant/view/$id?name=${Uri.encodeComponent(name)}'),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: BigDoggTheme.lightBorder),
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            CircleAvatar(
                              backgroundColor: BigDoggTheme.teal100,
                              foregroundColor: BigDoggTheme.teal800,
                              child: Text(
                                name.isNotEmpty
                                    ? name.substring(0, 1).toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.isEmpty ? 'BigDogg-gebruiker' : name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        color:
                                            BigDoggTheme.lightTextPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Tik om in te zien (alleen-lezen)',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            BigDoggTheme.lightTextSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: BigDoggTheme.lightTextSecondary),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
