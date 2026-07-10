// Surface containers shared across screens: a plain bordered card, a titled
// section panel, and a standalone section header. These give every screen the
// same rounded, hairline-bordered "Management Suite" look.
import 'package:flutter/material.dart';

import 'spacing.dart';

/// A bordered, rounded surface. Optionally tappable.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: scheme.outlineVariant),
    );
    return Material(
      color: color ?? scheme.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

/// A small section title placed above a group of settings/content.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  const SectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md, top: AppSpacing.xs),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            Text(trailing!,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

/// A titled panel: header row, divider, then content. Used for the dashboard's
/// Recent Bills / Top Products and grouped settings blocks.
class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  final EdgeInsetsGeometry childPadding;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.action,
    this.childPadding = const EdgeInsets.all(AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
                ?action,
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: childPadding, child: child),
        ],
      ),
    );
  }
}
