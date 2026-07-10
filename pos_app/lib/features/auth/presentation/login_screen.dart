import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme.dart';
import '../../../core/di/injector.dart';
import '../../settings/data/settings_repository.dart';
import 'auth_cubit.dart';

/// Sign-in screen. Adapts between a full split-panel layout on wide surfaces
/// (desktop / web / tablet-landscape) and a centred card on narrow ones
/// (phones / tablet-portrait) using [LayoutBuilder] so it responds to the
/// actual window size rather than the platform.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ok = await context.read<AuthCubit>().login(_username.text.trim(), _password.text);
    // Navigation is handled by the router's auth redirect.
    if (ok) {
      // Fetch the shared company profile so this user (incl. staff) sees it.
      unawaited(sl<SettingsRepository>().pullCompany());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Two-panel layout only when there's room for both the brand
          // artwork and a comfortable form column.
          final wide = constraints.maxWidth >= 900;
          if (wide) {
            return Row(
              children: [
                const Expanded(flex: 6, child: _BrandPanel()),
                Expanded(
                  flex: 5,
                  child: _FormPanel(
                    formKey: _formKey,
                    username: _username,
                    password: _password,
                    obscure: _obscure,
                    onToggleObscure: () => setState(() => _obscure = !_obscure),
                    onSubmit: _submit,
                  ),
                ),
              ],
            );
          }
          return _MobileLayout(
            formKey: _formKey,
            username: _username,
            password: _password,
            obscure: _obscure,
            onToggleObscure: () => setState(() => _obscure = !_obscure),
            onSubmit: _submit,
          );
        },
      ),
    );
  }
}

/// Left-hand marketing panel shown on wide layouts: gradient wash, product
/// name and a short list of what the suite does.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F766E), AppTheme.accent, Color(0xFF0369A1)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Image.asset('assets/logo.png', height: 140),
              ),
              const SizedBox(height: 40),
              const _BrandFeature(icon: Icons.wifi_off_rounded, label: 'Works offline, syncs automatically'),
              const SizedBox(height: 14),
              const _BrandFeature(icon: Icons.receipt_long_rounded, label: 'GST invoices & round-off handling'),
              const SizedBox(height: 14),
              const _BrandFeature(icon: Icons.inventory_2_rounded, label: 'Real-time stock across counters'),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandFeature extends StatelessWidget {
  final IconData icon;
  final String label;
  const _BrandFeature({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 14),
          ),
        ),
      ],
    );
  }
}

/// Centred form column used on the wide (two-panel) layout.
class _FormPanel extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController username;
  final TextEditingController password;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final Future<void> Function() onSubmit;

  const _FormPanel({
    required this.formKey,
    required this.username,
    required this.password,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: _LoginForm(
            formKey: formKey,
            username: username,
            password: password,
            obscure: obscure,
            onToggleObscure: onToggleObscure,
            onSubmit: onSubmit,
          ),
        ),
      ),
    );
  }
}

/// Mobile / narrow layout: a gradient hero header carrying the logo, with the
/// form sitting on a rounded sheet that overlaps it.
class _MobileLayout extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController username;
  final TextEditingController password;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final Future<void> Function() onSubmit;

  const _MobileLayout({
    required this.formKey,
    required this.username,
    required this.password,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final headerHeight = (media.size.height * 0.30).clamp(200.0, 300.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          // Fill at least the full viewport so the surface colour reaches the
          // bottom even when the form is short.
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: ColoredBox(
              color: scheme.surface,
              child: Column(
                children: [
                  // Gradient hero with the logo.
                  Container(
                    height: headerHeight,
                    width: double.infinity,
                    padding: EdgeInsets.only(top: media.padding.top + 8, bottom: 40),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0F766E), AppTheme.accent, Color(0xFF0369A1)],
                      ),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Image.asset('assets/logo.png', height: 96),
                      ),
                    ),
                  ),
                  // Form sheet, pulled up to overlap the hero's rounded corner.
                  Transform.translate(
                    offset: const Offset(0, -20),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                      child: _LoginForm(
                        formKey: formKey,
                        username: username,
                        password: password,
                        obscure: obscure,
                        onToggleObscure: onToggleObscure,
                        onSubmit: onSubmit,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Shared sign-in form body (heading, fields, error, submit button). Laid out
/// with stretched columns so it fills whatever width its parent gives it.
class _LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController username;
  final TextEditingController password;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final Future<void> Function() onSubmit;

  const _LoginForm({
    required this.formKey,
    required this.username,
    required this.password,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 25),
          Text(
            'Welcome back',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sign in to your account to continue',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 32),
          _FieldLabel('Username', scheme),
          const SizedBox(height: 6),
          TextFormField(
            controller: username,
            autofocus: !isMobile,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            decoration: const InputDecoration(
              hintText: 'Enter your username',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter username' : null,
          ),
          const SizedBox(height: 18),
          _FieldLabel('Password', scheme),
          const SizedBox(height: 6),
          TextFormField(
            controller: password,
            obscureText: obscure,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                tooltip: obscure ? 'Show password' : 'Hide password',
                onPressed: onToggleObscure,
              ),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Enter password' : null,
            onFieldSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 24),
          BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: scheme.error.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: scheme.error, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              state.error!,
                              style: TextStyle(color: scheme.error, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: state.loading ? null : onSubmit,
                      child: state.loading
                          ? const SizedBox(
                              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Sign in', style: TextStyle(fontSize: 15)),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final ColorScheme scheme;
  const _FieldLabel(this.text, this.scheme);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
