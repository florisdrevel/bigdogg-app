import 'package:flutter/material.dart';
import '../services/expenses_service.dart';

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

  void _showAddExpense() {
    final descController = TextEditingController();
    final amountController = TextEditingController();
    int btwRate = 21;
    String category = 'general';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Amount ex BTW (€)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: btwRate,
                  decoration: const InputDecoration(labelText: 'BTW rate'),
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
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'general', child: Text('General')),
                    DropdownMenuItem(value: 'travel', child: Text('Travel')),
                    DropdownMenuItem(value: 'materials', child: Text('Materials')),
                    DropdownMenuItem(value: 'software', child: Text('Software')),
                    DropdownMenuItem(value: 'food', child: Text('Food & Drinks')),
                    DropdownMenuItem(value: 'office', child: Text('Office')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (val) => setDialogState(() => category = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A2E),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
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

  @override
  Widget build(BuildContext context) {
    double totalExBtw = _expenses.fold(0, (sum, e) => sum + (e['amount_ex_btw'] as num).toDouble());
    double totalBtw = _expenses.fold(0, (sum, e) => sum + (e['btw_amount'] as num).toDouble());

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Expenses', style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpense,
        backgroundColor: const Color(0xFF1A1A2E),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_expenses.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total ex BTW', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              Text('€${totalExBtw.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('BTW', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              Text('€${totalBtw.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total incl BTW', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              Text('€${(totalExBtw + totalBtw).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _expenses.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_outlined, size: 64, color: Color(0xFFD1D5DB)),
                              SizedBox(height: 16),
                              Text('No expenses yet', style: TextStyle(fontSize: 18, color: Color(0xFF6B7280))),
                              SizedBox(height: 8),
                              Text('Tap + to add an expense', style: TextStyle(color: Color(0xFF9CA3AF))),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _expenses.length,
                          itemBuilder: (context, index) {
                            final exp = _expenses[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF1A1A2E).withOpacity(0.1),
                                  child: Icon(_categoryIcon(exp['category'] ?? 'general'), color: const Color(0xFF1A1A2E)),
                                ),
                                title: Text(exp['description'], style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  '${exp['expense_date']} · ${exp['category']} · ${exp['btw_rate']}% BTW',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('€${exp['amount_ex_btw']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text('+ €${exp['btw_amount']} BTW', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
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
    );
  }
}