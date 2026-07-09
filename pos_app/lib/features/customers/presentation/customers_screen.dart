// Customer list (local cache, populated by sync). Search by name/phone.
// Any signed-in user (staff or manager) can add a customer; new customers are
// saved locally and queued for sync.
import 'package:flutter/material.dart';

import '../../../core/di/injector.dart';
import '../../../core/money/tax_engine.dart';
import '../../../data/local/database.dart';
import '../data/customers_repository.dart';

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

  Future<void> _addCustomer() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => const _CustomerFormDialog(),
    );
    if (added == true) {
      _reload(_search.text);
      _snack('Customer added');
    }
  }

  Future<void> _editCustomer(Customer c) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CustomerFormDialog(existing: c),
    );
    if (saved == true) {
      _reload(_search.text);
      _snack('Customer updated');
    }
  }

  Future<void> _deleteCustomer(Customer c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete customer'),
        content: Text('Delete "${c.name}"? This removes them from the list.'),
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
      await sl<CustomersRepository>().deleteCustomer(c.id);
      _reload(_search.text);
      _snack('Deleted ${c.name}');
    } catch (_) {
      _snack('Could not delete customer');
    }
  }

  void _snack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCustomer,
        icon: const Icon(Icons.person_add),
        label: const Text('Add customer'),
      ),
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
                      onTap: () => _editCustomer(c),
                      leading: CircleAvatar(child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?')),
                      title: Text(c.name),
                      subtitle: Text('${c.phone ?? ''}  ·  ${c.groupName}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (c.balance != 0)
                            Text('Due ${formatPaise(c.balance)}',
                                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                          PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') _editCustomer(c);
                              if (v == 'delete') _deleteCustomer(c);
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

/// Add a new customer, or edit [existing] when provided. Only the name is
/// required; the rest are optional. Pops `true` on success.
class _CustomerFormDialog extends StatefulWidget {
  final Customer? existing;
  const _CustomerFormDialog({this.existing});

  @override
  State<_CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<_CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _gstin = TextEditingController();
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    if (c != null) {
      _name.text = c.name;
      _phone.text = c.phone ?? '';
      _email.text = c.email ?? '';
      _gstin.text = c.gstin ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _gstin]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
      final repo = sl<CustomersRepository>();
      if (_isEdit) {
        await repo.updateCustomer(
          widget.existing!.id,
          name: _name.text.trim(),
          phone: t(_phone),
          email: t(_email),
          group: widget.existing!.groupName,
          creditLimit: widget.existing!.creditLimit,
          gstin: t(_gstin),
          stateCode: widget.existing!.stateCode,
        );
      } else {
        await repo.addCustomer(
          name: _name.text.trim(),
          phone: t(_phone),
          email: t(_email),
          gstin: t(_gstin),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save customer');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit customer' : 'Add customer'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone (optional)'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email (optional)'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _gstin,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'GSTIN (optional)'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
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
}
