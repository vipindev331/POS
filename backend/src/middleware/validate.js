// Zod validation middleware. Validates req.body/query/params against a schema
// and replaces them with the parsed (typed, stripped) result.
import { badRequest } from '../utils/http.js';

export function validate(schema, source = 'body') {
  return (req, _res, next) => {
    const result = schema.safeParse(req[source]);
    if (!result.success) {
      const details = result.error.issues.map((i) => ({
        path: i.path.join('.'),
        message: i.message,
      }));
      return next(badRequest('Validation failed', details));
    }
    req[source] = result.data;
    next();
  };
}
