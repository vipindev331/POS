import { z } from 'zod';
import { AuthService } from '../services/auth.service.js';
import { asyncHandler, ok } from '../../../utils/http.js';

export const loginSchema = z.object({
  username: z.string().min(1),
  password: z.string().min(1),
});
export const refreshSchema = z.object({ refreshToken: z.string().min(10) });
export const createUserSchema = z.object({
  username: z.string().min(3),
  password: z.string().min(6),
  fullName: z.string().optional(),
  role: z.enum(['admin', 'manager', 'staff']).default('staff'),
  permissions: z.array(z.string()).default([]),
});
export const updateUserSchema = z.object({
  fullName: z.string().optional(),
  role: z.enum(['admin', 'manager', 'staff']).optional(),
  permissions: z.array(z.string()).optional(),
  active: z.boolean().optional(),
});
export const resetPasswordSchema = z.object({ password: z.string().min(6) });

export const AuthController = {
  login: asyncHandler(async (req, res) => {
    const { username, password } = req.body;
    ok(res, await AuthService.login(username, password, req.ip));
  }),
  refresh: asyncHandler(async (req, res) => {
    ok(res, await AuthService.refresh(req.body.refreshToken, req.ip));
  }),
  logout: asyncHandler(async (req, res) => {
    await AuthService.logout(req.body.refreshToken);
    ok(res, { success: true });
  }),
  me: asyncHandler(async (req, res) => {
    ok(res, AuthService.me(req.user.id));
  }),
  createUser: asyncHandler(async (req, res) => {
    ok(res, await AuthService.createUser(req.body, req.user), 201);
  }),
  listUsers: asyncHandler((req, res) => {
    ok(res, AuthService.listUsers(req.user));
  }),
  updateUser: asyncHandler((req, res) => {
    ok(res, AuthService.updateUser(req.params.id, req.body, req.user));
  }),
  resetPassword: asyncHandler(async (req, res) => {
    ok(res, await AuthService.resetPassword(req.params.id, req.body.password, req.user));
  }),
  deleteUser: asyncHandler((req, res) => {
    ok(res, AuthService.deleteUser(req.params.id, req.user));
  }),
};
