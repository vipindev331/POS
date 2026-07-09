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

  /// Manager-only: create a staff (or manager) account. Backend enforces the
  /// role check; a non-manager caller gets a 403 surfaced as an AuthException.
  Future<AuthUser> createUser({
    required String username,
    required String password,
    String fullName = '',
    String role = 'staff',
    List<String> permissions = const [],
  }) async {
    final res = await _client.dio.post(
      '/auth/users',
      data: {
        'username': username,
        'password': password,
        'fullName': fullName,
        'role': role,
        'permissions': permissions,
      },
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    if (res.statusCode != 201 && res.statusCode != 200) {
      final msg = res.data is Map
          ? (res.data['error']?['message'] ?? 'Could not create user')
          : 'Could not create user';
      throw AuthException(msg.toString());
    }
    return AuthUser.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  /// Manager-only: list all (non-deleted) accounts.
  Future<List<AuthUser>> listUsers() async {
    final res = await _client.dio.get(
      '/auth/users',
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    if (res.statusCode != 200) {
      throw AuthException(_errorMessage(res, 'Could not load users'));
    }
    return (res.data['data'] as List)
        .map((e) => AuthUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Manager-only: edit an account's full name, role, permissions, or active flag.
  Future<AuthUser> updateUser(
    String id, {
    String? fullName,
    String? role,
    List<String>? permissions,
    bool? active,
  }) async {
    final body = <String, dynamic>{
      'fullName': ?fullName,
      'role': ?role,
      'permissions': ?permissions,
      'active': ?active,
    };
    final res = await _client.dio.patch(
      '/auth/users/$id',
      data: body,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    if (res.statusCode != 200) {
      throw AuthException(_errorMessage(res, 'Could not update user'));
    }
    return AuthUser.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  /// Manager-only: set a new password for an account.
  Future<void> resetPassword(String id, String newPassword) async {
    final res = await _client.dio.post(
      '/auth/users/$id/reset-password',
      data: {'password': newPassword},
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    if (res.statusCode != 200) {
      throw AuthException(_errorMessage(res, 'Could not reset password'));
    }
  }

  /// Manager-only: soft-delete an account.
  Future<void> deleteUser(String id) async {
    final res = await _client.dio.delete(
      '/auth/users/$id',
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    if (res.statusCode != 200) {
      throw AuthException(_errorMessage(res, 'Could not delete user'));
    }
  }

  String _errorMessage(Response res, String fallback) => res.data is Map
      ? (res.data['error']?['message'] ?? fallback).toString()
      : fallback;

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
