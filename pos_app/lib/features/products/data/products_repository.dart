// Offline-first product repository. Reads always hit the local Drift cache
// (sub-millisecond, works offline); refreshFromRemote() pulls the catalog when
// online. The full delta-sync engine (Part 6) supersedes the naive refresh.
import 'package:drift/drift.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../data/local/database.dart';
import 'products_remote_ds.dart';

class ProductsRepository {
  final AppDatabase _db;
  final ProductsRemoteDataSource _remote;
  final ConnectivityService _connectivity;

  ProductsRepository(this._db, this._remote, this._connectivity);

  CatalogDao get _dao => _db.catalogDao;

  Future<Product?> byBarcode(String barcode) => _dao.byBarcode(barcode);
  Future<Product?> byId(String id) => _dao.byId(id);
  Future<List<Product>> search(String term) => _dao.search(term);
  Future<List<Product>> all() => _dao.allProducts();
  Stream<List<Product>> watch() => _dao.watchProducts();

  Future<int> localCount() async => (await _dao.allProducts()).length;

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
