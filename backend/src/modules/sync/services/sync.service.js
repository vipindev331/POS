import { getDb } from '../../../db/index.js';
import { TransactionsService } from '../../transactions/services/transactions.service.js';
import { ProductsService } from '../../products/services/products.service.js';
import { CustomersService } from '../../customers/services/customers.service.js';
import { badRequest } from '../../../utils/http.js';

// Entities the client may pull. Each maps to a table with an updated_at column.
const PULLABLE = {
  products: 'products',
  customers: 'customers',
  suppliers: 'suppliers',
  categories: 'categories',
  brands: 'brands',
  units: 'units',
  bills: 'bills',
};

export const SyncService = {
  /**
   * Pull all rows changed since `since` (epoch-ms) for the requested entities.
   * Includes soft-deleted rows so clients can tombstone locally.
   */
  pull({ since = 0, entities }) {
    const db = getDb();
    const list = entities?.length ? entities : Object.keys(PULLABLE);
    const serverTime = Date.now();
    const changes = {};
    for (const name of list) {
      const table = PULLABLE[name];
      if (!table) throw badRequest(`Unknown sync entity: ${name}`);
      changes[name] = db
        .prepare(`SELECT * FROM ${table} WHERE updated_at > ? ORDER BY updated_at ASC LIMIT 1000`)
        .all(since);
    }
    return { serverTime, changes };
  },

  /**
   * Push a batch of client operations. Each op is idempotent, so the whole
   * batch is safe to retry. Per-op results let the client clear its outbox
   * selectively. A failing op does not abort siblings.
   */
  push({ operations }, user) {
    if (!Array.isArray(operations)) throw badRequest('operations must be an array');
    const results = [];
    for (const op of operations) {
      try {
        const data = applyOp(op, user);
        results.push({ opId: op.opId ?? null, status: 'ok', data });
      } catch (err) {
        results.push({
          opId: op.opId ?? null,
          status: 'error',
          error: { message: err.message, code: err.code ?? 'error', statusCode: err.statusCode ?? 500 },
        });
      }
    }
    return { results, serverTime: Date.now() };
  },
};

function applyOp(op, user) {
  switch (`${op.entity}:${op.type}`) {
    case 'bill:checkout':
      return TransactionsService.checkout(op.payload, user).bill;
    case 'product:upsert':
      return op.payload.id && ProductsService_exists(op.payload.id)
        ? ProductsService.update(op.payload.id, op.payload)
        : ProductsService.create(op.payload);
    case 'customer:upsert':
      return op.payload.id && CustomersService_exists(op.payload.id)
        ? CustomersService.update(op.payload.id, op.payload)
        : CustomersService.create(op.payload);
    default:
      throw badRequest(`Unsupported sync op: ${op.entity}:${op.type}`);
  }
}

// Small existence probes so upsert can decide insert vs update without throwing.
function ProductsService_exists(id) {
  try { ProductsService.get(id); return true; } catch { return false; }
}
function CustomersService_exists(id) {
  try { CustomersService.get(id); return true; } catch { return false; }
}
