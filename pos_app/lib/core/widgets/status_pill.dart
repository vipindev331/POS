// Small rounded status badge (a "pill"). Used for stock states, dues, roles,
// bill status, etc. Tinted from a single colour so every badge in the app reads
// the same way.
import 'package:flutter/material.dart';

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  /// When true, fills with [color] and uses white text (for strong emphasis);
  /// otherwise shows a soft tinted background with coloured text (the default).
  final bool solid;

  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = solid ? Colors.white : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
