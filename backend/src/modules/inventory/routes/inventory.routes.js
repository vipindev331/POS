import { Router } from 'express';
import { z } from 'zod';
import { InventoryService } from '../services/inventory.service.js';
import { ProductsService } from '../../products/services/products.service.js';
import { validate } from '../../../middleware/validate.js';
import { authenticate } from '../../../middleware/auth.js';
import { asyncHandler, ok } from '../../../utils/http.js';

const adjustSchema = z.object({
  productId: z.string().min(1),
  change: z.number().int(),
  reason: z.enum(['stock_in', 'stock_out', 'adjustment', 'audit', 'purchase', 'transfer']).default('adjustment'),
  note: z.string().optional(),
});

const router = Router();
router.use(authenticate);

router.post('/adjust', validate(adjustSchema),
  asyncHandler((req, res) => ok(res, InventoryService.adjust(req.body, req.user, req.ip))));
router.get('/:productId/ledger',
  asyncHandler((req, res) => ok(res, InventoryService.ledger(req.params.productId))));
router.get('/low-stock', asyncHandler((_req, res) => ok(res, ProductsService.list())));

export default router;
