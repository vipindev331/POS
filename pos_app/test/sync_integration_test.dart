// INTEGRATION TEST — requires the backend running on :4000 (npm run setup && npm start).
// Skipped automatically if the backend is unreachable, so normal `flutter test`
// stays green offline. Run explicitly with the backend up to verify sync E2E.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/network/dio_client.dart';
import 'package:pos_app/core/network/token_store.dart';
import 'package:pos_app/data/local/database.dart';
import 'package:pos_app/features/billing/data/sales_repository.dart';
import 'package:pos_app/features/billing/domain/cart.dart';
import 'package:pos_app/features/sync/data/sync_engine.dart';
import 'package:pos_app/features/sync/data/sync_remote_ds.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/always_online.dart';

Future<bool> _backendUp() async {
  try {
    // Bare Dio (no baseUrl) — the /health route lives at the server root.
    final res = await Dio().getUri(
      Uri.parse(kApiBaseUrl.replaceFirst('/api/v1', '/health')),
    );
    return res.statusCode == 200;
  } catch (_) {
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The test binding blocks real network calls (returns HTTP 400). Restore the
  // real HttpClient so this integration test can talk to the live backend.
  HttpOverrides.global = null;

  test('offline sale pushes and gets a server invoice number; pull loads catalog', () async {
    SharedPreferences.setMockInitialValues({});
    final tokens = await TokenStore.create();
    final client = DioClient(tokens);

    if (!await _backendUp()) {
      markTestSkipped('backend not reachable on :4000');
      return;
    }

    // Log in and store tokens (DioClient injects them on subsequent calls).
    final login = await client.dio.post('/auth/login', data: {
      'username': 'manager',
      'password': 'manager123',
    });
    await tokens.saveTokens(
      access: login.data['data']['accessToken'],
      refresh: login.data['data']['refreshToken'],
    );

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final sales = SalesRepository(db);
    final engine = SyncEngine(db, SyncRemoteDataSource(client), AlwaysOnline());

    // Create an offline sale (manual line, no product dependency).
    await sales.checkout(
      lines: const [CartLine(productId: null, name: 'Test Item', unitPrice: 10000, qty: 1, gstRate: 18)],
      payments: const [PaymentEntry(method: PayMethod.cash, amount: 11800)],
    );
    expect(await db.syncDao.pendingCount(), 1);

    await engine.syncNow();

    // Outbox drained; the bill now carries the server's invoice number.
    expect(await db.syncDao.pendingCount(), 0);
    final bills = await db.salesDao.recentBills();
    expect(bills.single.invoiceNo, isNotNull);
    expect(bills.single.syncState, 'synced');

    // Pull populated the local catalog from the seeded backend.
    final products = await db.catalogDao.allProducts();
    expect(products, isNotEmpty);
  });
}
