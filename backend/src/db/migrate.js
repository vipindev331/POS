// Applies schema.sql (idempotent — all CREATE ... IF NOT EXISTS).
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { getDb } from './index.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export function migrate() {
  const db = getDb();
  const sql = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
  db.exec(sql);
  widenUserRoles(db);
  return db;
}

// SQLite can't ALTER a CHECK constraint. Databases created before the 'admin'
// role existed still restrict users.role to ('manager','staff'), which would
// reject admin accounts. Rebuild the table once, preserving all data.
function widenUserRoles(db) {
  const usersSql =
    db.prepare("SELECT sql FROM sqlite_master WHERE type='table' AND name='users'").get()?.sql ?? '';
  if (usersSql.includes("'admin'")) return; // already widened

  db.exec('PRAGMA foreign_keys=OFF');
  db.transaction(() => {
    db.exec(`
      CREATE TABLE users_new (
        id            TEXT PRIMARY KEY,
        username      TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        full_name     TEXT NOT NULL DEFAULT '',
        role          TEXT NOT NULL CHECK (role IN ('admin','manager','staff')),
        permissions   TEXT NOT NULL DEFAULT '[]',
        active        INTEGER NOT NULL DEFAULT 1,
        created_at    INTEGER NOT NULL,
        updated_at    INTEGER NOT NULL,
        deleted_at    INTEGER
      );
      INSERT INTO users_new SELECT id, username, password_hash, full_name, role,
        permissions, active, created_at, updated_at, deleted_at FROM users;
      DROP TABLE users;
      ALTER TABLE users_new RENAME TO users;
    `);
  })();
  db.exec('PRAGMA foreign_keys=ON');
}

// Run directly: `node src/db/migrate.js`
if (import.meta.url === `file://${process.argv[1]}`) {
  migrate();
  console.log('✔ schema applied');
}
