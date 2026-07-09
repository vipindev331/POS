// Central error handler + 404. Must be registered last.
import env from '../config/env.js';
import { ApiError } from '../utils/http.js';
import { ValidationError } from '../utils/money.js';

export function notFoundHandler(_req, res) {
  res.status(404).json({ error: { code: 'not_found', message: 'Route not found' } });
}

// eslint-disable-next-line no-unused-vars
export function errorHandler(err, _req, res, _next) {
  let status = err.statusCode ?? 500;
  let code = err.code ?? 'internal_error';

  if (err instanceof ValidationError) {
    status = 400;
    code = 'bad_request';
  }
  // better-sqlite3 constraint violations -> 409
  if (err.code === 'SQLITE_CONSTRAINT_UNIQUE' || err.code === 'SQLITE_CONSTRAINT_PRIMARYKEY') {
    status = 409;
    code = 'conflict';
  }

  const body = { error: { code, message: err.message || 'Internal error' } };
  if (err instanceof ApiError && err.details) body.error.details = err.details;
  if (!env.isProd && status === 500) body.error.stack = err.stack;

  if (status === 500) console.error('[error]', err);
  res.status(status).json(body);
}
