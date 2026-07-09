import { Router } from 'express';
import { z } from 'zod';
import { SyncService } from '../services/sync.service.js';
import { validate } from '../../../middleware/validate.js';
import { authenticate } from '../../../middleware/auth.js';
import { asyncHandler, ok } from '../../../utils/http.js';

const pullSchema = z.object({
  since: z.number().int().nonnegative().default(0),
  entities: z.array(z.string()).optional(),
});
const pushSchema = z.object({
  operations: z.array(
    z.object({
      opId: z.string().optional(),
      entity: z.string(),
      type: z.string(),
      payload: z.record(z.any()),
    }),
  ),
});

const router = Router();
router.use(authenticate);

router.post('/pull', validate(pullSchema), asyncHandler((req, res) => ok(res, SyncService.pull(req.body))));
router.post('/push', validate(pushSchema), asyncHandler((req, res) => ok(res, SyncService.push(req.body, req.user))));

export default router;
