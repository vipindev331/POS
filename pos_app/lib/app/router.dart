// App navigation. StatefulShellRoute keeps each section's navigation state.
// Auth/role guards are wired in Part 8 (allowDevBypass flips off then).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/billing/presentation/billing_screen.dart';
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
        _branch('/billing', const BillingScreen()),
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
