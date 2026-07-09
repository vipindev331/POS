// App navigation with authentication guards.
//   '/'       splash while the session is resolving
//   '/login'  unauthenticated
//   shell     authenticated (billing / products / customers / reports / settings)
// The redirect reads AuthCubit; a refreshListenable re-evaluates on auth change.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/di/injector.dart';
import '../features/auth/presentation/auth_cubit.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/billing/presentation/billing_screen.dart';
import '../features/customers/presentation/customers_screen.dart';
import '../features/products/presentation/products_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'shell_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: GoRouterRefreshStream(sl<AuthCubit>().stream),
  redirect: (context, state) {
    final status = sl<AuthCubit>().state.status;
    final loc = state.matchedLocation;

    if (status == AuthStatus.unknown) return loc == '/' ? null : '/';

    final loggingIn = loc == '/login';
    if (status == AuthStatus.unauthenticated) return loggingIn ? null : '/login';

    // Authenticated: bounce away from splash/login.
    if (loc == '/' || loc == '/login') return '/billing';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, _) => const _Splash()),
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => ShellScreen(navigationShell: shell),
      branches: [
        _branch('/billing', const BillingScreen()),
        _branch('/products', const ProductsScreen()),
        _branch('/customers', const CustomersScreen()),
        _branch('/reports', const ReportsScreen()),
        _branch('/settings', const SettingsScreen()),
      ],
    ),
  ],
);

StatefulShellBranch _branch(String path, Widget child) => StatefulShellBranch(
      routes: [GoRoute(path: path, builder: (_, _) => child)],
    );

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// Bridges a Cubit/Bloc stream to a Listenable so GoRouter re-runs redirects.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _sub;
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
