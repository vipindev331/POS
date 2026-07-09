// INTEGRATION — requires backend on :4000. Auto-skips if unreachable.
// Verifies login (success + failure), session validation, and logout.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/network/dio_client.dart';
import 'package:pos_app/core/network/token_store.dart';
import 'package:pos_app/features/auth/data/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<bool> _up() async {
  try {
    final r = await Dio().getUri(Uri.parse(kApiBaseUrl.replaceFirst('/api/v1', '/health')));
    return r.statusCode == 200;
  } catch (_) {
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null; // allow real network from the test binding

  test('login success/failure, me, logout', () async {
    SharedPreferences.setMockInitialValues({});
    final tokens = await TokenStore.create();
    final repo = AuthRepository(DioClient(tokens), tokens);

    if (!await _up()) {
      markTestSkipped('backend not reachable on :4000');
      return;
    }

    // Wrong password rejected.
    await expectLater(repo.login('manager', 'wrong'), throwsA(isA<AuthException>()));
    expect(tokens.isLoggedIn, false);

    // Correct login stores tokens + user.
    final user = await repo.login('manager', 'manager123');
    expect(user.role, 'manager');
    expect(tokens.isLoggedIn, true);
    expect(repo.cachedUser?.username, 'manager');

    // Session validates against /me.
    final me = await repo.me();
    expect(me?.username, 'manager');

    // Logout clears the session.
    await repo.logout();
    expect(tokens.isLoggedIn, false);
  });
}
