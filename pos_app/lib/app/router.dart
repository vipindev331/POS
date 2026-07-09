// App navigation. StatefulShellRoute keeps each section's navigation state.
// Auth/role guards are wired in Part 8 (allowDevBypass flips off then).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/dashboard/presentation/system_status_card.dart';
import '../shared/widgets/section_scaffold.dart';
import 'shell_screen.dart';

/// While auth UI (Part 8) is not yet built, allow entering the shell without
/// logging in. Part 8 sets this to false and adds a redirect guard.
const bool allowDevBypass = true;

final GoRouter appRouter = GoRouter(
  initialLocation: '/billing',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => ShellScreen(navigationShell: shell),
      branches: [
        _branch('/billing', const _BillingHome()),
        _branch('/products', const SectionScaffold(
          title: 'Products',
          body: ComingInPart(part: 5, feature: 'Product management'),
        )),
        _branch('/customers', const SectionScaffold(
          title: 'Customers',
          body: ComingInPart(part: 5, feature: 'Customer management'),
        )),
        _branch('/reports', const SectionScaffold(
          title: 'Reports',
          body: ComingInPart(part: 9, feature: 'Reports & dashboard'),
        )),
        _branch('/settings', const SectionScaffold(
          title: 'Settings',
          body: ComingInPart(part: 9, feature: 'Settings'),
        )),
      ],
    ),
  ],
);

StatefulShellBranch _branch(String path, Widget child) => StatefulShellBranch(
      routes: [GoRoute(path: path, builder: (_, _) => child)],
    );

class _BillingHome extends StatelessWidget {
  const _BillingHome();

  @override
  Widget build(BuildContext context) {
    return SectionScaffold(
      title: 'Billing',
      body: ListView(
        children: const [
          SystemStatusCard(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Core is wired (DI, config, network, connectivity, tax engine). '
              'The fast billing screen with barcode + F2–F12 shortcuts arrives in Part 5.',
            ),
          ),
        ],
      ),
    );
  }
}
