// Opens the SQLite database as a singleton and applies pragmas for correctness
// and performance (WAL journal, enforced foreign keys, NORMAL sync).
import Database from 'better-sqlite3';
import fs from 'node:fs';
import path from 'node:path';
import env from '../config/env.js';

let db;

export function getDb() {
  if (db) return db;

  fs.mkdirSync(path.dirname(env.dbPath), { recursive: true });
  db = new Database(env.dbPath);
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');
  db.pragma('synchronous = NORMAL');
  db.pragma('busy_timeout = 5000');
  migrate(db);
  return db;
}

// Lightweight, idempotent migrations for databases created before a column
// existed. `CREATE TABLE IF NOT EXISTS` never adds columns to an existing table,
// so additive changes are applied here. Duplicate-column errors are ignored.
function migrate(database) {
  const addColumn = (table, column, type) => {
    try {
      database.prepare(`ALTER TABLE ${table} ADD COLUMN ${column} ${type}`).run();
    } catch (err) {
      const msg = String(err.message);
      // Fresh DB (table not created yet — schema.sql already has the column) or
      // already-migrated DB: both are safe to ignore.
      if (!msg.includes('duplicate column name') && !msg.includes('no such table')) throw err;
    }
  };
  // Customer audit trail: who created / last edited each record.
  addColumn('customers', 'created_by', 'TEXT');
  addColumn('customers', 'updated_by', 'TEXT');
}

export function closeDb() {
  if (db) {
    db.close();
    db = undefined;
  }
}

export default getDb;
