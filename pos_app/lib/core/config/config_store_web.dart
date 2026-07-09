// Web config store: a single JSON blob in localStorage under one key.
import 'dart:convert';

import 'package:web/web.dart' as web;

import 'config_store.dart';

const _storageKey = 'pos_config';

ConfigStore createConfigStore() => WebConfigStore();

class WebConfigStore implements ConfigStore {
  Map<String, dynamic> _cache = {};

  @override
  Future<void> init() async {
    final raw = web.window.localStorage.getItem(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _cache = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        _cache = {};
      }
    }
  }

  @override
  Map<String, dynamic> readAll() => Map.of(_cache);

  @override
  T? read<T>(String key) => _cache[key] as T?;

  @override
  Future<void> write(String key, Object? value) async {
    _cache[key] = value;
    _flush();
  }

  @override
  Future<void> writeAll(Map<String, dynamic> map) async {
    _cache = Map.of(map);
    _flush();
  }

  void _flush() {
    web.window.localStorage.setItem(_storageKey, jsonEncode(_cache));
  }
}
