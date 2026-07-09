import { z } from 'zod';
import { TransactionsService } from '../services/transactions.service.js';
import { asyncHandler, ok } from '../../../utils/http.js';

const GST = z.union([z.literal(0), z.literal(5), z.literal(12), z.literal(18), z.literal(28)]);

const itemSchema = z.object({
  productId: z.string().optional(),
  name: z.string().optional(),
  hsn: z.string().optional(),
  qty: z.number().int().positive(),
  unitPrice: z.number().int().nonnegative().optional(),
  lineDiscount: z.number().int().nonnegative().default(0),
  gstRate: GST.optional(),
});

const paymentSchema = z.object({
  method: z.enum(['cash', 'card', 'upi', 'wallet', 'credit']),
  amount: z.number().int().nonnegative(),
  reference: z.string().optional(),
});

export const checkoutSchema = z.object({
  billId: z.string().uuid().optional(),
  idempotencyKey: z.string().min(8),
  customerId: z.string().optional(),
  items: z.array(itemSchema).min(1),
  billDiscount: z.number().int().nonnegative().default(0),
  payments: z.array(paymentSchema).default([]),
  interState: z.boolean().default(false),
  allowNegativeStock: z.boolean().default(false),
  status: z.enum(['completed', 'held']).default('completed'),
  note: z.string().optional(),
});

export const returnSchema = z.object({
  billId: z.string().min(1),
  reason: z.string().optional(),
});

export const TransactionsController = {
  checkout: asyncHandler((req, res) => {
    const result = TransactionsService.checkout(req.body, req.user);
    ok(res, result, result.replayed ? 200 : 201);
  }),
  list: asyncHandler((req, res) => {
    const limit = Math.min(Number(req.query.limit ?? 50), 200);
    const offset = Number(req.query.offset ?? 0);
    const from = req.query.from ? Number(req.query.from) : null;
    const to = req.query.to ? Number(req.query.to) : null;
    ok(res, TransactionsService.list({ limit, offset, from, to }));
  }),
  get: asyncHandler((req, res) => ok(res, TransactionsService.get(req.params.id))),
  returnBill: asyncHandler((req, res) => ok(res, TransactionsService.returnBill(req.body, req.user))),
};
