// Design tokens + light/dark themes. A "Management Suite" design system: a
// bright mint-teal accent for actions/highlights and a distinct sky-blue for
// the active navigation item, over either dark near-black or light surfaces.
// Widgets read surface/text colours from Theme.of(context).colorScheme so both
// modes recolour automatically; only the two brand colours are fixed.
import 'package:flutter/material.dart';

class AppTheme {
  // Brand colours — identical in both modes.
  static const accent = Color(0xFF2DD4BF); // teal — buttons, highlights, chips
  static const navActive = Color.fromARGB(255, 3, 72, 104); // blue — active navigation pill

  /// Sidebar background, adapted to the current brightness.
  static Color sidebar(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? const Color.fromARGB(255, 31, 38, 48) : Colors.white;

  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(
      primary: accent,
      onPrimary: const Color(0xFF04211C),
      secondary: navActive,
      onSecondary: Colors.white,
      error: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
      // Surface ramp (roles used throughout the redesigned widgets).
      surface: isDark ? const Color(0xFF171B1F) : Colors.white,
      onSurface: isDark ? const Color(0xFFE7EBEE) : const Color(0xFF0F1720),
      onSurfaceVariant: isDark ? const Color(0xFF98A1A9) : const Color(0xFF5A6672),
      surfaceContainerLowest: isDark ? const Color(0xFF0B0E11) : Colors.white,
      surfaceContainerLow: isDark ? const Color(0xFF12171B) : const Color(0xFFF7F8FA),
      surfaceContainer: isDark ? const Color(0xFF171B1F) : Colors.white,
      surfaceContainerHigh: isDark ? const Color(0xFF1B2126) : const Color(0xFFF1F3F6),
      surfaceContainerHighest: isDark ? const Color(0xFF20272D) : const Color(0xFFE9ECF1),
      outline: isDark ? const Color(0xFF3A434B) : const Color(0xFFC7CDD5),
      outlineVariant: isDark ? const Color(0xFF262D33) : const Color(0xFFE2E6EB),
    );

    final bg = isDark ? const Color.fromARGB(255, 36, 37, 37) : const Color.fromARGB(255, 237, 239, 240);
    final border = scheme.outlineVariant;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      visualDensity: VisualDensity.compact,
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: isDark ? bg : Colors.white,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: isDark ? const Color(0xFF12171B) : const Color(0xFFF3F5F8),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: const Color(0xFF04211C),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: isDark ? accent : const Color(0xFF0E7C6E)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: accent.withValues(alpha: isDark ? 0.14 : 0.16),
        side: BorderSide(color: accent.withValues(alpha: 0.35)),
        labelStyle: TextStyle(
            color: isDark ? accent : const Color(0xFF0E7C6E),
            fontWeight: FontWeight.w600,
            fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: isDark ? accent : const Color(0xFF0E7C6E),
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: accent,
        dividerColor: border,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppTheme._navBar(isDark),
        indicatorColor: navActive,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: s.contains(WidgetState.selected) ? navActive : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? Colors.white : scheme.onSurfaceVariant,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF20272D) : const Color(0xFF2B333B),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),
    );
  }

  static Color _navBar(bool isDark) =>
      isDark ? const Color(0xFF0C1013) : Colors.white;
}
