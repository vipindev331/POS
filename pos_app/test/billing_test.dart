// Verifies offline-first checkout: SalesRepository persists the sale atomically,
// decrements stock, and enqueues an idempotent outbox op. Also exercises the
// BillingCubit cart operations and live totals.
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/network/connectivity_service.dart';
import 'package:pos_app/core/network/dio_client.dart';
import 'package:pos_app/core/network/token_store.dart';
import 'package:pos_app/data/local/database.dart';
import 'package:pos_app/features/billing/data/sales_repository.dart';
import 'package:pos_app/features/billing/domain/cart.dart';
import 'package:pos_app/features/billing/presentation/billing_cubit.dart';
import 'package:pos_app/features/products/data/products_remote_ds.dart';
import 'package:pos_app/features/products/data/products_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SalesRepository sales;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    sales = SalesRepository(db);
    await db.catalogDao.upsertProduct(ProductsCompanion.insert(
      id: 'p1',
      name: 'Tata Salt 1kg',
      barcode: const Value('8901030510014'),
      sellingPrice: const Value(2800),
      gstRate: const Value(5),
      stock: const Value(120),
    ));
  });

  tearDown(() => db.close());

  test('checkout persists bill, decrements stock, enqueues outbox op', () async {
    final result = await sales.checkout(
      lines: const [
        CartLine(productId: 'p1', name: 'Tata Salt 1kg', unitPrice: 2800, qty: 3, gstRate: 5),
      ],
      payments: const [PaymentEntry(method: PayMethod.cash, amount: 8800)],
    );

    // Totals from the shared tax engine: 8400 taxable + 5% (420) -> 8820 -> 8800.
    expect(result.totals.grandTotal, 8800);
    expect(result.totals.totalTax, 420);
    expect(result.totals.roundOff, -20);

    // Bill + children persisted.
    final full = await sales.fullBill(result.billId);
    expect(full, isNotNull);
    expect(full!.items.single.qty, 3);
    expect(full.payments.single.amount, 8800);

    // Stock decremented exactly once.
    final product = await db.catalogDao.byId('p1');
    expect(product!.stock, 117);

    // Outbox has the idempotent checkout op with a matching payload.
    expect(await db.syncDao.pendingCount(), 1);
    final due = await db.syncDao.due(DateTime.now().millisecondsSinceEpoch + 1000);
    final payload = jsonDecode(due.single.payload) as Map<String, dynamic>;
    expect(due.single.type, 'checkout');
    expect(payload['idempotencyKey'], due.single.opId);
    expect((payload['items'] as List).single['qty'], 3);
  });

  test('held bill does not decrement stock nor enqueue', () async {
    await sales.checkout(
      lines: const [
        CartLine(productId: 'p1', name: 'Tata Salt 1kg', unitPrice: 2800, qty: 2, gstRate: 5),
      ],
      payments: const [],
      status: 'held',
    );
    final product = await db.catalogDao.byId('p1');
    expect(product!.stock, 120); // unchanged
    expect(await db.syncDao.pendingCount(), 0);
    expect((await sales.heldBills()).length, 1);
  });

  test('BillingCubit cart ops and totals', () async {
    final products = ProductsRepository(
      db,
      ProductsRemoteDataSource(DioClient(await TokenStore.create())),
      ConnectivityService(),
    );
    final cubit = BillingCubit(products, sales);

    final p = (await db.catalogDao.byId('p1'))!;
    cubit.addProduct(p);
    cubit.addProduct(p); // same product -> qty 2
    expect(cubit.state.lines.single.qty, 2);
    expect(cubit.state.totals.subTotal, 5600);

    cubit.incQty(0); // qty 3
    expect(cubit.state.itemCount, 3);
    expect(cubit.state.totals.grandTotal, 8800);

    cubit.setBillDiscount(800); // ₹8 off subtotal
    expect(cubit.state.totals.billDiscount, 800);

    cubit.removeLine(0);
    expect(cubit.state.isEmpty, true);
  });
}
