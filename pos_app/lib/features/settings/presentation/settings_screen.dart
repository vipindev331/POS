// Store configuration: company profile (shown on receipts) + printer setup.
// Persisted via ConfigStore — a JSON file on native, localStorage on web —
// and consumed by the printing service.
import 'package:flutter/material.dart';

import '../../../app/theme_controller.dart';
import '../../../core/config/config_store.dart';
import '../../../core/di/injector.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/user_menu.dart';
import '../../printing/data/receipt_printer.dart';
import '../data/settings_repository.dart';
import 'staff_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ConfigStore get _config => sl<ConfigStore>();
  SettingsRepository get _settings => sl<SettingsRepository>();

  // Company details (shown on receipts) are edited by admins or managers.
  // Both roles can also open the Team (user management) area.
  bool get _isAdmin => sl<AuthRepository>().cachedUser?.isAdmin ?? false;
  bool get _isManager => sl<AuthRepository>().cachedUser?.isManager ?? false;
  bool get _canManageUsers => _isAdmin || _isManager;
  bool get _canEditCompany => _isAdmin || _isManager;

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

    // Refresh company details from the backend so staff (and other devices)
    // always see the manager's latest saved profile.
    WidgetsBinding.instance.addPostFrameCallback((_) => _pullCompany());
  }

  Future<void> _pullCompany() async {
    final company = await _settings.pullCompany();
    if (company == null || !mounted) return;
    setState(() {
      _name.text = (company['name'] ?? '') as String;
      _gstin.text = (company['gstin'] ?? '') as String;
      _address.text = (company['address'] ?? '') as String;
      _phone.text = (company['phone'] ?? '') as String;
      _email.text = (company['email'] ?? '') as String;
    });
  }

  Future<void> _save() async {
    // Company details are shared: the admin pushes them to the backend so every
    // device/user receives them. Everyone else can still adjust printer setup.
    bool companyOffline = false;
    if (_canEditCompany) {
      final synced = await _settings.saveCompany({
        'name': _name.text.trim(),
        'gstin': _gstin.text.trim(),
        'address': _address.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'currency': 'INR',
      });
      companyOffline = !synced;
    }
    // Printer setup stays device-local.
    await _config.write('printer', {
      'kind': _printerKind.name,
      'host': _host.text.trim(),
      'port': int.tryParse(_port.text) ?? 9100,
      'width': _width,
    });
    if (mounted) {
      final msg = companyOffline
          ? 'Saved on this device, but could not reach the server — reopen and Save when online to share with staff'
          : 'Settings saved';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
          // Account + sign-out — the only screen an admin can reach, so it must
          // carry logout (mobile has no sidebar).
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Center(child: UserMenu()),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              SectionCard(
                title: 'Appearance',
                child: ValueListenableBuilder<ThemeMode>(
                  valueListenable: sl<ThemeController>(),
                  builder: (context, mode, _) => SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('System')),
                      ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ],
                    selected: {mode},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => sl<ThemeController>().set(s.first),
                  ),
                ),
              ),
              const Gap(AppSpacing.lg),
              SectionCard(
                title: 'Company',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_canEditCompany)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Text(
                          'Only an admin or manager can edit company details.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    _field(_name, 'Company name', enabled: _canEditCompany),
                    _field(_gstin, 'GSTIN', enabled: _canEditCompany),
                    _field(_address, 'Address', enabled: _canEditCompany),
                    _field(_phone, 'Phone', enabled: _canEditCompany),
                    _field(_email, 'Email', enabled: _canEditCompany, last: true),
                  ],
                ),
              ),
              const Gap(AppSpacing.lg),
              SectionCard(
                title: 'Receipt printer',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<PrinterKind>(
                      initialValue: _printerKind,
                      decoration: const InputDecoration(labelText: 'Printer type'),
                      items: PrinterKind.values
                          .map((k) => DropdownMenuItem(value: k, child: Text(k.name)))
                          .toList(),
                      onChanged: (v) => setState(() => _printerKind = v ?? PrinterKind.network),
                    ),
                    const Gap(AppSpacing.md),
                    if (_printerKind == PrinterKind.network) ...[
                      _field(_host, 'Printer IP / host'),
                      _field(_port, 'Port', keyboard: TextInputType.number),
                    ],
                    DropdownButtonFormField<int>(
                      initialValue: _width,
                      decoration: const InputDecoration(labelText: 'Paper width'),
                      items: const [
                        DropdownMenuItem(value: 48, child: Text('80mm (48 cols)')),
                        DropdownMenuItem(value: 32, child: Text('58mm (32 cols)')),
                      ],
                      onChanged: (v) => setState(() => _width = v ?? 48),
                    ),
                  ],
                ),
              ),
              if (_canManageUsers) ...[
                const Gap(AppSpacing.lg),
                SectionCard(
                  title: 'Team',
                  childPadding: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                    leading: const AppAvatar(icon: Icons.group_outlined),
                    title: Text(_isAdmin ? 'Users & members' : 'Staff & members'),
                    subtitle: Text(_isAdmin
                        ? 'Manage staff and manager accounts'
                        : 'Add, edit, delete, or reset staff passwords'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StaffScreen()),
                    ),
                  ),
                ),
              ],
              const Gap(AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
          {TextInputType? keyboard, bool enabled = true, bool last = false}) =>
      Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.md),
        child: TextField(
          controller: c,
          keyboardType: keyboard,
          enabled: enabled,
          decoration: InputDecoration(labelText: label),
        ),
      );
}
