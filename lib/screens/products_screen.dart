import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/products_service.dart';
import '../providers/app_provider.dart';
import '../theme.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<dynamic> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    final result = await ProductsService.getProducts();
    setState(() {
      _loading = false;
      if (result['success']) _products = result['products'];
    });
  }

  void _showAddProduct(bool isNl) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final priceController = TextEditingController();
    int btwRate = 21;
    String unit = 'hour';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isNl ? 'Product toevoegen' : 'Add Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: isNl ? 'Naam *' : 'Name *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: InputDecoration(labelText: isNl ? 'Omschrijving' : 'Description'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  decoration: InputDecoration(labelText: isNl ? 'Prijs ex BTW *' : 'Price ex BTW *'),
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
                  value: unit,
                  decoration: InputDecoration(labelText: isNl ? 'Eenheid' : 'Unit'),
                  items: [
                    DropdownMenuItem(value: 'hour', child: Text(isNl ? 'Uur' : 'Hour')),
                    DropdownMenuItem(value: 'day', child: Text(isNl ? 'Dag' : 'Day')),
                    DropdownMenuItem(value: 'piece', child: Text(isNl ? 'Stuk' : 'Piece')),
                    DropdownMenuItem(value: 'km', child: Text('km')),
                    DropdownMenuItem(value: 'fixed', child: Text(isNl ? 'Vast bedrag' : 'Fixed')),
                  ],
                  onChanged: (val) => setDialogState(() => unit = val!),
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
                if (nameController.text.isEmpty || priceController.text.isEmpty) return;
                Navigator.pop(context);
                await ProductsService.createProduct(
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                  unitPrice: double.parse(priceController.text),
                  btwRate: btwRate,
                  unit: unit,
                );
                _loadProducts();
              },
              child: Text(isNl ? 'Toevoegen' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  String _unitLabel(String unit, bool isNl) {
    switch (unit) {
      case 'hour': return isNl ? 'uur' : 'hour';
      case 'day': return isNl ? 'dag' : 'day';
      case 'piece': return isNl ? 'stuk' : 'piece';
      case 'fixed': return isNl ? 'vast' : 'fixed';
      default: return unit;
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
        title: Text(isNl ? 'Producten' : 'Products',
            style: const TextStyle(color: BigDoggTheme.lightTextPrimary, fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: BigDoggTheme.lightBorder, height: 1)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddProduct(isNl),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 64, color: BigDoggTheme.lightTextHint),
                      const SizedBox(height: 16),
                      Text(isNl ? 'Nog geen producten' : 'No products yet',
                          style: const TextStyle(fontSize: 18, color: BigDoggTheme.lightTextSecondary)),
                      const SizedBox(height: 8),
                      Text(isNl ? 'Tik + om een product toe te voegen' : 'Tap + to add a product',
                          style: const TextStyle(color: BigDoggTheme.lightTextHint)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    final isActive = product['is_active'] ?? true;
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
                          child: const Icon(Icons.inventory_2_outlined, color: BigDoggTheme.teal800, size: 20),
                        ),
                        title: Row(
                          children: [
                            Text(product['name'],
                                style: const TextStyle(fontWeight: FontWeight.w600, color: BigDoggTheme.lightTextPrimary)),
                            const SizedBox(width: 8),
                            if (!isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: BigDoggTheme.lightTextHint.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(isNl ? 'Inactief' : 'Inactive',
                                    style: const TextStyle(fontSize: 10, color: BigDoggTheme.lightTextHint)),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          '€${product['unit_price']} / ${_unitLabel(product['unit'] ?? 'hour', isNl)} · ${product['btw_rate']}% BTW',
                          style: const TextStyle(color: BigDoggTheme.lightTextSecondary, fontSize: 13),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: BigDoggTheme.error),
                          onPressed: () async {
                            await ProductsService.deleteProduct(product['id']);
                            _loadProducts();
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}