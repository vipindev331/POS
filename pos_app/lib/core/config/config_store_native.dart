// Native (desktop + mobile) config store: a JSON file in the app support dir.
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'config_store.dart';

ConfigStore createConfigStore() => NativeConfigStore();

class NativeConfigStore implements ConfigStore {
  File? _file;
  Map<String, dynamic> _cache = {};

  @override
  Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/pos_config.json');
    _file = file;
    if (await file.exists()) {
      try {
        _cache = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        _cache = {};
      }
    } else {
      await file.create(recursive: true);
      await file.writeAsString('{}');
    }
  }

  @override
  Map<String, dynamic> readAll() => Map.of(_cache);

  @override
  T? read<T>(String key) => _cache[key] as T?;

  @override
  Future<void> write(String key, Object? value) async {
    _cache[key] = value;
    await _flush();
  }

  @override
  Future<void> writeAll(Map<String, dynamic> map) async {
    _cache = Map.of(map);
    await _flush();
  }

  Future<void> _flush() async {
    await _file?.writeAsString(jsonEncode(_cache));
  }
}
