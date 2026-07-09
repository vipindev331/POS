import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import {
  AuthController,
  loginSchema,
  refreshSchema,
  createUserSchema,
  updateUserSchema,
  resetPasswordSchema,
} from '../controllers/auth.controller.js';
import { validate } from '../../../middleware/validate.js';
import { authenticate, requireRole } from '../../../middleware/auth.js';

const router = Router();

// Tighter brute-force limit on the login endpoint specifically.
const loginLimiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 20, standardHeaders: true, legacyHeaders: false });

router.post('/login', loginLimiter, validate(loginSchema), AuthController.login);
router.post('/refresh', validate(refreshSchema), AuthController.refresh);
router.post('/logout', validate(refreshSchema), AuthController.logout);
router.get('/me', authenticate, AuthController.me);

// Manager-only: list + create + edit + delete + reset-password for accounts.
const managerOnly = [authenticate, requireRole('manager')];
router.get('/users', ...managerOnly, AuthController.listUsers);
router.post('/users', ...managerOnly, validate(createUserSchema), AuthController.createUser);
router.patch('/users/:id', ...managerOnly, validate(updateUserSchema), AuthController.updateUser);
router.post('/users/:id/reset-password', ...managerOnly, validate(resetPasswordSchema), AuthController.resetPassword);
router.delete('/users/:id', ...managerOnly, AuthController.deleteUser);

export default router;
