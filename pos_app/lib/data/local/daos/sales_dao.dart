import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/tables.dart';

part 'sales_dao.g.dart';

/// A bill together with its lines and payments — the unit the UI and printer use.
class FullBill {
  final Bill bill;
  final List<BillItem> items;
  final List<Payment> payments;
  const FullBill(this.bill, this.items, this.payments);
}

@DriftAccessor(tables: [Bills, BillItems, Payments, InventoryLedger, Products])
class SalesDao extends DatabaseAccessor<AppDatabase> with _$SalesDaoMixin {
  SalesDao(super.db);

  /// Persist a completed sale atomically: bill + items + payments, decrement
  /// stock, append inventory-ledger rows. Everything in one transaction so an
  /// interrupted checkout never leaves a half-written bill.
  Future<void> saveSale({
    required BillsCompanion bill,
    required List<BillItemsCompanion> itemRows,
    required List<PaymentsCompanion> paymentRows,
    required List<InventoryLedgerCompanion> ledgerRows,
    bool decrementStock = true,
  }) async {
    await transaction(() async {
      await into(bills).insertOnConflictUpdate(bill);
      await batch((b) {
        b.insertAll(billItems, itemRows, mode: InsertMode.insertOrReplace);
        b.insertAll(payments, paymentRows, mode: InsertMode.insertOrReplace);
        b.insertAll(inventoryLedger, ledgerRows, mode: InsertMode.insertOrReplace);
      });
      if (decrementStock) {
        for (final l in ledgerRows) {
          final pid = l.productId.value;
          final delta = l.change.value;
          final p = await (select(products)..where((t) => t.id.equals(pid))).getSingleOrNull();
          if (p != null) {
            await (update(products)..where((t) => t.id.equals(pid)))
                .write(ProductsCompanion(stock: Value(p.stock + delta)));
          }
        }
      }
    });
  }

  Future<List<Bill>> recentBills({int limit = 50}) =>
      (select(bills)
            ..where((b) => b.deletedAt.isNull())
            ..orderBy([(b) => OrderingTerm(expression: b.createdAt, mode: OrderingMode.desc)])
            ..limit(limit))
          .get();

  Future<FullBill?> fullBill(String id) async {
    final bill = await (select(bills)..where((b) => b.id.equals(id))).getSingleOrNull();
    if (bill == null) return null;
    final items = await (select(billItems)..where((i) => i.billId.equals(id))).get();
    final pays = await (select(payments)..where((p) => p.billId.equals(id))).get();
    return FullBill(bill, items, pays);
  }

  Future<void> markSynced(String id, String invoiceNo) =>
      (update(bills)..where((b) => b.id.equals(id)))
          .write(BillsCompanion(syncState: const Value('synced'), invoiceNo: Value(invoiceNo)));

  Future<int> pendingSyncBills() async {
    final c = countAll();
    final row = await (selectOnly(bills)
          ..addColumns([c])
          ..where(bills.syncState.equals('pending')))
        .getSingle();
    return row.read(c) ?? 0;
  }

  Future<List<Bill>> heldBills() =>
      (select(bills)
            ..where((b) => b.status.equals('held') & b.deletedAt.isNull())
            ..orderBy([(b) => OrderingTerm(expression: b.createdAt, mode: OrderingMode.desc)]))
          .get();

  /// Remove a bill and its children (used when resuming a held bill into the cart).
  Future<void> deleteBillCascade(String id) async {
    await transaction(() async {
      await (delete(billItems)..where((i) => i.billId.equals(id))).go();
      await (delete(payments)..where((p) => p.billId.equals(id))).go();
      await (delete(bills)..where((b) => b.id.equals(id))).go();
    });
  }
}
