// Exercises the Drift schema + DAOs against an in-memory database.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/data/local/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('product upsert + barcode lookup', () async {
    await db.catalogDao.upsertProduct(ProductsCompanion.insert(
      id: 'p1',
      name: 'Tata Salt 1kg',
      barcode: const Value('8901030510014'),
      sellingPrice: const Value(2800),
      gstRate: const Value(5),
      stock: const Value(120),
    ));
    final found = await db.catalogDao.byBarcode('8901030510014');
    expect(found, isNotNull);
    expect(found!.name, 'Tata Salt 1kg');
    expect(found.stock, 120);
  });

  test('saveSale is atomic and decrements stock exactly once', () async {
    await db.catalogDao.upsertProduct(ProductsCompanion.insert(
      id: 'p1', name: 'Tata Salt 1kg', sellingPrice: const Value(2800),
      gstRate: const Value(5), stock: const Value(120),
    ));

    await db.salesDao.saveSale(
      bill: BillsCompanion.insert(
        id: 'b1', subTotal: 8400, grandTotal: 8800, createdAt: 1000,
        totalTax: const Value(420), paid: const Value(8800),
      ),
      itemRows: [
        BillItemsCompanion.insert(
          id: 'i1', billId: 'b1', productId: const Value('p1'),
          name: 'Tata Salt 1kg', qty: 3, unitPrice: 2800, taxable: 8400, lineTotal: 8820,
        ),
      ],
      paymentRows: [
        PaymentsCompanion.insert(id: 'pay1', billId: 'b1', method: 'cash', amount: 8800, createdAt: 1000),
      ],
      ledgerRows: [
        InventoryLedgerCompanion.insert(
          id: 'l1', productId: 'p1', change: -3, reason: 'sale', balanceAfter: 117, createdAt: 1000),
      ],
    );

    final product = await db.catalogDao.byId('p1');
    expect(product!.stock, 117); // decremented once

    final full = await db.salesDao.fullBill('b1');
    expect(full, isNotNull);
    expect(full!.items.length, 1);
    expect(full.payments.first.amount, 8800);
    expect(full.bill.grandTotal, 8800);
  });

  test('outbox enqueue + due + cursor', () async {
    await db.syncDao.enqueue(OutboxOpsCompanion.insert(
      opId: 'op1', entity: 'bill', type: 'checkout', payload: '{}', createdAt: 0,
      nextAttemptAt: const Value(0),
    ));
    expect(await db.syncDao.pendingCount(), 1);
    final due = await db.syncDao.due(1000);
    expect(due.length, 1);
    expect(due.first.entity, 'bill');

    await db.syncDao.setCursor('products', 12345);
    expect(await db.syncDao.cursor('products'), 12345);
  });
}
