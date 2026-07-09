import { getDb } from '../../../db/index.js';
import { newId } from '../../../utils/http.js';

export const InventoryRepository = {
  // Records a stock movement and updates the product's on-hand quantity.
  // Must be called inside a transaction by the caller for atomicity.
  applyMovement({ productId, change, reason, refType = null, refId = null, note = null, ts }) {
    const db = getDb();
    const prod = db.prepare('SELECT stock FROM products WHERE id = ?').get(productId);
    if (!prod) throw new Error(`product ${productId} not found`);
    const balanceAfter = prod.stock + change;
    db.prepare('UPDATE products SET stock = ?, updated_at = ? WHERE id = ?').run(balanceAfter, ts, productId);
    db.prepare(
      `INSERT INTO inventory_ledger (id, product_id, change, reason, ref_type, ref_id, balance_after, note, created_at)
       VALUES (@id,@product_id,@change,@reason,@ref_type,@ref_id,@balance_after,@note,@created_at)`,
    ).run({
      id: newId(), product_id: productId, change, reason,
      ref_type: refType, ref_id: refId, balance_after: balanceAfter, note, created_at: ts,
    });
    return balanceAfter;
  },
  ledger(productId, limit = 200) {
    return getDb()
      .prepare('SELECT * FROM inventory_ledger WHERE product_id = ? ORDER BY created_at DESC LIMIT ?')
      .all(productId, limit);
  },
  currentStock(productId) {
    const r = getDb().prepare('SELECT stock FROM products WHERE id = ?').get(productId);
    return r?.stock ?? 0;
  },
};
