// Persists a checkout offline-first: computes with the shared tax engine,
// writes the bill atomically to Drift (source of truth for the device), and
// enqueues an idempotent outbox op for the sync engine (Part 6) to push.
// If online, it also attempts an immediate push so the bill gets its
// authoritative invoice number promptly — but success does not depend on it.
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/money/tax_engine.dart';
import '../../../data/local/database.dart';
import '../domain/cart.dart';

class CheckoutResult {
  final String billId;
  final String localNo;
  final BillResult totals;
  const CheckoutResult(this.billId, this.localNo, this.totals);
}

class SalesRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  SalesRepository(this._db);

  /// Persist a sale locally and enqueue it for sync. `status` is 'completed'
  /// or 'held'. Held bills don't move stock.
  Future<CheckoutResult> checkout({
    required List<CartLine> lines,
    required List<PaymentEntry> payments,
    String? customerId,
    String? cashierId,
    int billDiscount = 0,
    bool interState = false,
    String status = 'completed',
    String? note,
  }) async {
    final totals = computeBill(
      lines.map((l) => l.toLineInput()).toList(),
      billDiscount: billDiscount,
      interState: interState,
    );

    final now = DateTime.now().millisecondsSinceEpoch;
    final billId = _uuid.v4();
    final idempotencyKey = _uuid.v4();
    final localNo = 'L-${now.toRadixString(36).toUpperCase()}';
    final paid = payments.fold<int>(0, (s, p) => s + p.amount);

    final billCompanion = BillsCompanion.insert(
      id: billId,
      localNo: Value(localNo),
      customerId: Value(customerId),
      cashierId: Value(cashierId),
      status: Value(status),
      subTotal: totals.subTotal,
      itemDiscount: Value(totals.itemDiscount),
      billDiscount: Value(totals.billDiscount),
      cgst: Value(totals.cgst),
      sgst: Value(totals.sgst),
      igst: Value(totals.igst),
      totalTax: Value(totals.totalTax),
      roundOff: Value(totals.roundOff),
      grandTotal: totals.grandTotal,
      paid: Value(paid),
      interState: Value(interState),
      idempotencyKey: Value(idempotencyKey),
      note: Value(note),
      createdAt: now,
      syncState: const Value('pending'),
    );

    final itemRows = <BillItemsCompanion>[];
    final ledgerRows = <InventoryLedgerCompanion>[];
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      final r = totals.lines[i];
      itemRows.add(BillItemsCompanion.insert(
        id: _uuid.v4(),
        billId: billId,
        productId: Value(l.productId),
        name: l.name,
        hsn: Value(l.hsn),
        qty: l.qty,
        unitPrice: l.unitPrice,
        lineDiscount: Value(l.lineDiscount),
        gstRate: Value(l.gstRate),
        taxable: r.taxable,
        cgst: Value(r.cgst),
        sgst: Value(r.sgst),
        igst: Value(r.igst),
        lineTotal: r.lineTotal,
      ));
      if (status == 'completed' && l.productId != null) {
        ledgerRows.add(InventoryLedgerCompanion.insert(
          id: _uuid.v4(),
          productId: l.productId!,
          change: -l.qty,
          reason: 'sale',
          refType: const Value('bill'),
          refId: Value(billId),
          balanceAfter: 0, // recomputed by adjustStock; informational locally
          createdAt: now,
        ));
      }
    }

    final paymentRows = payments
        .map((p) => PaymentsCompanion.insert(
              id: _uuid.v4(),
              billId: billId,
              method: p.methodName,
              amount: p.amount,
              reference: Value(p.reference),
              createdAt: now,
            ))
        .toList();

    await _db.salesDao.saveSale(
      bill: billCompanion,
      itemRows: itemRows,
      paymentRows: paymentRows,
      ledgerRows: ledgerRows,
      decrementStock: status == 'completed',
    );

    // Held bills stay local until resumed & completed; only completed sales
    // are enqueued for the server.
    if (status != 'completed') {
      return CheckoutResult(billId, localNo, totals);
    }

    // Enqueue the idempotent checkout op for the sync engine.
    await _db.syncDao.enqueue(OutboxOpsCompanion.insert(
      opId: idempotencyKey,
      entity: 'bill',
      type: 'checkout',
      payload: jsonEncode({
        'billId': billId,
        'idempotencyKey': idempotencyKey,
        'customerId': customerId,
        'items': [
          for (final l in lines)
            {
              'productId': l.productId,
              'name': l.name,
              'hsn': l.hsn,
              'qty': l.qty,
              'unitPrice': l.unitPrice,
              'lineDiscount': l.lineDiscount,
              'gstRate': l.gstRate,
            }
        ],
        'billDiscount': billDiscount,
        'payments': [
          for (final p in payments)
            {'method': p.methodName, 'amount': p.amount, 'reference': p.reference}
        ],
        'interState': interState,
        'status': status,
        'note': note,
      }),
      createdAt: now,
      nextAttemptAt: Value(now),
    ));

    return CheckoutResult(billId, localNo, totals);
  }

  Future<List<Bill>> recentBills() => _db.salesDao.recentBills();
  Future<FullBill?> fullBill(String id) => _db.salesDao.fullBill(id);
  Future<int> pendingSyncCount() => _db.syncDao.pendingCount();
  Future<List<Bill>> heldBills() => _db.salesDao.heldBills();
  Future<void> deleteHeld(String id) => _db.salesDao.deleteBillCascade(id);
}
