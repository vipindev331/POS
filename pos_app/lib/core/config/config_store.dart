/// Platform-agnostic key/value configuration store interface.
///
/// Native (desktop/mobile) persists a JSON file; web uses localStorage.
/// The concrete implementation is chosen by [createConfigStore] via a
/// conditional import — business logic never sees `dart:io` or `dart:html`.
library;

import 'config_store_factory.dart'
    if (dart.library.io) 'config_store_native.dart'
    if (dart.library.js_interop) 'config_store_web.dart' as impl;

abstract class ConfigStore {
  Future<void> init();

  /// Read the entire config map.
  Map<String, dynamic> readAll();

  /// Read a single top-level key.
  T? read<T>(String key);

  /// Persist a single top-level key.
  Future<void> write(String key, Object? value);

  /// Replace the whole map.
  Future<void> writeAll(Map<String, dynamic> map);
}

/// Selects the correct platform implementation at compile time.
ConfigStore createConfigStore() => impl.createConfigStore();
