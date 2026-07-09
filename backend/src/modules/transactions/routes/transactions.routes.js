import { Router } from 'express';
import { TransactionsController, checkoutSchema, returnSchema } from '../controllers/transactions.controller.js';
import { validate } from '../../../middleware/validate.js';
import { authenticate } from '../../../middleware/auth.js';

const router = Router();
router.use(authenticate);

router.post('/checkout', validate(checkoutSchema), TransactionsController.checkout);
router.post('/return', validate(returnSchema), TransactionsController.returnBill);
router.get('/', TransactionsController.list);
router.get('/:id', TransactionsController.get);

export default router;
