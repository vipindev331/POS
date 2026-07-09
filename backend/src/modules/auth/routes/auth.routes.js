import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { AuthController, loginSchema, refreshSchema, createUserSchema } from '../controllers/auth.controller.js';
import { validate } from '../../../middleware/validate.js';
import { authenticate, requireRole } from '../../../middleware/auth.js';

const router = Router();

// Tighter brute-force limit on the login endpoint specifically.
const loginLimiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 20, standardHeaders: true, legacyHeaders: false });

router.post('/login', loginLimiter, validate(loginSchema), AuthController.login);
router.post('/refresh', validate(refreshSchema), AuthController.refresh);
router.post('/logout', validate(refreshSchema), AuthController.logout);
router.get('/me', authenticate, AuthController.me);

// Manager-only: create staff/manager accounts.
router.post('/users', authenticate, requireRole('manager'), validate(createUserSchema), AuthController.createUser);

export default router;
