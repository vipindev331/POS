// Customer list (local cache, populated by sync). Search by name/phone.
// Any signed-in user (staff or manager) can add a customer; new customers are
// saved locally and queued for sync.
import 'package:flutter/material.dart';

import '../../../core/di/injector.dart';
import '../../../core/money/tax_engine.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/local/database.dart';
import '../../auth/data/auth_repository.dart';
import '../../sync/data/sync_engine.dart';
import '../data/customers_repository.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _search = TextEditingController();
  String _term = '';

  CustomersRepository get _repo => sl<CustomersRepository>();

  @override
  void initState() {
    super.initState();
    // Pull the latest from the server on open so the (reactive) list is fresh
    // immediately, rather than waiting for the next periodic sync tick.
    sl<SyncEngine>().syncNow();
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
    // The list is a live Drift stream, so it refreshes itself — no manual reload.
    if (added == true) _snack('Customer added');
  }

  Future<void> _editCustomer(Customer c) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CustomerFormDialog(existing: c),
    );
    if (saved == true) _snack('Customer updated');
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
      _snack('Deleted ${c.name}'); // list updates itself via the stream
    } catch (_) {
      _snack('Could not delete customer');
    }
  }

  void _snack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _viewDetails(Customer c) async {
    final action = await showDialog<String>(
      context: context,
      builder: (_) => _CustomerDetailDialog(customer: c),
    );
    if (action == 'edit') await _editCustomer(c);
    if (action == 'delete') await _deleteCustomer(c);
  }

  Widget _rowMenu(Customer c) => PopupMenuButton<String>(
        tooltip: 'Actions',
        onSelected: (v) {
          if (v == 'view') _viewDetails(c);
          if (v == 'edit') _editCustomer(c);
          if (v == 'delete') _deleteCustomer(c);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'view',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.info_outline),
              title: Text('View details'),
            ),
          ),
          PopupMenuItem(
            value: 'edit',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_outlined),
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
      );

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
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: AppSearchField(
              controller: _search,
              hintText: 'Search name / phone',
              onChanged: (v) => setState(() => _term = v.trim()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Customer>>(
              stream: _repo.watch(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snap.data ?? const [];
                final q = _term.toLowerCase();
                final items = q.isEmpty
                    ? all
                    : all
                        .where((c) =>
                            c.name.toLowerCase().contains(q) ||
                            (c.phone ?? '').toLowerCase().contains(q))
                        .toList();
                if (items.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.people_outline,
                    title: _term.isEmpty ? 'No customers yet' : 'No matches',
                    message: _term.isEmpty
                        ? 'Customers arrive through sync, or add one with the button below.'
                        : 'No customers match "$_term".',
                  );
                }
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: AppSpacing.contentMaxWidth),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 96),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Gap(AppSpacing.sm),
                      itemBuilder: (context, i) {
                        final c = items[i];
                        return AppListCard(
                          onTap: () => _viewDetails(c),
                          leading: AppAvatar(label: c.name),
                          title: c.name,
                          subtitle: [
                            if ((c.phone ?? '').isNotEmpty) c.phone,
                            c.groupName,
                          ].whereType<String>().join('  ·  '),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (c.balance != 0) ...[
                                StatusPill(
                                  label: 'DUE ${formatPaise(c.balance)}',
                                  color: const Color(0xFFF59E0B),
                                ),
                                const Gap(AppSpacing.xs),
                              ],
                              _rowMenu(c),
                            ],
                          ),
                        );
                      },
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

/// Read-only customer details, including the audit trail (who created / last
/// edited the record and when). Pops `'edit'` or `'delete'` to chain into those
/// flows, or null on close.
class _CustomerDetailDialog extends StatelessWidget {
  final Customer customer;
  const _CustomerDetailDialog({required this.customer});

  static String _dateTime(int? ms) {
    if (ms == null || ms == 0) return 'Unknown';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }

  static String _by(String? user) => (user == null || user.isEmpty) ? 'Unknown' : '@$user';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = customer;
    return AlertDialog(
      title: Row(
        children: [
          AppAvatar(label: c.name),
          const Gap(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                StatusPill(label: c.groupName.toUpperCase(), color: scheme.secondary),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _detail(context, Icons.phone_outlined, 'Phone', c.phone),
            _detail(context, Icons.email_outlined, 'Email', c.email),
            _detail(context, Icons.receipt_long_outlined, 'GSTIN', c.gstin),
            _detail(context, Icons.map_outlined, 'State code', c.stateCode),
            _detail(context, Icons.credit_score_outlined, 'Credit limit',
                c.creditLimit > 0 ? formatPaise(c.creditLimit) : null),
            _detail(context, Icons.account_balance_wallet_outlined, 'Balance',
                c.balance != 0 ? '${formatPaise(c.balance)} due' : 'Settled',
                highlight: c.balance != 0 ? const Color(0xFFF59E0B) : null),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Divider(height: 1),
            ),
            const SectionHeader('Audit trail'),
            _detail(context, Icons.person_add_alt, 'Created by',
                '${_by(c.createdBy)}  ·  ${_dateTime(c.createdAt)}'),
            _detail(context, Icons.edit_calendar_outlined, 'Last edited by',
                '${_by(c.updatedBy)}  ·  ${_dateTime(c.updatedAt)}'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop('delete'),
          style: TextButton.styleFrom(foregroundColor: scheme.error),
          child: const Text('Delete'),
        ),
        const Spacer(),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop('edit'),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit'),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
    );
  }

  Widget _detail(BuildContext context, IconData icon, String label, String? value,
      {Color? highlight}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const Gap(AppSpacing.md),
          SizedBox(
            width: 96,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(
              (value == null || value.isEmpty) ? '—' : value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: highlight ?? scheme.onSurface,
              ),
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
      final by = sl<AuthRepository>().cachedUser?.username;
      // Block duplicate phone/email up front for instant feedback (the server
      // enforces the same rule when the change syncs).
      final dupe = await repo.duplicateReason(
        phone: t(_phone),
        email: t(_email),
        exceptId: widget.existing?.id,
      );
      if (dupe != null) {
        if (mounted) setState(() => _error = dupe);
        return;
      }
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
          by: by,
        );
      } else {
        await repo.addCustomer(
          name: _name.text.trim(),
          phone: t(_phone),
          email: t(_email),
          gstin: t(_gstin),
          by: by,
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
