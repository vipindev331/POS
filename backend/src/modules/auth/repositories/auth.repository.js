import { getDb } from '../../../db/index.js';

export const AuthRepository = {
  findByUsername(username) {
    return getDb().prepare('SELECT * FROM users WHERE username = ? AND deleted_at IS NULL').get(username);
  },
  findById(id) {
    return getDb().prepare('SELECT * FROM users WHERE id = ? AND deleted_at IS NULL').get(id);
  },
  insertUser(u) {
    getDb()
      .prepare(
        `INSERT INTO users (id, username, password_hash, full_name, role, permissions, active, created_at, updated_at)
         VALUES (@id, @username, @password_hash, @full_name, @role, @permissions, 1, @created_at, @updated_at)`,
      )
      .run(u);
    return u;
  },
  listUsers() {
    return getDb()
      .prepare('SELECT * FROM users WHERE deleted_at IS NULL ORDER BY full_name, username')
      .all();
  },
  updateUser(id, fields) {
    getDb()
      .prepare(
        `UPDATE users
            SET full_name = @full_name, role = @role, permissions = @permissions,
                active = @active, updated_at = @updated_at
          WHERE id = @id AND deleted_at IS NULL`,
      )
      .run({ ...fields, id });
    return AuthRepository.findById(id);
  },
  updatePassword(id, passwordHash, updatedAt) {
    getDb()
      .prepare('UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ? AND deleted_at IS NULL')
      .run(passwordHash, updatedAt, id);
  },
  softDeleteUser(id, deletedAt) {
    getDb()
      .prepare('UPDATE users SET active = 0, deleted_at = ?, updated_at = ? WHERE id = ?')
      .run(deletedAt, deletedAt, id);
  },
  saveRefreshToken(row) {
    getDb()
      .prepare(
        `INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at, revoked, created_at)
         VALUES (@id, @user_id, @token_hash, @expires_at, 0, @created_at)`,
      )
      .run(row);
  },
  findRefreshToken(id) {
    return getDb().prepare('SELECT * FROM refresh_tokens WHERE id = ?').get(id);
  },
  revokeRefreshToken(id) {
    getDb().prepare('UPDATE refresh_tokens SET revoked = 1 WHERE id = ?').run(id);
  },
  revokeAllForUser(userId) {
    getDb().prepare('UPDATE refresh_tokens SET revoked = 1 WHERE user_id = ?').run(userId);
  },
};
