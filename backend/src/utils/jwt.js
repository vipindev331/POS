// JWT issue/verify for access + refresh tokens.
import jwt from 'jsonwebtoken';
import crypto from 'node:crypto';
import env from '../config/env.js';

export function signAccess(user) {
  return jwt.sign(
    { sub: user.id, username: user.username, role: user.role, type: 'access' },
    env.jwt.accessSecret,
    { expiresIn: env.jwt.accessTtl },
  );
}

export function signRefresh(user, tokenId) {
  return jwt.sign(
    { sub: user.id, jti: tokenId, type: 'refresh' },
    env.jwt.refreshSecret,
    { expiresIn: env.jwt.refreshTtl },
  );
}

export function verifyAccess(token) {
  const payload = jwt.verify(token, env.jwt.accessSecret);
  if (payload.type !== 'access') throw new Error('wrong token type');
  return payload;
}

export function verifyRefresh(token) {
  const payload = jwt.verify(token, env.jwt.refreshSecret);
  if (payload.type !== 'refresh') throw new Error('wrong token type');
  return payload;
}

// Hash refresh tokens before storing so a DB leak can't reuse them.
export const hashToken = (token) => crypto.createHash('sha256').update(token).digest('hex');
