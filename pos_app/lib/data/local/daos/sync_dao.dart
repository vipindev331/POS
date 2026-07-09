import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/tables.dart';

part 'sync_dao.g.dart';

@DriftAccessor(tables: [OutboxOps, SyncMeta])
class SyncDao extends DatabaseAccessor<AppDatabase> with _$SyncDaoMixin {
  SyncDao(super.db);

  Future<int> enqueue(OutboxOpsCompanion op) => into(outboxOps).insert(op);

  /// Ops whose backoff window has elapsed, oldest first.
  Future<List<OutboxOp>> due(int nowMs, {int limit = 50}) =>
      (select(outboxOps)
            ..where((o) => o.nextAttemptAt.isSmallerOrEqualValue(nowMs))
            ..orderBy([(o) => OrderingTerm(expression: o.seq)])
            ..limit(limit))
          .get();

  Future<int> pendingCount() async {
    final c = countAll();
    final row = await (selectOnly(outboxOps)..addColumns([c])).getSingle();
    return row.read(c) ?? 0;
  }

  Future<void> remove(int seq) =>
      (delete(outboxOps)..where((o) => o.seq.equals(seq))).go();

  Future<void> reschedule(int seq, {required int attempts, required int nextAttemptAt, String? error}) =>
      (update(outboxOps)..where((o) => o.seq.equals(seq))).write(
        OutboxOpsCompanion(
          attempts: Value(attempts),
          nextAttemptAt: Value(nextAttemptAt),
          lastError: Value(error),
        ),
      );

  Future<int> cursor(String entity) async {
    final row = await (select(syncMeta)..where((m) => m.entity.equals(entity))).getSingleOrNull();
    return row?.lastPulledAt ?? 0;
  }

  Future<void> setCursor(String entity, int lastPulledAt) =>
      into(syncMeta).insertOnConflictUpdate(
        SyncMetaCompanion(entity: Value(entity), lastPulledAt: Value(lastPulledAt)),
      );
}
