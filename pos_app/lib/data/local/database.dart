// The Drift database. `driftDatabase` (from drift_flutter) selects the right
// executor per platform: native SQLite (sqlite3_flutter_libs) on desktop/mobile,
// and a WASM/IndexedDB-backed database on web (assets in web/: sqlite3.wasm,
// drift_worker.js). Business logic is identical across all six platforms.
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/catalog_dao.dart';
import 'daos/parties_dao.dart';
import 'daos/sales_dao.dart';
import 'daos/sync_dao.dart';
import 'tables/tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Products, Customers, Suppliers, Categories, Brands, Units,
    Bills, BillItems, Payments, InventoryLedger, OutboxOps, SyncMeta,
  ],
  daos: [CatalogDao, PartiesDao, SalesDao, SyncDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _open() => driftDatabase(name: 'pos_db');
}
