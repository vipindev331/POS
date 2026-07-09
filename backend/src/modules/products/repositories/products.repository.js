import { getDb } from '../../../db/index.js';

const COLS = `id, sku, barcode, name, category_id, brand_id, unit_id, hsn, gst_rate,
  purchase_price, selling_price, mrp, stock, reorder_level, batch_no, expiry_at,
  image_url, active, created_at, updated_at, deleted_at`;

export const ProductsRepository = {
  list({ limit = 100, offset = 0 } = {}) {
    return getDb()
      .prepare(`SELECT ${COLS} FROM products WHERE deleted_at IS NULL ORDER BY name LIMIT ? OFFSET ?`)
      .all(limit, offset);
  },
  findById(id) {
    return getDb().prepare(`SELECT ${COLS} FROM products WHERE id = ? AND deleted_at IS NULL`).get(id);
  },
  findByBarcode(barcode) {
    return getDb()
      .prepare(`SELECT ${COLS} FROM products WHERE barcode = ? AND deleted_at IS NULL`)
      .get(barcode);
  },
  search(term, limit = 25) {
    const like = `%${term}%`;
    return getDb()
      .prepare(
        `SELECT ${COLS} FROM products
         WHERE deleted_at IS NULL AND (name LIKE ? OR sku LIKE ? OR barcode = ?)
         ORDER BY name LIMIT ?`,
      )
      .all(like, like, term, limit);
  },
  insert(p) {
    getDb()
      .prepare(
        `INSERT INTO products (${COLS})
         VALUES (@id,@sku,@barcode,@name,@category_id,@brand_id,@unit_id,@hsn,@gst_rate,
                 @purchase_price,@selling_price,@mrp,@stock,@reorder_level,@batch_no,@expiry_at,
                 @image_url,@active,@created_at,@updated_at,@deleted_at)`,
      )
      .run(p);
    return this.findById(p.id);
  },
  update(id, p) {
    getDb()
      .prepare(
        `UPDATE products SET sku=@sku, barcode=@barcode, name=@name, category_id=@category_id,
           brand_id=@brand_id, unit_id=@unit_id, hsn=@hsn, gst_rate=@gst_rate,
           purchase_price=@purchase_price, selling_price=@selling_price, mrp=@mrp,
           stock=@stock, reorder_level=@reorder_level, batch_no=@batch_no, expiry_at=@expiry_at,
           image_url=@image_url, active=@active, updated_at=@updated_at
         WHERE id=@id AND deleted_at IS NULL`,
      )
      .run({ ...p, id });
    return this.findById(id);
  },
  softDelete(id, ts) {
    getDb().prepare('UPDATE products SET deleted_at = ?, updated_at = ? WHERE id = ?').run(ts, ts, id);
  },
  lowStock() {
    return getDb()
      .prepare(
        `SELECT ${COLS} FROM products
         WHERE deleted_at IS NULL AND stock <= reorder_level AND stock > 0 ORDER BY stock`,
      )
      .all();
  },
  outOfStock() {
    return getDb()
      .prepare(`SELECT ${COLS} FROM products WHERE deleted_at IS NULL AND stock <= 0 ORDER BY name`)
      .all();
  },
};
