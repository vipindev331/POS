// A consistent list row rendered as a bordered card: leading avatar/icon,
// title + subtitle, and a trailing widget (price, pill, menu…). Used by the
// Products / Customers / Staff / Sold list screens so every list looks the same.
import 'package:flutter/material.dart';

import 'spacing.dart';

/// Circular avatar with either an initial letter or an icon, tinted from a
/// colour (defaults to the primary accent).
class AppAvatar extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final Color? color;
  final double radius;

  const AppAvatar({super.key, this.label, this.icon, this.color, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.primary;
    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: icon != null
          ? Icon(icon, size: radius, color: tint)
          : Text(
              (label != null && label!.isNotEmpty) ? label![0].toUpperCase() : '?',
              style: TextStyle(color: tint, fontWeight: FontWeight.w700, fontSize: radius * 0.8),
            ),
    );
  }
}

class AppListCard extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const AppListCard({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const Gap(AppSpacing.md)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const Gap(AppSpacing.sm), trailing!],
        ],
      ),
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: scheme.outlineVariant),
    );
    return Material(
      color: scheme.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? row : InkWell(onTap: onTap, child: row),
    );
  }
}
