// Background sync engine (Part 6).
//
//  PUSH  — drains the write-ahead outbox in order. Each op is idempotent, so a
//          retry is always safe. On success the op is removed and (for bills)
//          the server's authoritative invoice number is written locally. On
//          failure the op is rescheduled with capped exponential backoff.
//  PULL  — for each entity, requests rows changed since a per-entity cursor and
//          upserts them (last-write-wins). The cursor advances to the server's
//          clock so nothing is missed or re-fetched.
//
// It never blocks the UI: work runs on timers / connectivity events and only
// touches the local DB and network. A ValueNotifier exposes status for badges.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../data/local/database.dart';
import 'sync_remote_ds.dart';

class SyncStatus {
  final bool syncing;
  final int pending;
  final int? lastSyncedAt;
  final String? lastError;
  const SyncStatus({this.syncing = false, this.pending = 0, this.lastSyncedAt, this.lastError});

  SyncStatus copyWith({bool? syncing, int? pending, int? lastSyncedAt, String? lastError}) =>
      SyncStatus(
        syncing: syncing ?? this.syncing,
        pending: pending ?? this.pending,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        lastError: lastError,
      );
}

class SyncEngine {
  final AppDatabase _db;
  final SyncRemoteDataSource _remote;
  final ConnectivityService _connectivity;

  static const _pullEntities = ['products', 'customers', 'suppliers', 'categories', 'brands', 'units'];
  static const _maxBackoffMs = 60000;

  Timer? _timer;
  bool _running = false;
  StreamSubscription<bool>? _connSub;

  final status = SyncStatusNotifier();

  SyncEngine(this._db, this._remote, this._connectivity);

  /// Begin periodic sync + sync-on-reconnect. Safe to call once at startup.
  void start({Duration interval = const Duration(seconds: 30)}) {
    _timer ??= Timer.periodic(interval, (_) => syncNow());
    _connSub ??= _connectivity.onStatusChange.listen((online) {
      if (online) syncNow();
    });
    syncNow();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _connSub?.cancel();
    _connSub = null;
  }

  /// Run a push+pull cycle. Re-entrancy guarded so timer/reconnect can't overlap.
  Future<void> syncNow() async {
    if (_running || !_connectivity.isOnline) {
      await _refreshPending();
      return;
    }
    _running = true;
    status.set(status.value.copyWith(syncing: true, lastError: null));
    try {
      await _push();
      await _pull();
      status.set(status.value.copyWith(
        syncing: false,
        lastSyncedAt: DateTime.now().millisecondsSinceEpoch,
      ));
    } catch (e) {
      status.set(status.value.copyWith(syncing: false, lastError: e.toString()));
    } finally {
      _running = false;
      await _refreshPending();
    }
  }

  Future<void> _refreshPending() async {
    final pending = await _db.syncDao.pendingCount();
    status.set(status.value.copyWith(pending: pending));
  }

  // ── PUSH ────────────────────────────────────────────────────────────────
  Future<void> _push() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final ops = await _db.syncDao.due(now);
    if (ops.isEmpty) return;

    final payloads = ops
        .map((o) => {
              'opId': o.opId,
              'entity': o.entity,
              'type': o.type,
              'payload': jsonDecode(o.payload),
            })
        .toList();

    final results = await _remote.push(payloads);
    final byOpId = {for (final r in results) r['opId'] as String?: r};

    for (final op in ops) {
      final result = byOpId[op.opId];
      if (result != null && result['status'] == 'ok') {
        // Apply server authority (invoice number) for bills, then drop the op.
        if (op.entity == 'bill') {
          final data = result['data'] as Map<String, dynamic>?;
          final payload = jsonDecode(op.payload) as Map<String, dynamic>;
          final billId = payload['billId'] as String?;
          final invoiceNo = data?['invoiceNo'] as String?;
          if (billId != null && invoiceNo != null) {
            await _db.salesDao.markSynced(billId, invoiceNo);
          }
        }
        await _db.syncDao.remove(op.seq);
      } else {
        final attempts = op.attempts + 1;
        final backoff = min(_maxBackoffMs, (1000 * pow(2, attempts)).toInt());
        final jitter = Random().nextInt(500);
        await _db.syncDao.reschedule(
          op.seq,
          attempts: attempts,
          nextAttemptAt: now + backoff + jitter,
          error: result?['error']?['message']?.toString() ?? 'push failed',
        );
      }
    }
  }

  // ── PULL ────────────────────────────────────────────────────────────────
  Future<void> _pull() async {
    for (final entity in _pullEntities) {
      final since = await _db.syncDao.cursor(entity);
      final res = await _remote.pull(since: since, entities: [entity]);
      final rows = (res.changes[entity] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      if (rows.isNotEmpty) await _applyRows(entity, rows);
      await _db.syncDao.setCursor(entity, res.serverTime);
    }
  }

  Future<void> _applyRows(String entity, List<Map<String, dynamic>> rows) async {
    switch (entity) {
      case 'products':
        await _db.catalogDao.upsertAllProducts(rows.map(_productRow).toList());
      case 'customers':
        await _db.partiesDao.upsertAllCustomers(rows.map(_customerRow).toList());
      case 'suppliers':
        await _db.partiesDao.upsertAllSuppliers(rows.map(_supplierRow).toList());
      case 'categories':
        await _db.catalogDao.upsertAllCategories(rows.map(_categoryRow).toList());
      case 'brands':
        await _db.catalogDao.upsertAllBrands(rows.map(_brandRow).toList());
      case 'units':
        await _db.catalogDao.upsertAllUnits(rows.map(_unitRow).toList());
    }
  }

  // Backend /sync/pull returns raw snake_case rows. Map them to companions.
  int _i(Object? v) => (v as num?)?.toInt() ?? 0;
  bool _b(Object? v) => (v is bool) ? v : ((v as num?)?.toInt() ?? 0) != 0;

  ProductsCompanion _productRow(Map<String, dynamic> r) => ProductsCompanion(
        id: Value(r['id'] as String),
        sku: Value(r['sku'] as String?),
        barcode: Value(r['barcode'] as String?),
        name: Value(r['name'] as String),
        categoryId: Value(r['category_id'] as String?),
        brandId: Value(r['brand_id'] as String?),
        unitId: Value(r['unit_id'] as String?),
        hsn: Value(r['hsn'] as String?),
        gstRate: Value(_i(r['gst_rate'])),
        purchasePrice: Value(_i(r['purchase_price'])),
        sellingPrice: Value(_i(r['selling_price'])),
        mrp: Value(_i(r['mrp'])),
        stock: Value(_i(r['stock'])),
        reorderLevel: Value(_i(r['reorder_level'])),
        batchNo: Value(r['batch_no'] as String?),
        expiryAt: Value((r['expiry_at'] as num?)?.toInt()),
        imageUrl: Value(r['image_url'] as String?),
        active: Value(_b(r['active'])),
        updatedAt: Value(_i(r['updated_at'])),
        deletedAt: Value((r['deleted_at'] as num?)?.toInt()),
      );

  CustomersCompanion _customerRow(Map<String, dynamic> r) => CustomersCompanion(
        id: Value(r['id'] as String),
        name: Value(r['name'] as String),
        phone: Value(r['phone'] as String?),
        email: Value(r['email'] as String?),
        groupName: Value((r['group_name'] as String?) ?? 'walk-in'),
        loyaltyPoints: Value(_i(r['loyalty_points'])),
        creditLimit: Value(_i(r['credit_limit'])),
        balance: Value(_i(r['balance'])),
        gstin: Value(r['gstin'] as String?),
        stateCode: Value(r['state_code'] as String?),
        updatedAt: Value(_i(r['updated_at'])),
        deletedAt: Value((r['deleted_at'] as num?)?.toInt()),
      );

  SuppliersCompanion _supplierRow(Map<String, dynamic> r) => SuppliersCompanion(
        id: Value(r['id'] as String),
        name: Value(r['name'] as String),
        phone: Value(r['phone'] as String?),
        email: Value(r['email'] as String?),
        gstin: Value(r['gstin'] as String?),
        balance: Value(_i(r['balance'])),
        updatedAt: Value(_i(r['updated_at'])),
        deletedAt: Value((r['deleted_at'] as num?)?.toInt()),
      );

  CategoriesCompanion _categoryRow(Map<String, dynamic> r) => CategoriesCompanion(
        id: Value(r['id'] as String),
        name: Value(r['name'] as String),
        parentId: Value(r['parent_id'] as String?),
        updatedAt: Value(_i(r['updated_at'])),
        deletedAt: Value((r['deleted_at'] as num?)?.toInt()),
      );

  BrandsCompanion _brandRow(Map<String, dynamic> r) => BrandsCompanion(
        id: Value(r['id'] as String),
        name: Value(r['name'] as String),
        updatedAt: Value(_i(r['updated_at'])),
        deletedAt: Value((r['deleted_at'] as num?)?.toInt()),
      );

  UnitsCompanion _unitRow(Map<String, dynamic> r) => UnitsCompanion(
        id: Value(r['id'] as String),
        name: Value(r['name'] as String),
        shortName: Value((r['short_name'] as String?) ?? ''),
        updatedAt: Value(_i(r['updated_at'])),
        deletedAt: Value((r['deleted_at'] as num?)?.toInt()),
      );
}

// Lightweight observable so widgets can show a sync badge without bloc wiring.
class SyncStatusNotifier {
  final _controller = StreamController<SyncStatus>.broadcast();
  SyncStatus value = const SyncStatus();
  Stream<SyncStatus> get stream => _controller.stream;
  void set(SyncStatus s) {
    value = s;
    _controller.add(s);
  }
}
