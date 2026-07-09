// Adaptive navigation shell. Wide screens (desktop/web/tablet) get a full
// "Management Suite" sidebar — logo header, labelled destinations with a blue
// active pill, and account/support pinned to the bottom. Narrow screens fall
// back to a BottomNavigationBar. Hosts every feature section.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/di/injector.dart';
import '../features/auth/presentation/auth_cubit.dart';
import '../features/auth/presentation/user_menu.dart';
import 'theme.dart';
import 'theme_controller.dart';

class ShellScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const ShellScreen({super.key, required this.navigationShell});

  static const _destinations = [
    _Dest('Billing', Icons.point_of_sale_outlined, Icons.point_of_sale),
    _Dest('Products', Icons.inventory_2_outlined, Icons.inventory_2),
    _Dest('Customers', Icons.people_outline, Icons.people),
    _Dest('Reports', Icons.bar_chart_outlined, Icons.bar_chart),
    _Dest('Settings', Icons.settings_outlined, Icons.settings),
  ];

  void _go(int index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              current: navigationShell.currentIndex,
              onSelect: _go,
              destinations: _destinations,
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _go,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int current;
  final ValueChanged<int> onSelect;
  final List<_Dest> destinations;
  const _Sidebar({required this.current, required this.onSelect, required this.destinations});

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
                  for (var i = 0; i < destinations.length; i++)
                    _NavItem(
                      dest: destinations[i],
                      selected: i == current,
                      onTap: () => onSelect(i),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            const _ThemeToggleTile(),
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
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.storefront, color: Color(0xFF04211C), size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Retail POS',
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

class _ThemeToggleTile extends StatelessWidget {
  const _ThemeToggleTile();

  @override
  Widget build(BuildContext context) {
    final controller = sl<ThemeController>();
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: controller,
      builder: (context, _, _) {
        final dark = controller.isDark;
        return ListTile(
          leading: Icon(dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined, size: 20),
          title: Text(dark ? 'Dark mode' : 'Light mode',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          trailing: Switch(value: dark, onChanged: (_) => controller.toggle()),
          dense: true,
          onTap: controller.toggle,
        );
      },
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
        applicationName: 'Retail POS',
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
  const _Dest(this.label, this.icon, this.selectedIcon);
}
