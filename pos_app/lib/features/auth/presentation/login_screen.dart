import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injector.dart';
import '../../settings/data/settings_repository.dart';
import 'auth_cubit.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await context.read<AuthCubit>().login(_username.text.trim(), _password.text);
    // Navigation is handled by the router's auth redirect.
    if (ok) {
      // Fetch the shared company profile so this user (incl. staff) sees it.
      unawaited(sl<SettingsRepository>().pullCompany());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.storefront, size: 48, color: scheme.primary),
                      const SizedBox(height: 12),
                      Text('Retail POS',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text('Sign in to continue',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.outline)),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _username,
                        // Avoid auto-popping the keyboard on phones.
                        autofocus: !isMobile,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline)),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter username' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                        validator: (v) => (v == null || v.isEmpty) ? 'Enter password' : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 20),
                      BlocBuilder<AuthCubit, AuthState>(
                        builder: (context, state) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (state.error != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(state.error!,
                                      style: TextStyle(color: scheme.error), textAlign: TextAlign.center),
                                ),
                              FilledButton(
                                onPressed: state.loading ? null : _submit,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: state.loading
                                      ? const SizedBox(
                                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Text('Sign in'),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text('Demo: manager / manager123  ·  staff / staff123',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: scheme.outline)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
