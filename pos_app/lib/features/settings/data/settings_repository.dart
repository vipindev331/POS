// Company details are shared by every user of the store, so they live on the
// backend (`/settings/company`, manager-writable). We mirror the latest copy
// into the local ConfigStore so the Settings screen and receipts work offline.
//
// Printer setup is intentionally NOT synced here: each till has its own printer,
// so that stays device-local in ConfigStore.
import 'package:dio/dio.dart';

import '../../../core/config/config_store.dart';
import '../../../core/network/dio_client.dart';

class SettingsRepository {
  final DioClient _client;
  final ConfigStore _config;
  SettingsRepository(this._client, this._config);

  /// Pull company details from the backend and cache them locally. Returns the
  /// map on success, or null if offline/unavailable (the local cache is left
  /// untouched so we keep showing the last known values).
  Future<Map<String, dynamic>?> pullCompany() async {
    try {
      final res = await _client.dio.get(
        '/settings/company',
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      final data = res.statusCode == 200 ? res.data['data'] : null;
      if (data is Map) {
        final company = data.cast<String, dynamic>();
        await _config.write('company', company);
        return company;
      }
    } catch (_) {
      // Offline or server error — keep the cached copy.
    }
    return null;
  }

  /// Save company details (manager action). Writes the local cache first so the
  /// value is never lost, then pushes to the backend so staff on other devices
  /// receive it. Returns true if the server accepted it, false if it was only
  /// saved locally (offline / server unreachable).
  Future<bool> saveCompany(Map<String, dynamic> company) async {
    await _config.write('company', company);
    try {
      final res = await _client.dio.put(
        '/settings/company',
        data: {'value': company},
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
