// Adaptive navigation shell. Wide screens (desktop/web/tablet) get a full
// "Management Suite" sidebar — logo header, labelled destinations with a blue
// active pill, and account/support pinned to the bottom. Narrow screens fall
// back to a BottomNavigationBar. Hosts every feature section.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/di/injector.dart';
import '../features/auth/presentation/auth_cubit.dart';
import '../features/auth/presentation/user_menu.dart';
import 'theme.dart';

class ShellScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const ShellScreen({super.key, required this.navigationShell});

  // Order must match the router's StatefulShellRoute branches (index = branch).
  // Each destination lists the roles allowed to see it:
  //  · staff/manager run the store · manager also gets Reports
  //  · admin is a restricted back-office role — only Settings (users + company).
  static const _destinations = [
    _Dest('Billing', Icons.point_of_sale_outlined, Icons.point_of_sale, ['staff', 'manager']),
    _Dest('Products', Icons.inventory_2_outlined, Icons.inventory_2, ['staff', 'manager']),
    _Dest('Customers', Icons.people_outline, Icons.people, ['staff', 'manager']),
    _Dest('Reports', Icons.bar_chart_outlined, Icons.bar_chart, ['manager']),
    _Dest('Sold', Icons.sell_outlined, Icons.sell, ['staff', 'manager']),
    _Dest('Settings', Icons.settings_outlined, Icons.settings, ['staff', 'manager', 'admin']),
  ];

  void _go(int branchIndex) => navigationShell.goBranch(
        branchIndex,
        initialLocation: branchIndex == navigationShell.currentIndex,
      );

  @override
  Widget build(BuildContext context) {
    final role = sl<AuthCubit>().state.user?.role ?? 'staff';
    // Destinations the current role may see, paired with their true branch index
    // so filtering never misroutes navigation.
    final visible = <({int branch, _Dest dest})>[
      for (var i = 0; i < _destinations.length; i++)
        if (_destinations[i].roles.contains(role))
          (branch: i, dest: _destinations[i]),
    ];
    final sel = visible.indexWhere((e) => e.branch == navigationShell.currentIndex);
    final selectedIndex = sel < 0 ? 0 : sel;

    final wide = MediaQuery.sizeOf(context).width >= 720;
    final Widget scaffold = wide
        ? Scaffold(
            body: Row(
              children: [
                _Sidebar(
                  currentBranch: navigationShell.currentIndex,
                  onSelect: _go,
                  destinations: visible,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: navigationShell),
              ],
            ),
          )
        : Scaffold(
            body: navigationShell,
            // NavigationBar requires 2+ destinations; a single-section role
            // (e.g. the admin, who only has Settings) shows no bottom bar.
            bottomNavigationBar: visible.length < 2
                ? null
                : NavigationBar(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (i) => _go(visible[i].branch),
                    destinations: [
                      for (final e in visible)
                        NavigationDestination(
                          icon: Icon(e.dest.icon),
                          selectedIcon: Icon(e.dest.selectedIcon),
                          label: e.dest.label,
                        ),
                    ],
                  ),
          );

    // On Android, the hardware back button at a branch root would exit the app.
    // Intercept it to confirm first. (Pushed pages within a branch still pop
    // normally — this only fires once the branch has nothing left to pop.)
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    return PopScope(
      canPop: !isAndroid,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !isAndroid) return;
        final shouldExit = await _confirmExit(context);
        if (shouldExit) await SystemNavigator.pop();
      },
      child: scaffold,
    );
  }

  Future<bool> _confirmExit(BuildContext context) async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit app?'),
        content: const Text('Do you want to close the app?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Exit')),
        ],
      ),
    );
    return exit ?? false;
  }
}

class _Sidebar extends StatelessWidget {
  final int currentBranch;
  final ValueChanged<int> onSelect;
  final List<({int branch, _Dest dest})> destinations;
  const _Sidebar({required this.currentBranch, required this.onSelect, required this.destinations});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      color: AppTheme.sidebar(context),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _LogoHeader(),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final e in destinations)
                    _NavItem(
                      dest: e.dest,
                      selected: e.branch == currentBranch,
                      onTap: () => onSelect(e.branch),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            _SupportTile(),
            const _AccountTile(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _LogoHeader extends StatelessWidget {
  const _LogoHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset('assets/logo.png', width: 42, height: 42, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NxtCust POS',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  )),
              Text('MANAGEMENT SUITE',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _Dest dest;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.dest, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected ? AppTheme.navActive : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(selected ? dest.selectedIcon : dest.icon, size: 20, color: fg),
                const SizedBox(width: 14),
                Text(
                  dest.label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.help_outline, size: 20),
      title: const Text('Support', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      dense: true,
      onTap: () => showAboutDialog(
        context: context,
        applicationName: 'NxtCust POS',
        applicationVersion: 'Management Suite',
        children: const [Text('For help, contact your administrator.')],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final user = state.user;
        final name = (user?.fullName.isNotEmpty ?? false)
            ? user!.fullName
            : (user?.username ?? 'Account');
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      (user?.role ?? '').toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const UserMenu(),
            ],
          ),
        );
      },
    );
  }
}

class _Dest {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final List<String> roles; // roles permitted to see this destination
  const _Dest(this.label, this.icon, this.selectedIcon, this.roles);
}
