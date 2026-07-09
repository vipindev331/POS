// Append-only audit logging helper.
import { getDb } from '../db/index.js';
import { newId, now } from './http.js';

const stmt = () =>
  getDb().prepare(
    `INSERT INTO audit_logs (id, user_id, action, entity, entity_id, detail, ip, created_at)
     VALUES (@id, @user_id, @action, @entity, @entity_id, @detail, @ip, @created_at)`,
  );

export function audit({ userId = null, action, entity = null, entityId = null, detail = null, ip = null }) {
  stmt().run({
    id: newId(),
    user_id: userId,
    action,
    entity,
    entity_id: entityId,
    detail: detail ? JSON.stringify(detail) : null,
    ip,
    created_at: now(),
  });
}
