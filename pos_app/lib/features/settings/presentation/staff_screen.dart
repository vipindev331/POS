// Manager-only staff/member management: list all accounts and add, edit,
// delete, or reset the password for each. All operations go through the
// backend (manager role enforced server-side) and require connectivity.
import 'package:flutter/material.dart';

import '../../../core/di/injector.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_user.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  AuthRepository get _auth => sl<AuthRepository>();

  late Future<List<AuthUser>> _future;
  String? get _currentUserId => _auth.cachedUser?.id;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _auth.listUsers();
    });
  }

  Future<void> _addStaff() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const StaffFormDialog(),
    );
    if (created == true) {
      _snack('Account created');
      _reload();
    }
  }

  Future<void> _editStaff(AuthUser user) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StaffFormDialog(existing: user),
    );
    if (saved == true) {
      _snack('Account updated');
      _reload();
    }
  }

  Future<void> _resetPassword(AuthUser user) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => _ResetPasswordDialog(user: user),
    );
    if (done == true) _snack('Password reset for ${user.username}');
  }

  Future<void> _deleteStaff(AuthUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account'),
        content: Text('Delete "${user.username}"? They will no longer be able to sign in.'),
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
      await _auth.deleteUser(user.id);
      _snack('Deleted ${user.username}');
      _reload();
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Cannot reach server');
    }
  }

  void _snack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff & members'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addStaff,
        icon: const Icon(Icons.person_add),
        label: const Text('Add'),
      ),
      body: FutureBuilder<List<AuthUser>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorState(message: '${snap.error}', onRetry: _reload);
          }
          final users = snap.data ?? const [];
          if (users.isEmpty) {
            return const Center(child: Text('No accounts yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: users.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final u = users[i];
              final isSelf = u.id == _currentUserId;
              final display = u.fullName.isNotEmpty ? u.fullName : u.username;
              return ListTile(
                leading: CircleAvatar(child: Text(display[0].toUpperCase())),
                title: Text(display),
                subtitle: Text('@${u.username} · ${u.role}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    switch (v) {
                      case 'edit':
                        _editStaff(u);
                      case 'reset':
                        _resetPassword(u);
                      case 'delete':
                        _deleteStaff(u);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit),
                        title: Text('Edit'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'reset',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.lock_reset),
                        title: Text('Reset password'),
                      ),
                    ),
                    // Cannot delete your own account.
                    if (!isSelf)
                      const PopupMenuItem(
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
              );
            },
          );
        },
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 40),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// Create a new account, or edit an existing one when [existing] is provided.
/// Pops `true` on success. Username is immutable; password is set via the
/// separate reset flow when editing.
class StaffFormDialog extends StatefulWidget {
  final AuthUser? existing;
  const StaffFormDialog({super.key, this.existing});

  @override
  State<StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends State<StaffFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _fullName = TextEditingController();
  final _password = TextEditingController();
  String _role = 'staff';
  bool _canManageProducts = false;
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final u = widget.existing;
    if (u != null) {
      _username.text = u.username;
      _fullName.text = u.fullName;
      _role = u.role;
      _canManageProducts = u.permissions.contains(kPermManageProducts);
    }
  }

  // Assemble the permission list to send to the backend.
  List<String> get _permissions => [
        if (_canManageProducts) kPermManageProducts,
      ];

  @override
  void dispose() {
    _username.dispose();
    _fullName.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final auth = sl<AuthRepository>();
      if (_isEdit) {
        await auth.updateUser(
          widget.existing!.id,
          fullName: _fullName.text.trim(),
          role: _role,
          permissions: _permissions,
        );
      } else {
        await auth.createUser(
          username: _username.text.trim(),
          password: _password.text,
          fullName: _fullName.text.trim(),
          role: _role,
          permissions: _permissions,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Cannot reach server');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit account' : 'Add staff'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _fullName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _username,
                autocorrect: false,
                enabled: !_isEdit, // username is immutable
                decoration: InputDecoration(
                  labelText: 'Username',
                  helperText: _isEdit ? 'Username cannot be changed' : null,
                ),
                validator: (v) =>
                    (v == null || v.trim().length < 3) ? 'At least 3 characters' : null,
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'At least 6 characters' : null,
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'staff', child: Text('Staff')),
                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                ],
                onChanged: _submitting ? null : (v) => setState(() => _role = v ?? 'staff'),
              ),
              // Permissions only apply to staff — managers can do everything.
              if (_role == 'staff') ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _canManageProducts,
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _canManageProducts = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Can edit & delete products'),
                  subtitle: const Text('Allow this staff member to change or remove product details'),
                ),
              ],
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
              : Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  final AuthUser user;
  const _ResetPasswordDialog({required this.user});

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await sl<AuthRepository>().resetPassword(widget.user.id, _password.text);
      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Cannot reach server');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reset password · @${widget.user.username}'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'New password',
              errorText: _error,
            ),
            validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
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
              : const Text('Reset'),
        ),
      ],
    );
  }
}
