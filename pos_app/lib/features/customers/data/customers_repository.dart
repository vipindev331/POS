// Creates a customer offline-first: writes to Drift (device source of truth,
// marked dirty) and enqueues an idempotent 'customer:upsert' outbox op for the
// sync engine to push. Available to any signed-in user (staff or manager).
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/database.dart';

class CustomersRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  CustomersRepository(this._db);

  Future<List<Customer>> all() => _db.partiesDao.allCustomers();
  Future<List<Customer>> search(String term) => _db.partiesDao.searchCustomers(term);

  /// Reactive stream of all customers — updates live on local edits and on
  /// changes pulled by the sync engine.
  Stream<List<Customer>> watch() => _db.partiesDao.watchCustomers();

  /// Returns a human-readable reason if [phone] or [email] already belongs to
  /// another customer (excluding [exceptId] so editing doesn't self-collide),
  /// or null when the values are free to use. Checked against the local cache
  /// for instant feedback; the server enforces the same rule authoritatively.
  Future<String?> duplicateReason({String? phone, String? email, String? exceptId}) async {
    if (phone != null && phone.isNotEmpty) {
      final match = await _db.partiesDao.customerByPhone(phone);
      if (match != null && match.id != exceptId) {
        return 'Phone $phone is already used by "${match.name}"';
      }
    }
    if (email != null && email.isNotEmpty) {
      final match = await _db.partiesDao.customerByEmail(email);
      if (match != null && match.id != exceptId) {
        return 'Email $email is already used by "${match.name}"';
      }
    }
    return null;
  }

  /// Add a customer locally and queue it for sync. Returns the new local id.
  /// [by] is the current user's username, recorded as the creator (the server
  /// re-stamps this authoritatively from the auth token on sync).
  Future<String> addCustomer({
    required String name,
    String? phone,
    String? email,
    String group = 'walk-in',
    int creditLimit = 0,
    String? gstin,
    String? stateCode,
    String? by,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.partiesDao.upsertCustomer(CustomersCompanion.insert(
      id: id,
      name: name,
      phone: Value(phone),
      email: Value(email),
      groupName: Value(group),
      creditLimit: Value(creditLimit),
      gstin: Value(gstin),
      stateCode: Value(stateCode),
      createdBy: Value(by),
      updatedBy: Value(by),
      createdAt: Value(now),
      updatedAt: Value(now),
      dirty: const Value(true),
    ));

    await _enqueueUpsert(
      id: id,
      name: name,
      phone: phone,
      email: email,
      group: group,
      creditLimit: creditLimit,
      gstin: gstin,
      stateCode: stateCode,
      by: by,
      now: now,
    );
    return id;
  }

  /// Edit an existing customer. Updates the local cache and enqueues a
  /// 'customer:upsert' op with the full new state. Available to all users.
  Future<void> updateCustomer(
    String id, {
    required String name,
    String? phone,
    String? email,
    String group = 'walk-in',
    int creditLimit = 0,
    String? gstin,
    String? stateCode,
    String? by,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.partiesDao.updateCustomer(
      id,
      CustomersCompanion(
        name: Value(name),
        phone: Value(phone),
        email: Value(email),
        groupName: Value(group),
        creditLimit: Value(creditLimit),
        gstin: Value(gstin),
        stateCode: Value(stateCode),
        updatedBy: Value(by),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );

    await _enqueueUpsert(
      id: id,
      name: name,
      phone: phone,
      email: email,
      group: group,
      creditLimit: creditLimit,
      gstin: gstin,
      stateCode: stateCode,
      by: by,
      now: now,
    );
  }

  /// Soft-delete a customer. Tombstones locally and enqueues a 'customer:delete'
  /// op for the server. Available to all users.
  Future<void> deleteCustomer(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.partiesDao.softDeleteCustomer(id, now);
    await _db.syncDao.enqueue(OutboxOpsCompanion.insert(
      opId: 'del-$id',
      entity: 'customer',
      type: 'delete',
      payload: jsonEncode({'id': id}),
      createdAt: now,
      nextAttemptAt: Value(now),
    ));
  }

  Future<void> _enqueueUpsert({
    required String id,
    required String name,
    String? phone,
    String? email,
    required String group,
    required int creditLimit,
    String? gstin,
    String? stateCode,
    String? by,
    required int now,
  }) {
    return _db.syncDao.enqueue(OutboxOpsCompanion.insert(
      // Per-edit opId keeps each upsert idempotent yet distinct in the outbox.
      opId: 'up-$id-$now',
      entity: 'customer',
      type: 'upsert',
      payload: jsonEncode({
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'group': group,
        'creditLimit': creditLimit,
        'gstin': gstin,
        'stateCode': stateCode,
        // Fallback audit hint; the server prefers the authenticated user.
        'updatedBy': by,
      }),
      createdAt: now,
      nextAttemptAt: Value(now),
    ));
  }
}
