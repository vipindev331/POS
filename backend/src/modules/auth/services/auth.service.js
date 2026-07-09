import bcrypt from 'bcryptjs';
import { AuthRepository } from '../repositories/auth.repository.js';
import { signAccess, signRefresh, verifyRefresh, hashToken } from '../../../utils/jwt.js';
import { newId, now, unauthorized } from '../../../utils/http.js';
import { audit } from '../../../utils/audit.js';
import env from '../../../config/env.js';

const REFRESH_TTL_MS = 30 * 24 * 60 * 60 * 1000; // mirrors JWT_REFRESH_TTL default

function publicUser(u) {
  return {
    id: u.id,
    username: u.username,
    fullName: u.full_name,
    role: u.role,
    permissions: JSON.parse(u.permissions ?? '[]'),
  };
}

function issueTokens(user, ip) {
  const tokenId = newId();
  const accessToken = signAccess(user);
  const refreshToken = signRefresh(user, tokenId);
  AuthRepository.saveRefreshToken({
    id: tokenId,
    user_id: user.id,
    token_hash: hashToken(refreshToken),
    expires_at: now() + REFRESH_TTL_MS,
    created_at: now(),
  });
  audit({ userId: user.id, action: 'login', entity: 'user', entityId: user.id, ip });
  return { accessToken, refreshToken, user: publicUser(user) };
}

export const AuthService = {
  async login(username, password, ip) {
    const user = AuthRepository.findByUsername(username);
    if (!user || !user.active) throw unauthorized('Invalid credentials');
    const okPass = await bcrypt.compare(password, user.password_hash);
    if (!okPass) throw unauthorized('Invalid credentials');
    return issueTokens(user, ip);
  },

  async refresh(refreshToken, ip) {
    let payload;
    try {
      payload = verifyRefresh(refreshToken);
    } catch {
      throw unauthorized('Invalid refresh token');
    }
    const stored = AuthRepository.findRefreshToken(payload.jti);
    if (!stored || stored.revoked || stored.token_hash !== hashToken(refreshToken)) {
      throw unauthorized('Refresh token revoked');
    }
    if (stored.expires_at < now()) throw unauthorized('Refresh token expired');

    const user = AuthRepository.findById(payload.sub);
    if (!user || !user.active) throw unauthorized('User inactive');

    // Rotate: revoke old, issue new pair.
    AuthRepository.revokeRefreshToken(stored.id);
    return issueTokens(user, ip);
  },

  async logout(refreshToken) {
    try {
      const payload = verifyRefresh(refreshToken);
      AuthRepository.revokeRefreshToken(payload.jti);
    } catch {
      /* already invalid — nothing to do */
    }
  },

  me(userId) {
    const user = AuthRepository.findById(userId);
    if (!user) throw unauthorized();
    return publicUser(user);
  },

  async createUser({ username, password, fullName = '', role = 'staff', permissions = [] }) {
    const hash = await bcrypt.hash(password, 10);
    return publicUser(
      AuthRepository.insertUser({
        id: newId(),
        username,
        password_hash: hash,
        full_name: fullName,
        role,
        permissions: JSON.stringify(permissions),
        created_at: now(),
        updated_at: now(),
      }),
    );
  },
};

export { publicUser, REFRESH_TTL_MS, env };
