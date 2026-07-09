// Seeds baseline data: users, reference data, and a handful of products.
// Idempotent-ish: clears and re-seeds catalog + users if run repeatedly.
import bcrypt from 'bcryptjs';
import { getDb } from './index.js';
import { migrate } from './migrate.js';
import { newId, now } from '../utils/http.js';

export async function seed() {
  migrate();
  const db = getDb();
  const ts = now();

  const upsertUser = async (username, password, role, fullName) => {
    const existing = db.prepare('SELECT id FROM users WHERE username = ?').get(username);
    const hash = await bcrypt.hash(password, 10);
    if (existing) {
      db.prepare('UPDATE users SET password_hash=?, role=?, full_name=?, updated_at=? WHERE id=?')
        .run(hash, role, fullName, ts, existing.id);
      return;
    }
    db.prepare(
      `INSERT INTO users (id, username, password_hash, full_name, role, permissions, active, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, '[]', 1, ?, ?)`,
    ).run(newId(), username, hash, fullName, role, ts, ts);
  };

  await upsertUser('manager', 'manager123', 'manager', 'Store Manager');
  await upsertUser('staff', 'staff123', 'staff', 'Cashier');

  // Reference data (insert-if-absent by name).
  const ensure = (table, name, extra = {}) => {
    const row = db.prepare(`SELECT id FROM ${table} WHERE name = ? AND deleted_at IS NULL`).get(name);
    if (row) return row.id;
    const id = newId();
    const cols = ['id', 'name', ...Object.keys(extra), 'updated_at'];
    const vals = [id, name, ...Object.values(extra), ts];
    db.prepare(`INSERT INTO ${table} (${cols.join(',')}) VALUES (${cols.map(() => '?').join(',')})`).run(...vals);
    return id;
  };

  const catGrocery = ensure('categories', 'Grocery');
  const catBeverage = ensure('categories', 'Beverages');
  const brandGeneric = ensure('brands', 'Generic');
  const unitPc = ensure('units', 'Piece', { short_name: 'pc' });
  const unitKg = ensure('units', 'Kilogram', { short_name: 'kg' });

  const sampleProducts = [
    { name: 'Aashirvaad Atta 5kg', barcode: '8901030711107', gst: 5, purchase: 24000, sell: 27500, mrp: 29000, stock: 40, cat: catGrocery, unit: unitPc },
    { name: 'Tata Salt 1kg', barcode: '8901030510014', gst: 5, purchase: 2000, sell: 2800, mrp: 3000, stock: 120, cat: catGrocery, unit: unitPc },
    { name: 'Amul Milk 1L', barcode: '8901262010016', gst: 0, purchase: 5400, sell: 6600, mrp: 6800, stock: 60, cat: catBeverage, unit: unitPc },
    { name: 'Coca-Cola 750ml', barcode: '8901764010012', gst: 28, purchase: 3000, sell: 4000, mrp: 4500, stock: 80, cat: catBeverage, unit: unitPc },
    { name: 'Sugar (loose)', barcode: '2000000000015', gst: 5, purchase: 3800, sell: 4500, mrp: 5000, stock: 200, cat: catGrocery, unit: unitKg },
    { name: 'Colgate Toothpaste 200g', barcode: '8901314010015', gst: 18, purchase: 8000, sell: 9900, mrp: 11000, stock: 35, cat: catGrocery, unit: unitPc },
  ];

  const insertProd = db.prepare(
    `INSERT INTO products (id, sku, barcode, name, category_id, brand_id, unit_id, hsn, gst_rate,
        purchase_price, selling_price, mrp, stock, reorder_level, active, created_at, updated_at)
     VALUES (@id,@sku,@barcode,@name,@category_id,@brand_id,@unit_id,@hsn,@gst_rate,
        @purchase_price,@selling_price,@mrp,@stock,@reorder_level,1,@created_at,@updated_at)`,
  );
  for (const [i, p] of sampleProducts.entries()) {
    if (db.prepare('SELECT id FROM products WHERE barcode = ?').get(p.barcode)) continue;
    insertProd.run({
      id: newId(), sku: `SKU${String(i + 1).padStart(4, '0')}`, barcode: p.barcode, name: p.name,
      category_id: p.cat, brand_id: brandGeneric, unit_id: p.unit, hsn: '0000', gst_rate: p.gst,
      purchase_price: p.purchase, selling_price: p.sell, mrp: p.mrp, stock: p.stock,
      reorder_level: 10, created_at: ts, updated_at: ts,
    });
  }

  // A default walk-in customer.
  if (!db.prepare("SELECT id FROM customers WHERE name = 'Walk-in Customer'").get()) {
    db.prepare(
      `INSERT INTO customers (id, name, group_name, loyalty_points, credit_limit, balance, created_at, updated_at)
       VALUES (?, 'Walk-in Customer', 'walk-in', 0, 0, 0, ?, ?)`,
    ).run(newId(), ts, ts);
  }

  console.log('✔ seed complete — logins: manager/manager123, staff/staff123');
}

if (import.meta.url === `file://${process.argv[1]}`) {
  seed().then(() => process.exit(0));
}
