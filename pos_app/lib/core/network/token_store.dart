// Persists JWT access/refresh tokens. shared_preferences works on all 6
// platforms (localStorage on web, native prefs elsewhere).
import 'package:shared_preferences/shared_preferences.dart';

class TokenStore {
  static const _kAccess = 'auth_access_token';
  static const _kRefresh = 'auth_refresh_token';
  static const _kUser = 'auth_user_json';

  final SharedPreferences _prefs;
  TokenStore(this._prefs);

  static Future<TokenStore> create() async =>
      TokenStore(await SharedPreferences.getInstance());

  String? get accessToken => _prefs.getString(_kAccess);
  String? get refreshToken => _prefs.getString(_kRefresh);
  String? get userJson => _prefs.getString(_kUser);
  bool get isLoggedIn => (accessToken?.isNotEmpty ?? false);

  Future<void> saveTokens({
    required String access,
    required String refresh,
    String? userJson,
  }) async {
    await _prefs.setString(_kAccess, access);
    await _prefs.setString(_kRefresh, refresh);
    if (userJson != null) await _prefs.setString(_kUser, userJson);
  }

  Future<void> updateAccess(String access) => _prefs.setString(_kAccess, access);

  Future<void> clear() async {
    await _prefs.remove(_kAccess);
    await _prefs.remove(_kRefresh);
    await _prefs.remove(_kUser);
  }
}
