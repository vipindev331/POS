// HTTP helpers: typed errors + a uniform JSON envelope.
import { v4 as uuidv4 } from 'uuid';

export const newId = () => uuidv4();
export const now = () => Date.now();

export class ApiError extends Error {
  constructor(statusCode, message, code = undefined, details = undefined) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
  }
}
export const badRequest = (m, d) => new ApiError(400, m, 'bad_request', d);
export const unauthorized = (m = 'Unauthorized') => new ApiError(401, m, 'unauthorized');
export const forbidden = (m = 'Forbidden') => new ApiError(403, m, 'forbidden');
export const notFound = (m = 'Not found') => new ApiError(404, m, 'not_found');
export const conflict = (m, d) => new ApiError(409, m, 'conflict', d);

// Wrap async controllers so thrown errors reach the error middleware.
export const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

export const ok = (res, data, status = 200) => res.status(status).json({ data });
