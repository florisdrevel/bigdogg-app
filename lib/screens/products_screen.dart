import 'package:flutter/material.dart';
import '../services/products_service.dart';

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

  Future<void> _deleteProduct(String id) async {
    await ProductsService.deleteProduct(id);
    _loadProducts();
  }

  void _showAddProduct() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final priceController = TextEditingController();
    int btwRate = 21;
    String unit = 'hour';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Product name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Price ex. BTW (€)'),
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
                  value: unit,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: const [
                    DropdownMenuItem(value: 'hour', child: Text('Per hour')),
                    DropdownMenuItem(value: 'day', child: Text('Per day')),
                    DropdownMenuItem(value: 'piece', child: Text('Per piece')),
                    DropdownMenuItem(value: 'project', child: Text('Per project')),
                  ],
                  onChanged: (val) => setDialogState(() => unit = val!),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Products', style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProduct,
        backgroundColor: const Color(0xFF1A1A2E),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Color(0xFFD1D5DB)),
                      SizedBox(height: 16),
                      Text('No products yet', style: TextStyle(fontSize: 18, color: Color(0xFF6B7280))),
                      SizedBox(height: 8),
                      Text('Tap + to add your first product', style: TextStyle(color: Color(0xFF9CA3AF))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final p = _products[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(p['description'] ?? '', style: const TextStyle(color: Color(0xFF6B7280))),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('€${p['unit_price']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('${p['btw_rate']}% BTW · per ${p['unit']}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                              ],
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                              onPressed: () => _deleteProduct(p['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}