import { Router } from 'express';
import { CustomersController, customerSchema } from '../controllers/customers.controller.js';
import { validate } from '../../../middleware/validate.js';
import { authenticate, requireRole } from '../../../middleware/auth.js';

const router = Router();
router.use(authenticate);

router.get('/search', CustomersController.search);
router.get('/', CustomersController.list);
router.get('/:id', CustomersController.get);
router.get('/:id/ledger', CustomersController.ledger);
router.get('/:id/history', CustomersController.history);

router.post('/', validate(customerSchema), CustomersController.create);
router.put('/:id', validate(customerSchema), CustomersController.update);
router.delete('/:id', requireRole('manager'), CustomersController.remove);

export default router;
