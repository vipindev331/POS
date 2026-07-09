import { getDb } from '../../../db/index.js';
import { now } from '../../../utils/http.js';

const DEFAULTS = {
  company: {
    name: 'My Retail Store',
    gstin: '',
    address: '',
    phone: '',
    email: '',
    logoUrl: '',
    currency: 'INR',
    stateCode: '',
  },
  tax: { pricesIncludeTax: false, defaultGstRate: 18 },
  printer: { type: 'thermal', width: 80, autoPrint: true },
  barcode: { prefixStrip: '', suffixEnter: true },
  backup: { auto: true, intervalHours: 24 },
};

export const SettingsService = {
  getAll() {
    const rows = getDb().prepare('SELECT key, value FROM settings').all();
    const stored = Object.fromEntries(rows.map((r) => [r.key, JSON.parse(r.value)]));
    return { ...DEFAULTS, ...stored };
  },
  get(key) {
    const row = getDb().prepare('SELECT value FROM settings WHERE key = ?').get(key);
    return row ? JSON.parse(row.value) : DEFAULTS[key] ?? null;
  },
  set(key, value) {
    getDb()
      .prepare(
        `INSERT INTO settings (key, value, updated_at) VALUES (?, ?, ?)
         ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at`,
      )
      .run(key, JSON.stringify(value), now());
    return this.get(key);
  },
};
