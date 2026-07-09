// Drift table definitions — the client's local mirror of the backend schema.
// Conventions match the server: money = INTEGER paise, timestamps = epoch-ms,
// syncable PKs = client UUID (TEXT). `dirty` marks locally-changed rows that
// the sync engine (Part 6) still needs to push.
import 'package:drift/drift.dart';

mixin _Syncable on Table {
  TextColumn get id => text()();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  IntColumn get deletedAt => integer().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();
}

class Products extends Table with _Syncable {
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();
  TextColumn get name => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get brandId => text().nullable()();
  TextColumn get unitId => text().nullable()();
  TextColumn get hsn => text().nullable()();
  IntColumn get gstRate => integer().withDefault(const Constant(0))();
  IntColumn get purchasePrice => integer().withDefault(const Constant(0))();
  IntColumn get sellingPrice => integer().withDefault(const Constant(0))();
  IntColumn get mrp => integer().withDefault(const Constant(0))();
  IntColumn get stock => integer().withDefault(const Constant(0))();
  IntColumn get reorderLevel => integer().withDefault(const Constant(0))();
  TextColumn get batchNo => text().nullable()();
  IntColumn get expiryAt => integer().nullable()();
  TextColumn get imageUrl => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class Customers extends Table with _Syncable {
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get groupName => text().withDefault(const Constant('walk-in'))();
  IntColumn get loyaltyPoints => integer().withDefault(const Constant(0))();
  IntColumn get creditLimit => integer().withDefault(const Constant(0))();
  IntColumn get balance => integer().withDefault(const Constant(0))();
  TextColumn get gstin => text().nullable()();
  TextColumn get stateCode => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Suppliers extends Table with _Syncable {
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get gstin => text().nullable()();
  IntColumn get balance => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table with _Syncable {
  TextColumn get name => text()();
  TextColumn get parentId => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class Brands extends Table with _Syncable {
  TextColumn get name => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class Units extends Table with _Syncable {
  TextColumn get name => text()();
  TextColumn get shortName => text().withDefault(const Constant(''))();
  @override
  Set<Column> get primaryKey => {id};
}

class Bills extends Table with _Syncable {
  TextColumn get invoiceNo => text().nullable()();
  TextColumn get localNo => text().nullable()(); // provisional number before sync
  TextColumn get branchId => text().withDefault(const Constant('BR01'))();
  TextColumn get customerId => text().nullable()();
  TextColumn get cashierId => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('completed'))();
  IntColumn get subTotal => integer()();
  IntColumn get itemDiscount => integer().withDefault(const Constant(0))();
  IntColumn get billDiscount => integer().withDefault(const Constant(0))();
  IntColumn get cgst => integer().withDefault(const Constant(0))();
  IntColumn get sgst => integer().withDefault(const Constant(0))();
  IntColumn get igst => integer().withDefault(const Constant(0))();
  IntColumn get totalTax => integer().withDefault(const Constant(0))();
  IntColumn get roundOff => integer().withDefault(const Constant(0))();
  IntColumn get grandTotal => integer()();
  IntColumn get paid => integer().withDefault(const Constant(0))();
  BoolColumn get interState => boolean().withDefault(const Constant(false))();
  TextColumn get idempotencyKey => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();
  // 'pending' | 'synced' — whether the server has acknowledged this bill.
  TextColumn get syncState => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

class BillItems extends Table {
  TextColumn get id => text()();
  TextColumn get billId => text()();
  TextColumn get productId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get hsn => text().nullable()();
  IntColumn get qty => integer()();
  IntColumn get unitPrice => integer()();
  IntColumn get lineDiscount => integer().withDefault(const Constant(0))();
  IntColumn get gstRate => integer().withDefault(const Constant(0))();
  IntColumn get taxable => integer()();
  IntColumn get cgst => integer().withDefault(const Constant(0))();
  IntColumn get sgst => integer().withDefault(const Constant(0))();
  IntColumn get igst => integer().withDefault(const Constant(0))();
  IntColumn get lineTotal => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get billId => text()();
  TextColumn get method => text()();
  IntColumn get amount => integer()();
  TextColumn get reference => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class InventoryLedger extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text()();
  IntColumn get change => integer()();
  TextColumn get reason => text()();
  TextColumn get refType => text().nullable()();
  TextColumn get refId => text().nullable()();
  IntColumn get balanceAfter => integer()();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Write-ahead outbox for the sync engine (Part 6). Every local mutation that
/// must reach the server is appended here and drained in order.
class OutboxOps extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get opId => text()(); // UUID, idempotency handle
  TextColumn get entity => text()(); // 'bill' | 'product' | 'customer'
  TextColumn get type => text()(); // 'checkout' | 'upsert' | ...
  TextColumn get payload => text()(); // JSON
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get nextAttemptAt => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  IntColumn get createdAt => integer()();
}

/// Per-entity pull cursor (last successfully pulled updated_at).
class SyncMeta extends Table {
  TextColumn get entity => text()();
  IntColumn get lastPulledAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {entity};
}
