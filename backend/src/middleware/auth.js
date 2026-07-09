// Authentication + role-based authorization middleware.
import { verifyAccess } from '../utils/jwt.js';
import { unauthorized, forbidden } from '../utils/http.js';

// Verifies the Bearer access token and attaches req.user.
export function authenticate(req, _res, next) {
  const header = req.headers.authorization ?? '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) return next(unauthorized('Missing bearer token'));
  try {
    const payload = verifyAccess(token);
    req.user = { id: payload.sub, username: payload.username, role: payload.role };
    next();
  } catch {
    next(unauthorized('Invalid or expired token'));
  }
}

// Restrict a route to specific roles. requireRole('manager')
export function requireRole(...roles) {
  return (req, _res, next) => {
    if (!req.user) return next(unauthorized());
    if (!roles.includes(req.user.role)) return next(forbidden('Insufficient role'));
    next();
  };
}
