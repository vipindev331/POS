import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'auth_cubit.dart';

/// Avatar + popup showing the signed-in user and a logout action.
class UserMenu extends StatelessWidget {
  const UserMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final user = state.user;
        final initial = (user?.fullName.isNotEmpty ?? false)
            ? user!.fullName[0].toUpperCase()
            : (user?.username.isNotEmpty ?? false)
                ? user!.username[0].toUpperCase()
                : '?';
        return PopupMenuButton<String>(
          tooltip: user?.username ?? 'Account',
          onSelected: (value) {
            if (value == 'logout') context.read<AuthCubit>().logout();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(user?.fullName.isNotEmpty == true ? user!.fullName : user?.username ?? ''),
                subtitle: Text('Role: ${user?.role ?? '-'}'),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.logout),
                title: Text('Sign out'),
              ),
            ),
          ],
          child: CircleAvatar(radius: 16, child: Text(initial)),
        );
      },
    );
  }
}
