// Holds the app's ThemeMode and persists the user's choice via ConfigStore.
// The MaterialApp listens to this notifier so toggling recolours instantly.
import 'package:flutter/material.dart';

import '../core/config/config_store.dart';

class ThemeController extends ValueNotifier<ThemeMode> {
  final ConfigStore _config;
  static const _key = 'themeMode';

  ThemeController(this._config) : super(_read(_config));

  static ThemeMode _read(ConfigStore c) {
    switch (c.read<String>(_key)) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  bool get isDark => value == ThemeMode.dark;

  void toggle() => set(value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  void set(ThemeMode mode) {
    if (mode == value) return;
    value = mode;
    _config.write(_key, mode.name);
  }
}
