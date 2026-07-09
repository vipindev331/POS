import { z } from 'zod';
import { CustomersService } from '../services/customers.service.js';
import { asyncHandler, ok, badRequest } from '../../../utils/http.js';

export const customerSchema = z.object({
  id: z.string().uuid().optional(),
  name: z.string().min(1),
  phone: z.string().optional(),
  email: z.string().email().optional().or(z.literal('')),
  group: z.string().optional(),
  creditLimit: z.number().int().nonnegative().optional(),
  gstin: z.string().optional(),
  stateCode: z.string().optional(),
});

export const CustomersController = {
  list: asyncHandler((req, res) => ok(res, CustomersService.list())),
  search: asyncHandler((req, res) => {
    const term = String(req.query.q ?? '').trim();
    if (!term) throw badRequest('q is required');
    ok(res, CustomersService.search(term));
  }),
  get: asyncHandler((req, res) => ok(res, CustomersService.get(req.params.id))),
  create: asyncHandler((req, res) => ok(res, CustomersService.create(req.body), 201)),
  update: asyncHandler((req, res) => ok(res, CustomersService.update(req.params.id, req.body))),
  remove: asyncHandler((req, res) => {
    CustomersService.remove(req.params.id);
    ok(res, { success: true });
  }),
  ledger: asyncHandler((req, res) => ok(res, CustomersService.ledger(req.params.id))),
  history: asyncHandler((req, res) => ok(res, CustomersService.history(req.params.id))),
};
