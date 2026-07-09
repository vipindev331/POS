import { getDb } from '../../../db/index.js';

const COLS = `id, name, phone, email, group_name, loyalty_points, credit_limit, balance,
  gstin, state_code, created_at, updated_at, deleted_at`;

export const CustomersRepository = {
  list({ limit = 100, offset = 0 } = {}) {
    return getDb()
      .prepare(`SELECT ${COLS} FROM customers WHERE deleted_at IS NULL ORDER BY name LIMIT ? OFFSET ?`)
      .all(limit, offset);
  },
  findById(id) {
    return getDb().prepare(`SELECT ${COLS} FROM customers WHERE id = ? AND deleted_at IS NULL`).get(id);
  },
  search(term, limit = 25) {
    const like = `%${term}%`;
    return getDb()
      .prepare(
        `SELECT ${COLS} FROM customers WHERE deleted_at IS NULL AND (name LIKE ? OR phone LIKE ?)
         ORDER BY name LIMIT ?`,
      )
      .all(like, like, limit);
  },
  insert(c) {
    getDb()
      .prepare(
        `INSERT INTO customers (${COLS})
         VALUES (@id,@name,@phone,@email,@group_name,@loyalty_points,@credit_limit,@balance,
                 @gstin,@state_code,@created_at,@updated_at,@deleted_at)`,
      )
      .run(c);
    return this.findById(c.id);
  },
  update(id, c) {
    getDb()
      .prepare(
        `UPDATE customers SET name=@name, phone=@phone, email=@email, group_name=@group_name,
           credit_limit=@credit_limit, gstin=@gstin, state_code=@state_code, updated_at=@updated_at
         WHERE id=@id AND deleted_at IS NULL`,
      )
      .run({ ...c, id });
    return this.findById(id);
  },
  softDelete(id, ts) {
    getDb().prepare('UPDATE customers SET deleted_at=?, updated_at=? WHERE id=?').run(ts, ts, id);
  },
  adjustBalance(id, delta, ts) {
    getDb().prepare('UPDATE customers SET balance = balance + ?, updated_at=? WHERE id=?').run(delta, ts, id);
    return this.findById(id);
  },
  addLoyalty(id, points, ts) {
    getDb()
      .prepare('UPDATE customers SET loyalty_points = loyalty_points + ?, updated_at=? WHERE id=?')
      .run(points, ts, id);
  },
  ledger(id) {
    return getDb()
      .prepare(
        `SELECT * FROM ledger_entries WHERE party_type='customer' AND party_id=? ORDER BY created_at DESC`,
      )
      .all(id);
  },
  bills(id) {
    return getDb()
      .prepare(`SELECT * FROM bills WHERE customer_id=? AND deleted_at IS NULL ORDER BY created_at DESC`)
      .all(id);
  },
};
