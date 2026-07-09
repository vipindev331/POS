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
  return db;
}

// Run directly: `node src/db/migrate.js`
if (import.meta.url === `file://${process.argv[1]}`) {
  migrate();
  console.log('✔ schema applied');
}
