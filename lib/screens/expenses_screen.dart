import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
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
  bool _parsing = false;

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

  Future<void> _pickAndParseReceipt(bool isNl, {bool camera = false}) async {
    Uint8List? bytes;
    String? fileName;

    if (kIsWeb) {
      final completer = Completer<void>();
      final input = html.FileUploadInputElement();
      if (camera) {
        input.accept = 'image/*';
        input.setAttribute('capture', 'environment');
      } else {
        input.accept = 'image/*,application/pdf,.pdf,.heic,.heif,*/*';
      }
      input.click();
      input.onChange.listen((event) async {
        final file = input.files?.first;
        if (file != null) {
          final reader = html.FileReader();
          reader.readAsArrayBuffer(file);
          await reader.onLoad.first;
          bytes = Uint8List.fromList(reader.result as List<int>);
          fileName = file.name;
        }
        completer.complete();
      });
      await completer.future;
    } else {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked != null) {
        bytes = await picked.readAsBytes();
        fileName = picked.name;
      }
    }

    if (bytes == null) return;

    setState(() => _parsing = true);

    final parsed = await ExpensesService.parseReceipt(
      fileBytes: bytes!,
      fileName: fileName ?? 'receipt.jpg',
    );

    setState(() => _parsing = false);

    if (!mounted) return;

    if (parsed['success']) {
      _showAddExpense(
        isNl,
        prefill: parsed,
        receiptBytes: bytes,
        receiptFileName: fileName,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNl ? 'Kon bon niet lezen' : 'Could not read receipt'),
          backgroundColor: BigDoggTheme.error,
        ),
      );
    }
  }

  void _showAddExpense(
    bool isNl, {
    Map<String, dynamic>? prefill,
    Uint8List? receiptBytes,
    String? receiptFileName,
  }) {
    final descController =
        TextEditingController(text: prefill?['description'] ?? '');
    final amountController = TextEditingController(
      text: prefill?['amount_ex_btw'] != null
          ? (prefill!['amount_ex_btw'] as num).toStringAsFixed(2)
          : '',
    );
    int btwRate = prefill?['btw_rate'] ?? 21;
    String category = prefill?['category'] ?? 'general';
    Uint8List? currentReceiptBytes = receiptBytes;
    String? currentReceiptFileName = receiptFileName;
    bool uploading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isNl ? 'Uitgave toevoegen' : 'Add Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (prefill != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: BigDoggTheme.successBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome,
                            size: 14, color: BigDoggTheme.success),
                        const SizedBox(width: 6),
                        Text(
                          isNl
                              ? 'Automatisch ingevuld via bon'
                              : 'Auto-filled from receipt',
                          style: const TextStyle(
                              fontSize: 12,
                              color: BigDoggTheme.success,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: descController,
                  decoration: InputDecoration(
                      labelText: isNl ? 'Omschrijving' : 'Description'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                      labelText:
                          isNl ? 'Bedrag ex BTW (€)' : 'Amount ex VAT (€)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
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
                  decoration: InputDecoration(
                      labelText: isNl ? 'Categorie' : 'Category'),
                  items: [
                    DropdownMenuItem(
                        value: 'general',
                        child: Text(isNl ? 'Algemeen' : 'General')),
                    DropdownMenuItem(
                        value: 'travel',
                        child: Text(isNl ? 'Reizen' : 'Travel')),
                    DropdownMenuItem(
                        value: 'materials',
                        child: Text(isNl ? 'Materialen' : 'Materials')),
                    DropdownMenuItem(
                        value: 'software', child: const Text('Software')),
                    DropdownMenuItem(
                        value: 'food',
                        child:
                            Text(isNl ? 'Eten & Drinken' : 'Food & Drinks')),
                    DropdownMenuItem(
                        value: 'office',
                        child: Text(isNl ? 'Kantoor' : 'Office')),
                    DropdownMenuItem(
                        value: 'other',
                        child: Text(isNl ? 'Overig' : 'Other')),
                  ],
                  onChanged: (val) => setDialogState(() => category = val!),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BigDoggTheme.lightBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: BigDoggTheme.lightBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isNl ? 'Bon' : 'Receipt',
                        style: const TextStyle(
                            fontSize: 12,
                            color: BigDoggTheme.lightTextSecondary,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      if (currentReceiptBytes != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.memory(
                            currentReceiptBytes!,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextButton.icon(
                          onPressed: () => setDialogState(() {
                            currentReceiptBytes = null;
                            currentReceiptFileName = null;
                          }),
                          icon: const Icon(Icons.close,
                              size: 14, color: BigDoggTheme.error),
                          label: Text(
                            isNl ? 'Verwijderen' : 'Remove',
                            style: const TextStyle(
                                color: BigDoggTheme.error, fontSize: 12),
                          ),
                        ),
                      ] else
                        Text(
                          isNl
                              ? 'Geen bon bijgevoegd'
                              : 'No receipt attached',
                          style: const TextStyle(
                              fontSize: 12,
                              color: BigDoggTheme.lightTextHint),
                        ),
                    ],
                  ),
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
              onPressed: uploading
                  ? null
                  : () async {
                      if (descController.text.isEmpty ||
                          amountController.text.isEmpty) return;
                      setDialogState(() => uploading = true);
                      Navigator.pop(context);

                      final result = await ExpensesService.createExpense(
                        description: descController.text.trim(),
                        amountExBtw: double.parse(amountController.text),
                        btwRate: btwRate,
                        category: category,
                        expenseDate: prefill?['expense_date'],
                      );

                      if (result['success'] && currentReceiptBytes != null) {
                        await ExpensesService.uploadReceipt(
                          result['expense']['id'],
                          currentReceiptBytes!,
                          currentReceiptFileName ?? 'receipt.jpg',
                        );
                      }

                      _loadExpenses();
                    },
              child: uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isNl ? 'Toevoegen' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiptDialog(String receiptUrl, bool isNl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(isNl ? 'Bon' : 'Receipt'),
              backgroundColor: BigDoggTheme.teal800,
              foregroundColor: Colors.white,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Image.network(receiptUrl, fit: BoxFit.contain),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'travel':
        return Icons.directions_car;
      case 'materials':
        return Icons.build;
      case 'software':
        return Icons.computer;
      case 'food':
        return Icons.restaurant;
      case 'office':
        return Icons.business;
      default:
        return Icons.receipt;
    }
  }

  String _categoryLabel(String category, bool isNl) {
    switch (category) {
      case 'travel':
        return isNl ? 'Reizen' : 'Travel';
      case 'materials':
        return isNl ? 'Materialen' : 'Materials';
      case 'software':
        return 'Software';
      case 'food':
        return isNl ? 'Eten & Drinken' : 'Food & Drinks';
      case 'office':
        return isNl ? 'Kantoor' : 'Office';
      case 'other':
        return isNl ? 'Overig' : 'Other';
      default:
        return isNl ? 'Algemeen' : 'General';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNl = context.watch<AppProvider>().language == 'nl';
    double totalExBtw = _expenses.fold(
        0, (sum, e) => sum + (e['amount_ex_btw'] as num).toDouble());
    double totalBtw = _expenses.fold(
        0, (sum, e) => sum + (e['btw_amount'] as num).toDouble());

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
                                Text(
                                    isNl ? 'Totaal ex BTW' : 'Total ex VAT',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                                Text('€${totalExBtw.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('BTW / VAT',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                                Text('€${totalBtw.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    isNl
                                        ? 'Totaal incl BTW'
                                        : 'Total incl VAT',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                                Text(
                                    '€${(totalExBtw + totalBtw).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18)),
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
                                const Icon(Icons.receipt,
                                    size: 64,
                                    color: BigDoggTheme.lightTextHint),
                                const SizedBox(height: 16),
                                Text(
                                    isNl
                                        ? 'Nog geen kosten'
                                        : 'No expenses yet',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        color:
                                            BigDoggTheme.lightTextSecondary)),
                                const SizedBox(height: 8),
                                Text(
                                    isNl
                                        ? 'Tik + om een uitgave toe te voegen'
                                        : 'Tap + to add an expense',
                                    style: const TextStyle(
                                        color: BigDoggTheme.lightTextHint)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _expenses.length,
                            itemBuilder: (context, index) {
                              final exp = _expenses[index];
                              final hasReceipt =
                                  exp['receipt_url'] != null &&
                                      exp['receipt_url']
                                          .toString()
                                          .isNotEmpty;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: BigDoggTheme.lightSurface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: BigDoggTheme.lightBorder),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: BigDoggTheme.teal100,
                                    child: Icon(
                                        _categoryIcon(
                                            exp['category'] ?? 'general'),
                                        color: BigDoggTheme.teal800,
                                        size: 20),
                                  ),
                                  title: Text(exp['description'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color:
                                              BigDoggTheme.lightTextPrimary)),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${exp['expense_date']} · ${_categoryLabel(exp['category'] ?? 'general', isNl)} · ${exp['btw_rate']}% BTW',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: BigDoggTheme
                                                .lightTextSecondary),
                                      ),
                                      if (hasReceipt)
                                        GestureDetector(
                                          onTap: () => _showReceiptDialog(
                                              exp['receipt_url'], isNl),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.attach_file,
                                                  size: 12,
                                                  color: BigDoggTheme.teal700),
                                              const SizedBox(width: 2),
                                              Text(
                                                isNl
                                                    ? 'Bon bekijken'
                                                    : 'View receipt',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: BigDoggTheme.teal700,
                                                    fontWeight:
                                                        FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text('€${exp['amount_ex_btw']}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: BigDoggTheme.teal800)),
                                          Text('+ €${exp['btw_amount']} BTW',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: BigDoggTheme
                                                      .lightTextSecondary)),
                                        ],
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: BigDoggTheme.error),
                                        onPressed: () =>
                                            _deleteExpense(exp['id']),
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

        // Parsing overlay
        if (_parsing)
          Container(
            color: Colors.black45,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      isNl ? 'Bon analyseren...' : 'Analysing receipt...',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // FABs
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                heroTag: 'camera_fab',
                onPressed: _parsing
                    ? null
                    : () => _pickAndParseReceipt(isNl, camera: true),
                backgroundColor: BigDoggTheme.teal800,
                child: const Icon(Icons.camera_alt,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: 'upload_fab',
                onPressed: _parsing
                    ? null
                    : () => _pickAndParseReceipt(isNl, camera: false),
                backgroundColor: BigDoggTheme.teal800,
                child: const Icon(Icons.folder_open,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: 'add_fab',
                onPressed: () => _showAddExpense(isNl),
                child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
            ],
          ),
        ),
      ],
    );
  }
}