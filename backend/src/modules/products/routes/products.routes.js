import { Router } from 'express';
import { ProductsController, productSchema } from '../controllers/products.controller.js';
import { validate } from '../../../middleware/validate.js';
import { authenticate, requireRole } from '../../../middleware/auth.js';

const router = Router();
router.use(authenticate);

// Read (either role). Order matters: static paths before :id.
router.get('/search', ProductsController.search);
router.get('/barcode/:barcode', ProductsController.byBarcode);
router.get('/', ProductsController.list);
router.get('/:id', ProductsController.get);

// Write (manager only).
router.post('/', requireRole('manager'), validate(productSchema), ProductsController.create);
router.put('/:id', requireRole('manager'), validate(productSchema), ProductsController.update);
router.delete('/:id', requireRole('manager'), ProductsController.remove);

export default router;
