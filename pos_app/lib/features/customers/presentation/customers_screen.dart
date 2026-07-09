// Customer list (local cache, populated by sync). Search by name/phone.
import 'package:flutter/material.dart';

import '../../../core/di/injector.dart';
import '../../../core/money/tax_engine.dart';
import '../../../data/local/database.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _search = TextEditingController();
  late Future<List<Customer>> _future;

  AppDatabase get _db => sl<AppDatabase>();

  @override
  void initState() {
    super.initState();
    _future = _db.partiesDao.allCustomers();
  }

  void _reload([String? term]) {
    setState(() {
      _future = (term == null || term.isEmpty)
          ? _db.partiesDao.allCustomers()
          : _db.partiesDao.searchCustomers(term);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name / phone'),
              onChanged: _reload,
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Customer>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snap.data ?? const [];
                if (items.isEmpty) {
                  return const Center(child: Text('No customers yet (they arrive via sync).'));
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = items[i];
                    return ListTile(
                      leading: CircleAvatar(child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?')),
                      title: Text(c.name),
                      subtitle: Text('${c.phone ?? ''}  ·  ${c.groupName}'),
                      trailing: c.balance != 0
                          ? Text('Due ${formatPaise(c.balance)}',
                              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))
                          : null,
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
