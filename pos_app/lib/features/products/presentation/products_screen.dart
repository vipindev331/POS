// Product catalog viewer. Reads the local Drift cache reactively (works
// offline); a refresh pulls the latest from the backend.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injector.dart';
import '../../../core/money/tax_engine.dart';
import '../../../data/local/database.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../data/products_repository.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _search = TextEditingController();
  String _term = '';
  bool _refreshing = false;

  ProductsRepository get _repo => sl<ProductsRepository>();

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    final n = await _repo.refreshFromRemote();
    if (mounted) {
      setState(() => _refreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(n >= 0 ? 'Synced $n products' : 'Offline — showing cached catalog')));
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // Managers, or staff granted the manage-products permission, can edit/delete.
  bool get _canManage =>
      context.read<AuthCubit>().state.user?.can(kPermManageProducts) ?? false;

  Future<void> _addProduct() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => const _ProductFormDialog(),
    );
    if (added == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Product added')));
    }
  }

  Future<void> _editProduct(Product p) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ProductFormDialog(existing: p),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Product updated')));
    }
  }

  Future<void> _deleteProduct(Product p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product'),
        content: Text('Delete "${p.name}"? This removes it from the catalog.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await sl<ProductsRepository>().deleteProduct(p.id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Deleted ${p.name}')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not delete product')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
            tooltip: 'Sync from server',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addProduct,
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name / SKU / barcode'),
              onChanged: (v) => setState(() => _term = v.trim()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: _repo.watch(),
              builder: (context, snap) {
                final all = snap.data ?? const [];
                final items = _term.isEmpty
                    ? all
                    : all
                        .where((p) =>
                            p.name.toLowerCase().contains(_term.toLowerCase()) ||
                            (p.barcode ?? '').contains(_term) ||
                            (p.sku ?? '').toLowerCase().contains(_term.toLowerCase()))
                        .toList();
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (items.isEmpty) {
                  return const Center(child: Text('No products. Tap sync to load from the server.'));
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = items[i];
                    final low = p.stock <= p.reorderLevel;
                    return ListTile(
                      onTap: _canManage ? () => _editProduct(p) : null,
                      title: Text(p.name),
                      subtitle: Text('${p.barcode ?? p.sku ?? ''}  ·  GST ${p.gstRate}%'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(formatPaise(p.sellingPrice),
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('Stock ${p.stock}',
                                  style: TextStyle(fontSize: 12, color: low ? Colors.orange : null)),
                            ],
                          ),
                          if (_canManage)
                            PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') _editProduct(p);
                                if (v == 'delete') _deleteProduct(p);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(Icons.edit),
                                    title: Text('Edit'),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(Icons.delete_outline),
                                    title: Text('Delete'),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Add a new product, or edit [existing] when provided. Name is required; money
/// fields are entered in rupees and stored as paise. Pops `true` on success.
class _ProductFormDialog extends StatefulWidget {
  final Product? existing;
  const _ProductFormDialog({this.existing});

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _barcode = TextEditingController();
  final _hsn = TextEditingController();
  final _selling = TextEditingController();
  final _mrp = TextEditingController();
  final _purchase = TextEditingController();
  final _stock = TextEditingController(text: '0');
  final _reorder = TextEditingController(text: '0');
  int _gstRate = 0; // must be one of kGstSlabs (0/5/12/18/28)
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  // Paise -> a clean rupees string (no ".00" for whole rupees).
  static String _rupees(int paise) {
    final r = paise / 100;
    return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(2);
  }

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    if (p != null) {
      _name.text = p.name;
      _sku.text = p.sku ?? '';
      _barcode.text = p.barcode ?? '';
      _hsn.text = p.hsn ?? '';
      // Guard against legacy/invalid slabs so the dropdown has a valid value.
      _gstRate = kGstSlabs.contains(p.gstRate) ? p.gstRate : 0;
      _selling.text = _rupees(p.sellingPrice);
      _mrp.text = _rupees(p.mrp);
      _purchase.text = _rupees(p.purchasePrice);
      _stock.text = '${p.stock}';
      _reorder.text = '${p.reorderLevel}';
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _sku, _barcode, _hsn, _selling, _mrp, _purchase, _stock, _reorder]) {
      c.dispose();
    }
    super.dispose();
  }

  // Rupees text -> paise. Empty/invalid becomes 0.
  int _paise(TextEditingController c) => ((double.tryParse(c.text.trim()) ?? 0) * 100).round();
  int _int(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
      final repo = sl<ProductsRepository>();
      if (_isEdit) {
        await repo.updateProduct(
          widget.existing!.id,
          name: _name.text.trim(),
          sku: t(_sku),
          barcode: t(_barcode),
          hsn: t(_hsn),
          gstRate: _gstRate,
          purchasePrice: _paise(_purchase),
          sellingPrice: _paise(_selling),
          mrp: _paise(_mrp),
          stock: _int(_stock),
          reorderLevel: _int(_reorder),
        );
      } else {
        await repo.addProduct(
          name: _name.text.trim(),
          sku: t(_sku),
          barcode: t(_barcode),
          hsn: t(_hsn),
          gstRate: _gstRate,
          purchasePrice: _paise(_purchase),
          sellingPrice: _paise(_selling),
          mrp: _paise(_mrp),
          stock: _int(_stock),
          reorderLevel: _int(_reorder),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save product');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit product' : 'Add product'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    helperText: 'Product name shown at billing and on the receipt',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: _field(_sku, 'SKU (optional)',
                        helper: 'Your own product code for tracking stock (e.g. MILK-1L)'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(_barcode, 'Barcode (optional)',
                        helper: 'Scannable number on the pack (EAN/UPC)'),
                  ),
                ]),
                const SizedBox(height: 18),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: _field(_hsn, 'HSN (optional)',
                        helper: 'Govt. GST classification code for tax invoices'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _gstRate,
                      decoration: const InputDecoration(
                        labelText: 'GST %',
                        helperText: 'Tax slab applied on this item',
                        helperMaxLines: 2,
                      ),
                      items: [
                        for (final r in kGstSlabs)
                          DropdownMenuItem(value: r, child: Text('$r%')),
                      ],
                      onChanged: _submitting ? null : (v) => setState(() => _gstRate = v ?? 0),
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: _field(_selling, 'Selling price ₹', number: true,
                        helper: 'Price charged to the customer'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(_mrp, 'MRP ₹', number: true,
                        helper: 'Maximum retail price printed on the pack'),
                  ),
                ]),
                const SizedBox(height: 18),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: _field(_purchase, 'Purchase price ₹', number: true,
                        helper: 'Your cost — used to calculate profit'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(_stock, 'Opening stock', number: true,
                        helper: 'Quantity currently in hand'),
                  ),
                ]),
                const SizedBox(height: 18),
                _field(_reorder, 'Reorder level', number: true,
                    helper: 'Low-stock alert triggers at or below this quantity'),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String label, {bool number = false, String? helper}) =>
      TextFormField(
        controller: c,
        keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 2,
        ),
      );
}
