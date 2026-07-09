import { getDb } from '../../../db/index.js';

const COLS = `id, name, phone, email, gstin, balance, created_at, updated_at, deleted_at`;

export const SuppliersRepository = {
  list: () => getDb().prepare(`SELECT ${COLS} FROM suppliers WHERE deleted_at IS NULL ORDER BY name`).all(),
  findById: (id) => getDb().prepare(`SELECT ${COLS} FROM suppliers WHERE id=? AND deleted_at IS NULL`).get(id),
  insert(s) {
    getDb()
      .prepare(
        `INSERT INTO suppliers (${COLS})
         VALUES (@id,@name,@phone,@email,@gstin,@balance,@created_at,@updated_at,@deleted_at)`,
      )
      .run(s);
    return this.findById(s.id);
  },
  update(id, s) {
    getDb()
      .prepare(
        `UPDATE suppliers SET name=@name, phone=@phone, email=@email, gstin=@gstin, updated_at=@updated_at
         WHERE id=@id AND deleted_at IS NULL`,
      )
      .run({ ...s, id });
    return this.findById(id);
  },
  softDelete: (id, ts) =>
    getDb().prepare('UPDATE suppliers SET deleted_at=?, updated_at=? WHERE id=?').run(ts, ts, id),
  ledger: (id) =>
    getDb()
      .prepare(`SELECT * FROM ledger_entries WHERE party_type='supplier' AND party_id=? ORDER BY created_at DESC`)
      .all(id),
};
