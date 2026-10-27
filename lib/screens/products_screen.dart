import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/products_service.dart';
import '../services/product_groups_service.dart';
import '../services/local_storage_service.dart';
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
    _bootstrapFromCache();
    _loadProducts();
  }

  /// Synchronous Hive read so the list paints on the first frame and
  /// revisiting the tab never flashes a spinner.
  void _bootstrapFromCache() {
    final cached = LocalStorageService.get('products');
    if (cached is List && cached.isNotEmpty) {
      _products = cached;
      _loading = false;
    }
  }

  Future<void> _loadProducts() async {
    if (_products.isEmpty) setState(() => _loading = true);
    final result = await ProductsService.getProducts();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success']) _products = result['products'];
    });
    if (result['success']) {
      await LocalStorageService.save('products', result['products']);
    }
  }

  void _showProductDialog(bool isNl, {Map<String, dynamic>? existing}) {
    final nameController = TextEditingController(text: existing?['name'] ?? '');
    final descController = TextEditingController(text: existing?['description'] ?? '');
    final priceController = TextEditingController(text: existing?['unit_price']?.toString() ?? '');
    int btwRate = existing?['btw_rate'] ?? 21;
    String unit = existing?['unit'] ?? 'hour';
    bool vatIncluded = existing?['vat_included'] ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing != null
              ? (isNl ? 'Product bewerken' : 'Edit Product')
              : (isNl ? 'Product toevoegen' : 'Add Product')),
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
                  decoration: InputDecoration(
                    labelText: vatIncluded
                        ? (isNl ? 'Prijs incl BTW *' : 'Price incl VAT *')
                        : (isNl ? 'Prijs ex BTW *' : 'Price ex BTW *'),
                  ),
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
                const SizedBox(height: 12),
                // VAT included checkbox
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: vatIncluded
                        ? BigDoggTheme.teal800.withOpacity(0.06)
                        : BigDoggTheme.lightBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: vatIncluded
                          ? BigDoggTheme.teal800.withOpacity(0.3)
                          : BigDoggTheme.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: vatIncluded,
                        activeColor: BigDoggTheme.teal800,
                        onChanged: (val) => setDialogState(() => vatIncluded = val ?? false),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isNl ? 'BTW inbegrepen' : 'VAT included',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: BigDoggTheme.lightTextPrimary,
                              ),
                            ),
                            Text(
                              isNl
                                  ? 'De ingevoerde prijs is inclusief BTW'
                                  : 'The entered price already includes VAT',
                              style: const TextStyle(
                                fontSize: 11,
                                color: BigDoggTheme.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Preview back-calculation
                if (vatIncluded && priceController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Builder(builder: (_) {
                    final price = double.tryParse(priceController.text) ?? 0;
                    final exBtw = btwRate > 0
                        ? price / (1 + btwRate / 100)
                        : price;
                    final btwAmt = price - exBtw;
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: BigDoggTheme.teal100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isNl ? 'Berekening:' : 'Calculation:',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: BigDoggTheme.teal800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isNl
                                ? '\u20ac${price.toStringAsFixed(2)} incl = \u20ac${exBtw.toStringAsFixed(2)} ex BTW + \u20ac${btwAmt.toStringAsFixed(2)} BTW'
                                : '\u20ac${price.toStringAsFixed(2)} incl = \u20ac${exBtw.toStringAsFixed(2)} ex VAT + \u20ac${btwAmt.toStringAsFixed(2)} VAT',
                            style: const TextStyle(
                              fontSize: 11,
                              color: BigDoggTheme.teal800,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
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
                if (existing != null) {
                  await ProductsService.updateProduct(
                    productId: existing['id'],
                    name: nameController.text.trim(),
                    description: descController.text.trim(),
                    unitPrice: double.parse(priceController.text),
                    btwRate: btwRate,
                    unit: unit,
                    vatIncluded: vatIncluded,
                  );
                } else {
                  await ProductsService.createProduct(
                    name: nameController.text.trim(),
                    description: descController.text.trim(),
                    unitPrice: double.parse(priceController.text),
                    btwRate: btwRate,
                    unit: unit,
                    vatIncluded: vatIncluded,
                  );
                }
                _loadProducts();
              },
              child: Text(existing != null
                  ? (isNl ? 'Opslaan' : 'Save')
                  : (isNl ? 'Toevoegen' : 'Add')),
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

  // ─── Product groups ─────────────────────────────────────────

  Future<void> _showGroupsManager(bool isNl) async {
    final res = await ProductGroupsService.getGroups();
    if (!mounted) return;
    List groups = (res['success'] == true) ? (res['groups'] as List? ?? []) : [];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          Future<void> reload() async {
            final r = await ProductGroupsService.getGroups();
            if (r['success'] == true) {
              setSheet(() => groups = r['groups'] as List? ?? []);
            }
          }

          return AlertDialog(
            title: Text(isNl ? 'Productgroepen' : 'Product groups'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (groups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                          isNl
                              ? 'Nog geen groepen. Maak een groep van producten die je vaak samen factureert, dan voeg je ze in één keer toe aan een factuur.'
                              : 'No groups yet. Make a group of products you often invoice together to add them to an invoice in one tap.',
                          style: const TextStyle(
                              color: BigDoggTheme.lightTextSecondary, fontSize: 13)),
                    )
                  else
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: groups.map<Widget>((g) {
                          final count = (g['items'] as List? ?? []).length;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(g['name'] ?? ''),
                            subtitle: Text(
                                isNl ? '$count product(en)' : '$count product(s)',
                                style: const TextStyle(fontSize: 12)),
                            onTap: () async {
                              final changed =
                                  await _showGroupEditor(isNl, existing: g);
                              if (changed == true) await reload();
                            },
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: BigDoggTheme.error),
                              onPressed: () async {
                                await ProductGroupsService.deleteGroup(g['id']);
                                await reload();
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () async {
                      final changed = await _showGroupEditor(isNl);
                      if (changed == true) await reload();
                    },
                    icon: const Icon(Icons.add),
                    label: Text(isNl ? 'Nieuwe groep' : 'New group'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(isNl ? 'Sluiten' : 'Close')),
            ],
          );
        },
      ),
    );
  }

  Future<bool?> _showGroupEditor(bool isNl, {Map? existing}) async {
    final nameController =
        TextEditingController(text: existing?['name'] ?? '');
    final selected = <String>{
      ...((existing?['items'] as List? ?? [])
          .map((it) => it['product_id'] as String)),
    };
    final activeProducts =
        _products.where((p) => (p['is_active'] ?? true) == true).toList();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => AlertDialog(
          title: Text(existing == null
              ? (isNl ? 'Nieuwe groep' : 'New group')
              : (isNl ? 'Groep bewerken' : 'Edit group')),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration:
                      InputDecoration(labelText: isNl ? 'Naam' : 'Name'),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      isNl
                          ? 'Producten in deze groep:'
                          : 'Products in this group:',
                      style: const TextStyle(
                          fontSize: 12,
                          color: BigDoggTheme.lightTextSecondary)),
                ),
                if (activeProducts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                        isNl
                            ? 'Voeg eerst producten toe.'
                            : 'Add some products first.',
                        style: const TextStyle(
                            fontSize: 12,
                            color: BigDoggTheme.lightTextHint)),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: activeProducts.map<Widget>((p) {
                        final pid = p['id'] as String;
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: selected.contains(pid),
                          title: Text(p['name'] ?? ''),
                          onChanged: (v) => setSheet(() {
                            if (v == true) {
                              selected.add(pid);
                            } else {
                              selected.remove(pid);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(isNl ? 'Annuleren' : 'Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty || selected.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(isNl
                          ? 'Geef een naam en kies minstens één product.'
                          : 'Enter a name and pick at least one product.')));
                  return;
                }
                // Keep the product order as shown in the list.
                final items = activeProducts
                    .where((p) => selected.contains(p['id']))
                    .map<Map<String, dynamic>>((p) =>
                        {'product_id': p['id'], 'default_quantity': 1})
                    .toList();
                final res = existing == null
                    ? await ProductGroupsService.createGroup(
                        name: nameController.text.trim(), items: items)
                    : await ProductGroupsService.updateGroup(
                        groupId: existing['id'],
                        name: nameController.text.trim(),
                        items: items);
                if (!mounted) return;
                if (res['success'] == true) {
                  Navigator.pop(context, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      backgroundColor: BigDoggTheme.error,
                      content: Text(res['message']?.toString() ??
                          (isNl ? 'Opslaan mislukt' : 'Save failed'))));
                }
              },
              child: Text(isNl ? 'Opslaan' : 'Save'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    return saved;
  }

  @override
  Widget build(BuildContext context) {
    final isNl = context.watch<AppProvider>().language == 'nl';

    return Stack(
      children: [
        _loading
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
                      final vatInc = product['vat_included'] ?? false;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: BigDoggTheme.lightSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: BigDoggTheme.lightBorder),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          onTap: () => _showProductDialog(isNl, existing: product),
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
                              if (vatInc) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: BigDoggTheme.teal800.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isNl ? 'incl BTW' : 'incl VAT',
                                    style: const TextStyle(fontSize: 10, color: BigDoggTheme.teal800, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            '\u20ac${product['unit_price']} / ${_unitLabel(product['unit'] ?? 'hour', isNl)} \u00b7 ${product['btw_rate']}% BTW',
                            style: const TextStyle(color: BigDoggTheme.lightTextSecondary, fontSize: 13),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: BigDoggTheme.teal800),
                                onPressed: () => _showProductDialog(isNl, existing: product),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: BigDoggTheme.error),
                                onPressed: () async {
                                  await ProductsService.deleteProduct(product['id']);
                                  _loadProducts();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        Positioned(
          bottom: 84,
          right: 16,
          child: FloatingActionButton.small(
            heroTag: 'groupsFab',
            backgroundColor: BigDoggTheme.teal100,
            foregroundColor: BigDoggTheme.teal800,
            tooltip: isNl ? 'Productgroepen' : 'Product groups',
            onPressed: () => _showGroupsManager(isNl),
            child: const Icon(Icons.library_add_outlined),
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: () => _showProductDialog(isNl),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}