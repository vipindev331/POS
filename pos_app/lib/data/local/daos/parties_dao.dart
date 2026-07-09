import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/tables.dart';

part 'parties_dao.g.dart';

@DriftAccessor(tables: [Customers, Suppliers])
class PartiesDao extends DatabaseAccessor<AppDatabase> with _$PartiesDaoMixin {
  PartiesDao(super.db);

  Future<List<Customer>> allCustomers() =>
      (select(customers)..where((c) => c.deletedAt.isNull())..orderBy([(c) => OrderingTerm(expression: c.name)]))
          .get();

  Future<Customer?> customerById(String id) =>
      (select(customers)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<List<Customer>> searchCustomers(String term, {int limit = 25}) {
    final like = '%$term%';
    return (select(customers)
          ..where((c) => c.deletedAt.isNull() & (c.name.like(like) | c.phone.like(like)))
          ..limit(limit))
        .get();
  }

  Future<void> upsertCustomer(CustomersCompanion c) => into(customers).insertOnConflictUpdate(c);
  Future<void> upsertAllCustomers(List<CustomersCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(customers, rows));

  Future<List<Supplier>> allSuppliers() =>
      (select(suppliers)..where((s) => s.deletedAt.isNull())).get();
  Future<void> upsertAllSuppliers(List<SuppliersCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(suppliers, rows));
}
