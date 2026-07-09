// Product catalog viewer. Reads the local Drift cache reactively (works
// offline); a refresh pulls the latest from the backend.
import 'package:flutter/material.dart';

import '../../../core/di/injector.dart';
import '../../../core/money/tax_engine.dart';
import '../../../data/local/database.dart';
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
                      title: Text(p.name),
                      subtitle: Text('${p.barcode ?? p.sku ?? ''}  ·  GST ${p.gstRate}%'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(formatPaise(p.sellingPrice), style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Stock ${p.stock}',
                              style: TextStyle(fontSize: 12, color: low ? Colors.orange : null)),
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
