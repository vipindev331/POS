// Shared spacing scale and page-layout constants for the whole app. Using one
// set of steps everywhere keeps padding and gaps consistent across screens.
import 'package:flutter/widgets.dart';

/// Named spacing steps (logical pixels). Prefer these over ad-hoc numbers so
/// every screen breathes at the same rhythm.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Standard page gutter used for screen bodies.
  static const EdgeInsets pagePadding = EdgeInsets.all(lg);

  /// Max width a content column should grow to on wide screens, so lists and
  /// forms stay readable on desktop instead of stretching edge-to-edge.
  static const double contentMaxWidth = 900;
}

/// A fixed-size gap. `const Gap(16)` in a Column adds 16px of vertical space
/// (or horizontal inside a Row). One widget instead of sized boxes everywhere.
class Gap extends StatelessWidget {
  final double size;
  const Gap(this.size, {super.key});

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size);
}
