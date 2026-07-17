// Configured Dio instance with:
//  - base URL + JSON defaults
//  - Authorization header injection from TokenStore
//  - transparent access-token refresh on 401 (single-flight), then retry
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'token_store.dart';

/// Explicit override, e.g. --dart-define=API_BASE_URL=http://192.168.1.20:4000/api/v1
const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

/// Backend base URL.
///  - A --dart-define override always wins (use this for a physical device:
///    pass your dev machine's LAN IP).
///  - Otherwise defaults are host-aware: the Android emulator reaches the host
///    machine's localhost via the special alias 10.0.2.2, not "localhost".
String get kApiBaseUrl {
  if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.242.242.125:4000/api/v1';
  }
  return 'http://localhost:4000/api/v1';
}

class DioClient {
  final TokenStore _tokens;
  late final Dio dio;

  // Single-flight refresh: concurrent 401s await one refresh call.
  Completer<bool>? _refreshing;

  DioClient(this._tokens) {
    dio = Dio(
      BaseOptions(
        baseUrl: kApiBaseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
        contentType: Headers.jsonContentType,
        // We handle non-2xx ourselves so the refresh flow can intercept 401.
        validateStatus: (s) => s != null && s < 500,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _tokens.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) async {
          // Retry once after a successful refresh when we get a 401.
          if (response.statusCode == 401 &&
              response.requestOptions.extra['__retried'] != true &&
              !_isAuthEndpoint(response.requestOptions.path)) {
            final refreshed = await _refreshOnce();
            if (refreshed) {
              try {
                final retried = await _retry(response.requestOptions);
                return handler.resolve(retried);
              } catch (_) {
                return handler.next(response);
              }
            }
          }
          handler.next(response);
        },
      ),
    );
  }

  bool _isAuthEndpoint(String path) =>
      path.contains('/auth/login') || path.contains('/auth/refresh');

  Future<bool> _refreshOnce() async {
    if (_refreshing != null) return _refreshing!.future;
    final completer = Completer<bool>();
    _refreshing = completer;
    try {
      final refresh = _tokens.refreshToken;
      if (refresh == null || refresh.isEmpty) {
        completer.complete(false);
        return false;
      }
      final res = await Dio(BaseOptions(baseUrl: kApiBaseUrl)).post(
        '/auth/refresh',
        data: {'refreshToken': refresh},
      );
      final data = res.data['data'] as Map<String, dynamic>;
      await _tokens.saveTokens(
        access: data['accessToken'] as String,
        refresh: data['refreshToken'] as String,
      );
      completer.complete(true);
      return true;
    } catch (_) {
      await _tokens.clear();
      completer.complete(false);
      return false;
    } finally {
      _refreshing = null;
    }
  }

  Future<Response> _retry(RequestOptions req) {
    final token = _tokens.accessToken;
    return dio.request(
      req.path,
      data: req.data,
      queryParameters: req.queryParameters,
      options: Options(
        method: req.method,
        headers: {...req.headers, 'Authorization': 'Bearer $token'},
        extra: {...req.extra, '__retried': true},
      ),
    );
  }
}
