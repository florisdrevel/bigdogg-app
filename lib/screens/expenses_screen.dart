import 'package:flutter/material.dart';
import '../services/expenses_service.dart';
import '../app_theme.dart';

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
                  decoration: const InputDecoration(
                    labelText: 'Amount ex BTW (€)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
                    DropdownMenuItem(
                      value: 'materials',
                      child: Text('Materials'),
                    ),
                    DropdownMenuItem(
                      value: 'software',
                      child: Text('Software'),
                    ),
                    DropdownMenuItem(
                      value: 'food',
                      child: Text('Food & Drinks'),
                    ),
                    DropdownMenuItem(value: 'office', child: Text('Office')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (val) => setDialogState(() => category = val!),
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
                if (descController.text.isEmpty ||
                    amountController.text.isEmpty)
                  return;
                Navigator.pop(context);
                await ExpensesService.createExpense(
                  description: descController.text.trim(),
                  amountExBtw: double.parse(amountController.text),
                  btwRate: btwRate,
                  category: category,
                );
                _loadExpenses();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'travel':
        return Icons.directions_car_outlined;
      case 'materials':
        return Icons.build_outlined;
      case 'software':
        return Icons.computer_outlined;
      case 'food':
        return Icons.restaurant_outlined;
      case 'office':
        return Icons.business_outlined;
      default:
        return Icons.receipt_outlined;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'travel':
        return const Color(0xFF0EA5E9);
      case 'materials':
        return const Color(0xFFF59E0B);
      case 'software':
        return const Color(0xFF8B5CF6);
      case 'food':
        return const Color(0xFFEF4444);
      case 'office':
        return const Color(0xFF10B981);
      default:
        return AppColors.navy;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double totalExBtw = _expenses.fold(
      0,
      (sum, e) => sum + (e['amount_ex_btw'] as num).toDouble(),
    );
    final double totalBtw = _expenses.fold(
      0,
      (sum, e) => sum + (e['btw_amount'] as num).toDouble(),
    );

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpense,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_expenses.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: GradientStatCard(
                      stats: [
                        statItem(
                          'Ex BTW',
                          '€${totalExBtw.toStringAsFixed(2)}',
                        ),
                        statItem(
                          'BTW',
                          '€${totalBtw.toStringAsFixed(2)}',
                        ),
                        statItem(
                          'Total',
                          '€${(totalExBtw + totalBtw).toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _expenses.isEmpty
                      ? const EmptyState(
                          icon: Icons.receipt_outlined,
                          title: 'No expenses yet',
                          subtitle: 'Tap + to add an expense',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: _expenses.length,
                          itemBuilder: (context, index) {
                            final exp = _expenses[index];
                            final cat = exp['category'] ?? 'general';
                            final catColor = _categoryColor(cat);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: AppDecorations.card,
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: catColor.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _categoryIcon(cat),
                                      color: catColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          exp['description'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${exp['expense_date']}  ·  $cat  ·  ${exp['btw_rate']}% BTW',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '€${exp['amount_ex_btw']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '+ €${exp['btw_amount']} BTW',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: AppColors.danger,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _deleteExpense(exp['id']),
                                  ),
                                ],
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
