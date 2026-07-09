-- ============================================================================
--  Retail Billing & POS — SQLite schema (server authority copy)
--  Conventions:
--    * money      : INTEGER paise
--    * timestamps : INTEGER epoch-ms
--    * syncable PK: TEXT client-generated UUID
--    * soft delete: deleted_at (epoch-ms) NULL = live
--    * change track: updated_at (epoch-ms) for pull-changes cursor
--  PRAGMAs (WAL, foreign_keys) are set by the connection layer, not here.
-- ============================================================================

-- ── Auth & audit ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id            TEXT PRIMARY KEY,
  username      TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  full_name     TEXT NOT NULL DEFAULT '',
  role          TEXT NOT NULL CHECK (role IN ('manager','staff')),
  permissions   TEXT NOT NULL DEFAULT '[]',          -- JSON array of permission keys
  active        INTEGER NOT NULL DEFAULT 1,
  created_at    INTEGER NOT NULL,
  updated_at    INTEGER NOT NULL,
  deleted_at    INTEGER
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
  id         TEXT PRIMARY KEY,
  user_id    TEXT NOT NULL REFERENCES users(id),
  token_hash TEXT NOT NULL,
  expires_at INTEGER NOT NULL,
  revoked    INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_refresh_user ON refresh_tokens(user_id);

CREATE TABLE IF NOT EXISTS audit_logs (
  id         TEXT PRIMARY KEY,
  user_id    TEXT,
  action     TEXT NOT NULL,          -- e.g. 'checkout', 'negative_stock_override'
  entity     TEXT,                   -- e.g. 'bill', 'product'
  entity_id  TEXT,
  detail     TEXT,                   -- JSON
  ip         TEXT,
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_logs(created_at);

-- ── Catalog reference data ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS categories (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, parent_id TEXT,
  updated_at INTEGER NOT NULL, deleted_at INTEGER
);
CREATE TABLE IF NOT EXISTS brands (
  id TEXT PRIMARY KEY, name TEXT NOT NULL,
  updated_at INTEGER NOT NULL, deleted_at INTEGER
);
CREATE TABLE IF NOT EXISTS units (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, short_name TEXT NOT NULL DEFAULT '',
  updated_at INTEGER NOT NULL, deleted_at INTEGER
);

-- ── Products ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS products (
  id             TEXT PRIMARY KEY,
  sku            TEXT,
  barcode        TEXT,
  name           TEXT NOT NULL,
  category_id    TEXT REFERENCES categories(id),
  brand_id       TEXT REFERENCES brands(id),
  unit_id        TEXT REFERENCES units(id),
  hsn            TEXT,
  gst_rate       INTEGER NOT NULL DEFAULT 0,        -- one of 0/5/12/18/28
  purchase_price INTEGER NOT NULL DEFAULT 0,        -- paise
  selling_price  INTEGER NOT NULL DEFAULT 0,        -- paise (tax-exclusive)
  mrp            INTEGER NOT NULL DEFAULT 0,        -- paise
  stock          INTEGER NOT NULL DEFAULT 0,        -- current on-hand qty
  reorder_level  INTEGER NOT NULL DEFAULT 0,
  batch_no       TEXT,
  expiry_at      INTEGER,                           -- epoch-ms
  image_url      TEXT,
  active         INTEGER NOT NULL DEFAULT 1,
  created_at     INTEGER NOT NULL,
  updated_at     INTEGER NOT NULL,
  deleted_at     INTEGER
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode) WHERE barcode IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_products_sku  ON products(sku);
CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);

-- Multiple selling prices (retail / wholesale / member ...)
CREATE TABLE IF NOT EXISTS product_prices (
  id         TEXT PRIMARY KEY,
  product_id TEXT NOT NULL REFERENCES products(id),
  label      TEXT NOT NULL,                          -- 'retail' | 'wholesale' | ...
  price      INTEGER NOT NULL,                       -- paise
  updated_at INTEGER NOT NULL, deleted_at INTEGER
);
CREATE INDEX IF NOT EXISTS idx_prices_product ON product_prices(product_id);

-- ── Customers & suppliers ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS customers (
  id             TEXT PRIMARY KEY,
  name           TEXT NOT NULL,
  phone          TEXT,
  email          TEXT,
  group_name     TEXT NOT NULL DEFAULT 'walk-in',
  loyalty_points INTEGER NOT NULL DEFAULT 0,
  credit_limit   INTEGER NOT NULL DEFAULT 0,         -- paise
  balance        INTEGER NOT NULL DEFAULT 0,         -- paise, +ve = owes us
  gstin          TEXT,
  state_code     TEXT,                               -- for intra/inter-state GST
  created_at     INTEGER NOT NULL,
  updated_at     INTEGER NOT NULL,
  deleted_at     INTEGER
);
CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone);

CREATE TABLE IF NOT EXISTS suppliers (
  id         TEXT PRIMARY KEY,
  name       TEXT NOT NULL,
  phone      TEXT,
  email      TEXT,
  gstin      TEXT,
  balance    INTEGER NOT NULL DEFAULT 0,             -- paise, +ve = we owe them
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER
);

-- Ledgers (append-only) for customer/supplier balances.
CREATE TABLE IF NOT EXISTS ledger_entries (
  id         TEXT PRIMARY KEY,
  party_type TEXT NOT NULL CHECK (party_type IN ('customer','supplier')),
  party_id   TEXT NOT NULL,
  ref_type   TEXT,                                   -- 'bill' | 'payment' | 'adjustment'
  ref_id     TEXT,
  debit      INTEGER NOT NULL DEFAULT 0,             -- paise
  credit     INTEGER NOT NULL DEFAULT 0,             -- paise
  balance_after INTEGER NOT NULL,
  note       TEXT,
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_ledger_party ON ledger_entries(party_type, party_id);

-- ── Inventory ledger (append-only stock movements) ─────────────────────────
CREATE TABLE IF NOT EXISTS inventory_ledger (
  id            TEXT PRIMARY KEY,
  product_id    TEXT NOT NULL REFERENCES products(id),
  change        INTEGER NOT NULL,                    -- +in / -out
  reason        TEXT NOT NULL,                       -- 'sale'|'return'|'purchase'|'adjustment'|'opening'|'transfer'
  ref_type      TEXT,
  ref_id        TEXT,
  balance_after INTEGER NOT NULL,
  note          TEXT,
  created_at    INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_invledger_product ON inventory_ledger(product_id);

-- ── Sales / billing ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS bills (
  id              TEXT PRIMARY KEY,                  -- client UUID
  invoice_no      TEXT UNIQUE,                       -- server-allocated authoritative number
  branch_id       TEXT NOT NULL,
  customer_id     TEXT REFERENCES customers(id),
  cashier_id      TEXT REFERENCES users(id),
  status          TEXT NOT NULL DEFAULT 'completed'  -- 'completed'|'held'|'returned'|'void'
                    CHECK (status IN ('completed','held','returned','void')),
  sub_total       INTEGER NOT NULL,
  item_discount   INTEGER NOT NULL DEFAULT 0,
  bill_discount   INTEGER NOT NULL DEFAULT 0,
  cgst            INTEGER NOT NULL DEFAULT 0,
  sgst            INTEGER NOT NULL DEFAULT 0,
  igst            INTEGER NOT NULL DEFAULT 0,
  total_tax       INTEGER NOT NULL DEFAULT 0,
  round_off       INTEGER NOT NULL DEFAULT 0,
  grand_total     INTEGER NOT NULL,
  paid            INTEGER NOT NULL DEFAULT 0,
  inter_state     INTEGER NOT NULL DEFAULT 0,
  idempotency_key TEXT UNIQUE,
  note            TEXT,
  created_at      INTEGER NOT NULL,
  updated_at      INTEGER NOT NULL,
  deleted_at      INTEGER
);
CREATE INDEX IF NOT EXISTS idx_bills_created  ON bills(created_at);
CREATE INDEX IF NOT EXISTS idx_bills_customer ON bills(customer_id);

CREATE TABLE IF NOT EXISTS bill_items (
  id           TEXT PRIMARY KEY,
  bill_id      TEXT NOT NULL REFERENCES bills(id),
  product_id   TEXT REFERENCES products(id),
  name         TEXT NOT NULL,                        -- snapshot at sale time
  hsn          TEXT,
  qty          INTEGER NOT NULL,
  unit_price   INTEGER NOT NULL,                     -- paise
  line_discount INTEGER NOT NULL DEFAULT 0,
  gst_rate     INTEGER NOT NULL DEFAULT 0,
  taxable      INTEGER NOT NULL,
  cgst         INTEGER NOT NULL DEFAULT 0,
  sgst         INTEGER NOT NULL DEFAULT 0,
  igst         INTEGER NOT NULL DEFAULT 0,
  line_total   INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_billitems_bill ON bill_items(bill_id);

CREATE TABLE IF NOT EXISTS payments (
  id         TEXT PRIMARY KEY,
  bill_id    TEXT NOT NULL REFERENCES bills(id),
  method     TEXT NOT NULL CHECK (method IN ('cash','card','upi','wallet','credit')),
  amount     INTEGER NOT NULL,                       -- paise
  reference  TEXT,
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_payments_bill ON payments(bill_id);

-- Per-branch monotonic invoice counter (server authority).
CREATE TABLE IF NOT EXISTS invoice_counters (
  branch_id TEXT PRIMARY KEY,
  next_no   INTEGER NOT NULL DEFAULT 1,
  prefix    TEXT NOT NULL DEFAULT 'INV'
);

-- ── Settings (single JSON blob keyed by 'company') ─────────────────────────
CREATE TABLE IF NOT EXISTS settings (
  key        TEXT PRIMARY KEY,
  value      TEXT NOT NULL,                          -- JSON
  updated_at INTEGER NOT NULL
);

-- ── Sync cursors (per client device) ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS sync_state (
  client_id  TEXT NOT NULL,
  entity     TEXT NOT NULL,
  last_pulled_at INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (client_id, entity)
);
