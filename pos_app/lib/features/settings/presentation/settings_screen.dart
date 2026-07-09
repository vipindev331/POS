// Store configuration: company profile (shown on receipts) + printer setup.
// Persisted via ConfigStore — a JSON file on native, localStorage on web —
// and consumed by the printing service.
import 'package:flutter/material.dart';

import '../../../core/config/config_store.dart';
import '../../../core/di/injector.dart';
import '../../auth/data/auth_repository.dart';
import '../../printing/data/receipt_printer.dart';
import 'staff_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ConfigStore get _config => sl<ConfigStore>();

  // Only managers may edit company details (they appear on receipts).
  bool get _isManager => sl<AuthRepository>().cachedUser?.isManager ?? false;

  final _name = TextEditingController();
  final _gstin = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  PrinterKind _printerKind = PrinterKind.network;
  final _host = TextEditingController();
  final _port = TextEditingController(text: '9100');
  int _width = 48;

  @override
  void initState() {
    super.initState();
    final company = (_config.read<Map>('company') ?? const {}).cast<String, dynamic>();
    _name.text = (company['name'] ?? '') as String;
    _gstin.text = (company['gstin'] ?? '') as String;
    _address.text = (company['address'] ?? '') as String;
    _phone.text = (company['phone'] ?? '') as String;
    _email.text = (company['email'] ?? '') as String;

    final printer = (_config.read<Map>('printer') ?? const {}).cast<String, dynamic>();
    _printerKind = PrinterKind.values.firstWhere(
      (k) => k.name == (printer['kind'] ?? 'network'),
      orElse: () => PrinterKind.network,
    );
    _host.text = (printer['host'] ?? '') as String;
    _port.text = ((printer['port'] ?? 9100)).toString();
    _width = (printer['width'] as num?)?.toInt() ?? 48;
  }

  Future<void> _save() async {
    // Staff can adjust printer setup but not company details.
    if (_isManager) {
      await _config.write('company', {
        'name': _name.text.trim(),
        'gstin': _gstin.text.trim(),
        'address': _address.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'currency': 'INR',
      });
    }
    await _config.write('printer', {
      'kind': _printerKind.name,
      'host': _host.text.trim(),
      'port': int.tryParse(_port.text) ?? 9100,
      'width': _width,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _gstin, _address, _phone, _email, _host, _port]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Save')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(context, 'Company'),
          if (!_isManager)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Only a manager can edit company details.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          _field(_name, 'Company name', enabled: _isManager),
          _field(_gstin, 'GSTIN', enabled: _isManager),
          _field(_address, 'Address', enabled: _isManager),
          _field(_phone, 'Phone', enabled: _isManager),
          _field(_email, 'Email', enabled: _isManager),
          const SizedBox(height: 24),
          _section(context, 'Receipt printer'),
          DropdownButtonFormField<PrinterKind>(
            initialValue: _printerKind,
            decoration: const InputDecoration(labelText: 'Printer type'),
            items: PrinterKind.values
                .map((k) => DropdownMenuItem(value: k, child: Text(k.name)))
                .toList(),
            onChanged: (v) => setState(() => _printerKind = v ?? PrinterKind.network),
          ),
          const SizedBox(height: 12),
          if (_printerKind == PrinterKind.network) ...[
            _field(_host, 'Printer IP / host'),
            _field(_port, 'Port', keyboard: TextInputType.number),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _width,
            decoration: const InputDecoration(labelText: 'Paper width'),
            items: const [
              DropdownMenuItem(value: 48, child: Text('80mm (48 cols)')),
              DropdownMenuItem(value: 32, child: Text('58mm (32 cols)')),
            ],
            onChanged: (v) => setState(() => _width = v ?? 48),
          ),
          if (_isManager) ...[
            const SizedBox(height: 24),
            _section(context, 'Team'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.group),
              title: const Text('Staff & members'),
              subtitle: const Text('Add, edit, delete, or reset passwords'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StaffScreen()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _field(TextEditingController c, String label,
          {TextInputType? keyboard, bool enabled = true}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: keyboard,
          enabled: enabled,
          decoration: InputDecoration(labelText: label),
        ),
      );
}
