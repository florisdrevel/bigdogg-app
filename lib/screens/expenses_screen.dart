import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/expenses_service.dart';
import '../providers/app_provider.dart';
import '../theme.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<dynamic> _expenses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _loading = true);
    final result = await ExpensesService.getExpenses();
    setState(() {
      _loading = false;
      if (result['success']) _expenses = result['expenses'];
    });
  }

  Future<void> _deleteExpense(String id) async {
    await ExpensesService.deleteExpense(id);
    _loadExpenses();
  }

  void _showAddExpense(bool isNl) {
    final descController = TextEditingController();
    final amountController = TextEditingController();
    int btwRate = 21;
    String category = 'general';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isNl ? 'Uitgave toevoegen' : 'Add Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descController,
                  decoration: InputDecoration(labelText: isNl ? 'Omschrijving' : 'Description'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(labelText: isNl ? 'Bedrag ex BTW (€)' : 'Amount ex BTW (€)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: btwRate,
                  decoration: const InputDecoration(labelText: 'BTW'),
                  items: const [
                    DropdownMenuItem(value: 21, child: Text('21%')),
                    DropdownMenuItem(value: 9, child: Text('9%')),
                    DropdownMenuItem(value: 0, child: Text('0%')),
                  ],
                  onChanged: (val) => setDialogState(() => btwRate = val!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: InputDecoration(labelText: isNl ? 'Categorie' : 'Category'),
                  items: [
                    DropdownMenuItem(value: 'general', child: Text(isNl ? 'Algemeen' : 'General')),
                    DropdownMenuItem(value: 'travel', child: Text(isNl ? 'Reizen' : 'Travel')),
                    DropdownMenuItem(value: 'materials', child: Text(isNl ? 'Materialen' : 'Materials')),
                    DropdownMenuItem(value: 'software', child: Text('Software')),
                    DropdownMenuItem(value: 'food', child: Text(isNl ? 'Eten & Drinken' : 'Food & Drinks')),
                    DropdownMenuItem(value: 'office', child: Text(isNl ? 'Kantoor' : 'Office')),
                    DropdownMenuItem(value: 'other', child: Text(isNl ? 'Overig' : 'Other')),
                  ],
                  onChanged: (val) => setDialogState(() => category = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isNl ? 'Annuleren' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (descController.text.isEmpty || amountController.text.isEmpty) return;
                Navigator.pop(context);
                await ExpensesService.createExpense(
                  description: descController.text.trim(),
                  amountExBtw: double.parse(amountController.text),
                  btwRate: btwRate,
                  category: category,
                );
                _loadExpenses();
              },
              child: Text(isNl ? 'Toevoegen' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'travel': return Icons.directions_car_outlined;
      case 'materials': return Icons.build_outlined;
      case 'software': return Icons.computer_outlined;
      case 'food': return Icons.restaurant_outlined;
      case 'office': return Icons.business_outlined;
      default: return Icons.receipt_outlined;
    }
  }

  String _categoryLabel(String category, bool isNl) {
    switch (category) {
      case 'travel': return isNl ? 'Reizen' : 'Travel';
      case 'materials': return isNl ? 'Materialen' : 'Materials';
      case 'software': return 'Software';
      case 'food': return isNl ? 'Eten & Drinken' : 'Food & Drinks';
      case 'office': return isNl ? 'Kantoor' : 'Office';
      case 'other': return isNl ? 'Overig' : 'Other';
      default: return isNl ? 'Algemeen' : 'General';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNl = context.watch<AppProvider>().language == 'nl';
    double totalExBtw = _expenses.fold(0, (sum, e) => sum + (e['amount_ex_btw'] as num).toDouble());
    double totalBtw = _expenses.fold(0, (sum, e) => sum + (e['btw_amount'] as num).toDouble());

    return Stack(
      children: [
        _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_expenses.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: BigDoggTheme.teal800,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(isNl ? 'Totaal ex BTW' : 'Total ex BTW',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                Text('€${totalExBtw.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('BTW', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                Text('€${totalBtw.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(isNl ? 'Totaal incl BTW' : 'Total incl BTW',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                Text('€${(totalExBtw + totalBtw).toStringAsFixed(2)}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: _expenses.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.receipt_outlined, size: 64, color: BigDoggTheme.lightTextHint),
                                const SizedBox(height: 16),
                                Text(isNl ? 'Nog geen kosten' : 'No expenses yet',
                                    style: const TextStyle(fontSize: 18, color: BigDoggTheme.lightTextSecondary)),
                                const SizedBox(height: 8),
                                Text(isNl ? 'Tik + om een uitgave toe te voegen' : 'Tap + to add an expense',
                                    style: const TextStyle(color: BigDoggTheme.lightTextHint)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _expenses.length,
                            itemBuilder: (context, index) {
                              final exp = _expenses[index];
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
                                    backgroundColor: BigDoggTheme.teal100,
                                    child: Icon(_categoryIcon(exp['category'] ?? 'general'),
                                        color: BigDoggTheme.teal800, size: 20),
                                  ),
                                  title: Text(exp['description'],
                                      style: const TextStyle(fontWeight: FontWeight.w600, color: BigDoggTheme.lightTextPrimary)),
                                  subtitle: Text(
                                    '${exp['expense_date']} · ${_categoryLabel(exp['category'] ?? 'general', isNl)} · ${exp['btw_rate']}% BTW',
                                    style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextSecondary),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('€${exp['amount_ex_btw']}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: BigDoggTheme.teal800)),
                                          Text('+ €${exp['btw_amount']} BTW',
                                              style: const TextStyle(fontSize: 11, color: BigDoggTheme.lightTextSecondary)),
                                        ],
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: BigDoggTheme.error),
                                        onPressed: () => _deleteExpense(exp['id']),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: () => _showAddExpense(isNl),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}