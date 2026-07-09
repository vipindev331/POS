import { Router } from 'express';
import { z } from 'zod';
import { SuppliersService } from '../services/suppliers.service.js';
import { validate } from '../../../middleware/validate.js';
import { authenticate, requireRole } from '../../../middleware/auth.js';
import { asyncHandler, ok } from '../../../utils/http.js';

const supplierSchema = z.object({
  id: z.string().uuid().optional(),
  name: z.string().min(1),
  phone: z.string().optional(),
  email: z.string().email().optional().or(z.literal('')),
  gstin: z.string().optional(),
});

const router = Router();
router.use(authenticate);

router.get('/', asyncHandler((_req, res) => ok(res, SuppliersService.list())));
router.get('/:id', asyncHandler((req, res) => ok(res, SuppliersService.get(req.params.id))));
router.get('/:id/ledger', asyncHandler((req, res) => ok(res, SuppliersService.ledger(req.params.id))));
router.post('/', requireRole('manager'), validate(supplierSchema),
  asyncHandler((req, res) => ok(res, SuppliersService.create(req.body), 201)));
router.put('/:id', requireRole('manager'), validate(supplierSchema),
  asyncHandler((req, res) => ok(res, SuppliersService.update(req.params.id, req.body))));
router.delete('/:id', requireRole('manager'),
  asyncHandler((req, res) => { SuppliersService.remove(req.params.id); ok(res, { success: true }); }));

export default router;
