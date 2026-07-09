import { Router } from 'express';
import { z } from 'zod';
import { SettingsService } from '../services/settings.service.js';
import { validate } from '../../../middleware/validate.js';
import { authenticate, requireRole } from '../../../middleware/auth.js';
import { asyncHandler, ok } from '../../../utils/http.js';

const setSchema = z.object({ value: z.any() });

const router = Router();
router.use(authenticate);

router.get('/', asyncHandler((_req, res) => ok(res, SettingsService.getAll())));
router.get('/:key', asyncHandler((req, res) => ok(res, SettingsService.get(req.params.key))));
router.put('/:key', requireRole('manager'), validate(setSchema),
  asyncHandler((req, res) => ok(res, SettingsService.set(req.params.key, req.body.value))));

export default router;
