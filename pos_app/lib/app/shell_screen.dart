// Adaptive navigation shell: NavigationRail on wide screens (desktop/web/tablet),
// BottomNavigationBar on narrow (phones). Hosts the feature sections.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/user_menu.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    if (wide) {
      // Sky-blue side menu with white icons/labels; on-primary is the
      // theme-computed contrast colour for text/icons over primary.
      final onRail = scheme.onPrimary;
      final onRailDim = scheme.onPrimary.withValues(alpha: 0.75);
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: scheme.primary,
              indicatorColor: scheme.onPrimary.withValues(alpha: 0.20),
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _go,
              labelType: NavigationRailLabelType.all,
              selectedIconTheme: IconThemeData(color: onRail),
              unselectedIconTheme: IconThemeData(color: onRailDim),
              selectedLabelTextStyle: TextStyle(color: onRail, fontWeight: FontWeight.w600),
              unselectedLabelTextStyle: TextStyle(color: onRailDim),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Icon(Icons.storefront, size: 28, color: onRail),
              ),
              trailing: const Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(padding: EdgeInsets.only(bottom: 12), child: UserMenu()),
                ),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
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

class _Dest {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _Dest(this.label, this.icon, this.selectedIcon);
}
