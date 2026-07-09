import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/tables.dart';

part 'catalog_dao.g.dart';

@DriftAccessor(tables: [Products, Categories, Brands, Units])
class CatalogDao extends DatabaseAccessor<AppDatabase> with _$CatalogDaoMixin {
  CatalogDao(super.db);

  Future<List<Product>> allProducts() =>
      (select(products)..where((p) => p.deletedAt.isNull())..orderBy([(p) => OrderingTerm(expression: p.name)]))
          .get();

  Stream<List<Product>> watchProducts() =>
      (select(products)..where((p) => p.deletedAt.isNull())..orderBy([(p) => OrderingTerm(expression: p.name)]))
          .watch();

  /// Fast barcode lookup — the billing hot path.
  Future<Product?> byBarcode(String barcode) =>
      (select(products)..where((p) => p.barcode.equals(barcode) & p.deletedAt.isNull()))
          .getSingleOrNull();

  Future<Product?> byId(String id) =>
      (select(products)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<List<Product>> search(String term, {int limit = 25}) {
    final like = '%$term%';
    // Partial match on name, SKU, and barcode (LIKE). Exact barcode scanning
    // uses byBarcode() on the billing hot path; this is the manual search.
    return (select(products)
          ..where((p) =>
              p.deletedAt.isNull() &
              (p.name.like(like) | p.sku.like(like) | p.barcode.like(like)))
          ..limit(limit))
        .get();
  }

  Future<void> upsertProduct(ProductsCompanion c) =>
      into(products).insertOnConflictUpdate(c);

  /// Partial update of an existing product by id.
  Future<void> updateProduct(String id, ProductsCompanion c) =>
      (update(products)..where((t) => t.id.equals(id))).write(c);

  /// Local soft-delete (tombstone) so the row drops out of lists immediately.
  Future<void> softDeleteProduct(String id, int ts) =>
      (update(products)..where((t) => t.id.equals(id))).write(
        ProductsCompanion(deletedAt: Value(ts), updatedAt: Value(ts), dirty: const Value(true)),
      );

  Future<void> upsertAllProducts(List<ProductsCompanion> rows) async {
    await batch((b) => b.insertAllOnConflictUpdate(products, rows));
  }

  /// Apply a local stock delta (e.g. after an offline sale).
  Future<void> adjustStock(String productId, int delta, int ts) async {
    final p = await byId(productId);
    if (p == null) return;
    await (update(products)..where((t) => t.id.equals(productId)))
        .write(ProductsCompanion(stock: Value(p.stock + delta), updatedAt: Value(ts)));
  }

  Future<List<Product>> lowStock() => (select(products)
        ..where((p) => p.deletedAt.isNull() & p.stock.isSmallerOrEqual(p.reorderLevel) & p.stock.isBiggerThanValue(0)))
      .get();

  Future<void> upsertAllCategories(List<CategoriesCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(categories, rows));
  Future<void> upsertAllBrands(List<BrandsCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(brands, rows));
  Future<void> upsertAllUnits(List<UnitsCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(units, rows));
}
