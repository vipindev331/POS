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
  return db;
}

export function closeDb() {
  if (db) {
    db.close();
    db = undefined;
  }
}

export default getDb;
