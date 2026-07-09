// Authentication data layer: talks to the backend and persists tokens + the
// current user via TokenStore.
import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/token_store.dart';
import '../domain/auth_user.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthRepository {
  final DioClient _client;
  final TokenStore _tokens;

  AuthRepository(this._client, this._tokens);

  bool get hasSession => _tokens.isLoggedIn;

  AuthUser? get cachedUser {
    final json = _tokens.userJson;
    if (json == null || json.isEmpty) return null;
    try {
      return AuthUser.decode(json);
    } catch (_) {
      return null;
    }
  }

  Future<AuthUser> login(String username, String password) async {
    final res = await _client.dio.post(
      '/auth/login',
      data: {'username': username, 'password': password},
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    if (res.statusCode != 200) {
      final msg = res.data is Map ? (res.data['error']?['message'] ?? 'Login failed') : 'Login failed';
      throw AuthException(msg.toString());
    }
    final data = res.data['data'] as Map<String, dynamic>;
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    await _tokens.saveTokens(
      access: data['accessToken'] as String,
      refresh: data['refreshToken'] as String,
      userJson: user.encode(),
    );
    return user;
  }

  /// Confirm the session is still valid (and refresh the cached user).
  Future<AuthUser?> me() async {
    if (!hasSession) return null;
    try {
      final res = await _client.dio.get('/auth/me',
          options: Options(validateStatus: (s) => s != null && s < 500));
      if (res.statusCode == 200) {
        final user = AuthUser.fromJson(res.data['data'] as Map<String, dynamic>);
        await _tokens.saveTokens(
          access: _tokens.accessToken!,
          refresh: _tokens.refreshToken!,
          userJson: user.encode(),
        );
        return user;
      }
    } catch (_) {
      // Offline — fall back to the cached user so the app still opens.
      return cachedUser;
    }
    return cachedUser;
  }

  Future<void> logout() async {
    final refresh = _tokens.refreshToken;
    if (refresh != null) {
      try {
        await _client.dio.post('/auth/logout',
            data: {'refreshToken': refresh},
            options: Options(validateStatus: (_) => true));
      } catch (_) {/* best effort */}
    }
    await _tokens.clear();
  }
}
