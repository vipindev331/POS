import { getDb } from '../../../db/index.js';

export const TransactionsRepository = {
  findByIdempotencyKey(key) {
    if (!key) return null;
    return getDb().prepare('SELECT * FROM bills WHERE idempotency_key = ?').get(key);
  },
  findBillRow(id) {
    return getDb().prepare('SELECT * FROM bills WHERE id = ? AND deleted_at IS NULL').get(id);
  },
  items(billId) {
    return getDb().prepare('SELECT * FROM bill_items WHERE bill_id = ?').all(billId);
  },
  payments(billId) {
    return getDb().prepare('SELECT * FROM payments WHERE bill_id = ?').all(billId);
  },

  // Allocate the next per-branch invoice number. Caller must be inside a tx.
  allocateInvoiceNo(branchId) {
    const db = getDb();
    let counter = db.prepare('SELECT * FROM invoice_counters WHERE branch_id = ?').get(branchId);
    if (!counter) {
      db.prepare('INSERT INTO invoice_counters (branch_id, next_no, prefix) VALUES (?, 1, ?)').run(branchId, 'INV');
      counter = { branch_id: branchId, next_no: 1, prefix: 'INV' };
    }
    const seq = counter.next_no;
    db.prepare('UPDATE invoice_counters SET next_no = next_no + 1 WHERE branch_id = ?').run(branchId);
    return `${counter.prefix}-${branchId}-${String(seq).padStart(6, '0')}`;
  },

  insertBill(b) {
    getDb()
      .prepare(
        `INSERT INTO bills
         (id, invoice_no, branch_id, customer_id, cashier_id, status, sub_total, item_discount,
          bill_discount, cgst, sgst, igst, total_tax, round_off, grand_total, paid, inter_state,
          idempotency_key, note, created_at, updated_at)
         VALUES (@id,@invoice_no,@branch_id,@customer_id,@cashier_id,@status,@sub_total,@item_discount,
          @bill_discount,@cgst,@sgst,@igst,@total_tax,@round_off,@grand_total,@paid,@inter_state,
          @idempotency_key,@note,@created_at,@updated_at)`,
      )
      .run(b);
  },
  insertItem(it) {
    getDb()
      .prepare(
        `INSERT INTO bill_items
         (id, bill_id, product_id, name, hsn, qty, unit_price, line_discount, gst_rate,
          taxable, cgst, sgst, igst, line_total)
         VALUES (@id,@bill_id,@product_id,@name,@hsn,@qty,@unit_price,@line_discount,@gst_rate,
          @taxable,@cgst,@sgst,@igst,@line_total)`,
      )
      .run(it);
  },
  insertPayment(p) {
    getDb()
      .prepare(
        `INSERT INTO payments (id, bill_id, method, amount, reference, created_at)
         VALUES (@id,@bill_id,@method,@amount,@reference,@created_at)`,
      )
      .run(p);
  },
  insertLedger(e) {
    getDb()
      .prepare(
        `INSERT INTO ledger_entries
         (id, party_type, party_id, ref_type, ref_id, debit, credit, balance_after, note, created_at)
         VALUES (@id,@party_type,@party_id,@ref_type,@ref_id,@debit,@credit,@balance_after,@note,@created_at)`,
      )
      .run(e);
  },
  updateStatus(id, status, ts) {
    getDb().prepare('UPDATE bills SET status = ?, updated_at = ? WHERE id = ?').run(status, ts, id);
  },
  list({ limit = 50, offset = 0, from = null, to = null } = {}) {
    const clauses = ['deleted_at IS NULL'];
    const params = [];
    if (from) { clauses.push('created_at >= ?'); params.push(from); }
    if (to) { clauses.push('created_at <= ?'); params.push(to); }
    return getDb()
      .prepare(`SELECT * FROM bills WHERE ${clauses.join(' AND ')} ORDER BY created_at DESC LIMIT ? OFFSET ?`)
      .all(...params, limit, offset);
  },
};
