// Offline-first product repository. Reads always hit the local Drift cache
// (sub-millisecond, works offline); refreshFromRemote() pulls the catalog when
// online. The full delta-sync engine (Part 6) supersedes the naive refresh.
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../data/local/database.dart';
import 'products_remote_ds.dart';

class ProductsRepository {
  final AppDatabase _db;
  final ProductsRemoteDataSource _remote;
  final ConnectivityService _connectivity;
  static const _uuid = Uuid();

  ProductsRepository(this._db, this._remote, this._connectivity);

  CatalogDao get _dao => _db.catalogDao;

  Future<Product?> byBarcode(String barcode) => _dao.byBarcode(barcode);
  Future<Product?> byId(String id) => _dao.byId(id);
  Future<List<Product>> search(String term) => _dao.search(term);
  Future<List<Product>> all() => _dao.allProducts();
  Stream<List<Product>> watch() => _dao.watchProducts();

  Future<int> localCount() async => (await _dao.allProducts()).length;

  /// Add a product offline-first: write to the local cache (marked dirty) and
  /// enqueue a 'product:upsert' outbox op for the sync engine. Money values are
  /// in paise; `stock` is the opening stock. Returns the new local id.
  Future<String> addProduct({
    required String name,
    String? sku,
    String? barcode,
    String? hsn,
    int gstRate = 0,
    int purchasePrice = 0,
    int sellingPrice = 0,
    int mrp = 0,
    int stock = 0,
    int reorderLevel = 0,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _dao.upsertProduct(ProductsCompanion.insert(
      id: id,
      name: name,
      sku: Value(sku),
      barcode: Value(barcode),
      hsn: Value(hsn),
      gstRate: Value(gstRate),
      purchasePrice: Value(purchasePrice),
      sellingPrice: Value(sellingPrice),
      mrp: Value(mrp),
      stock: Value(stock),
      reorderLevel: Value(reorderLevel),
      updatedAt: Value(now),
      dirty: const Value(true),
    ));

    await _enqueueUpsert(
      id: id,
      name: name,
      sku: sku,
      barcode: barcode,
      hsn: hsn,
      gstRate: gstRate,
      purchasePrice: purchasePrice,
      sellingPrice: sellingPrice,
      mrp: mrp,
      stock: stock,
      reorderLevel: reorderLevel,
      now: now,
    );
    return id;
  }

  /// Edit an existing product (manager action). Updates the local cache and
  /// enqueues a 'product:upsert' op carrying the full new state.
  Future<void> updateProduct(
    String id, {
    required String name,
    String? sku,
    String? barcode,
    String? hsn,
    int gstRate = 0,
    int purchasePrice = 0,
    int sellingPrice = 0,
    int mrp = 0,
    int stock = 0,
    int reorderLevel = 0,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _dao.updateProduct(
      id,
      ProductsCompanion(
        name: Value(name),
        sku: Value(sku),
        barcode: Value(barcode),
        hsn: Value(hsn),
        gstRate: Value(gstRate),
        purchasePrice: Value(purchasePrice),
        sellingPrice: Value(sellingPrice),
        mrp: Value(mrp),
        stock: Value(stock),
        reorderLevel: Value(reorderLevel),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );

    await _enqueueUpsert(
      id: id,
      name: name,
      sku: sku,
      barcode: barcode,
      hsn: hsn,
      gstRate: gstRate,
      purchasePrice: purchasePrice,
      sellingPrice: sellingPrice,
      mrp: mrp,
      stock: stock,
      reorderLevel: reorderLevel,
      now: now,
    );
  }

  /// Soft-delete a product (manager action). Tombstones locally and enqueues a
  /// 'product:delete' op for the server.
  Future<void> deleteProduct(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _dao.softDeleteProduct(id, now);
    await _db.syncDao.enqueue(OutboxOpsCompanion.insert(
      opId: 'del-$id',
      entity: 'product',
      type: 'delete',
      payload: jsonEncode({'id': id}),
      createdAt: now,
      nextAttemptAt: Value(now),
    ));
  }

  Future<void> _enqueueUpsert({
    required String id,
    required String name,
    String? sku,
    String? barcode,
    String? hsn,
    required int gstRate,
    required int purchasePrice,
    required int sellingPrice,
    required int mrp,
    required int stock,
    required int reorderLevel,
    required int now,
  }) {
    return _db.syncDao.enqueue(OutboxOpsCompanion.insert(
      // Per-edit opId keeps each upsert idempotent yet distinct in the outbox.
      opId: 'up-$id-$now',
      entity: 'product',
      type: 'upsert',
      payload: jsonEncode({
        'id': id,
        'name': name,
        'sku': sku,
        'barcode': barcode,
        'hsn': hsn,
        'gstRate': gstRate,
        'purchasePrice': purchasePrice,
        'sellingPrice': sellingPrice,
        'mrp': mrp,
        'openingStock': stock,
        'reorderLevel': reorderLevel,
      }),
      createdAt: now,
      nextAttemptAt: Value(now),
    ));
  }

  /// Pull the catalog from the backend into the local cache. Returns the number
  /// of products written, or -1 if offline / the request failed.
  Future<int> refreshFromRemote() async {
    if (!_connectivity.isOnline) return -1;
    try {
      final rows = await _remote.fetchAll();
      final companions = rows.map(_toCompanion).toList();
      await _dao.upsertAllProducts(companions);
      return companions.length;
    } catch (_) {
      return -1;
    }
  }

  ProductsCompanion _toCompanion(Map<String, dynamic> j) {
    return ProductsCompanion(
      id: Value(j['id'] as String),
      sku: Value(j['sku'] as String?),
      barcode: Value(j['barcode'] as String?),
      name: Value(j['name'] as String),
      categoryId: Value(j['categoryId'] as String?),
      brandId: Value(j['brandId'] as String?),
      unitId: Value(j['unitId'] as String?),
      hsn: Value(j['hsn'] as String?),
      gstRate: Value((j['gstRate'] ?? 0) as int),
      purchasePrice: Value((j['purchasePrice'] ?? 0) as int),
      sellingPrice: Value((j['sellingPrice'] ?? 0) as int),
      mrp: Value((j['mrp'] ?? 0) as int),
      stock: Value((j['stock'] ?? 0) as int),
      reorderLevel: Value((j['reorderLevel'] ?? 0) as int),
      batchNo: Value(j['batchNo'] as String?),
      expiryAt: Value(j['expiryAt'] as int?),
      imageUrl: Value(j['imageUrl'] as String?),
      active: Value((j['active'] ?? true) as bool),
      updatedAt: Value((j['updatedAt'] ?? 0) as int),
    );
  }
}
