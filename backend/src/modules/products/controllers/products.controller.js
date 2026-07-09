import { z } from 'zod';
import { ProductsService } from '../services/products.service.js';
import { asyncHandler, ok, badRequest } from '../../../utils/http.js';

const GST = z.union([z.literal(0), z.literal(5), z.literal(12), z.literal(18), z.literal(28)]);

export const productSchema = z.object({
  id: z.string().uuid().optional(),
  sku: z.string().optional(),
  barcode: z.string().optional(),
  name: z.string().min(1),
  categoryId: z.string().optional(),
  brandId: z.string().optional(),
  unitId: z.string().optional(),
  hsn: z.string().optional(),
  gstRate: GST.default(0),
  purchasePrice: z.number().int().nonnegative().default(0),
  sellingPrice: z.number().int().nonnegative().default(0),
  mrp: z.number().int().nonnegative().default(0),
  openingStock: z.number().int().default(0),
  reorderLevel: z.number().int().nonnegative().default(0),
  batchNo: z.string().optional(),
  expiryAt: z.number().int().optional(),
  imageUrl: z.string().optional(),
  active: z.boolean().optional(),
});

export const ProductsController = {
  list: asyncHandler((req, res) => {
    const limit = Math.min(Number(req.query.limit ?? 100), 500);
    const offset = Number(req.query.offset ?? 0);
    ok(res, ProductsService.list({ limit, offset }));
  }),
  search: asyncHandler((req, res) => {
    const term = String(req.query.q ?? '').trim();
    if (!term) throw badRequest('q is required');
    ok(res, ProductsService.search(term));
  }),
  byBarcode: asyncHandler((req, res) => {
    ok(res, ProductsService.byBarcode(req.params.barcode));
  }),
  get: asyncHandler((req, res) => ok(res, ProductsService.get(req.params.id))),
  create: asyncHandler((req, res) => ok(res, ProductsService.create(req.body), 201)),
  update: asyncHandler((req, res) => ok(res, ProductsService.update(req.params.id, req.body))),
  remove: asyncHandler((req, res) => {
    ProductsService.remove(req.params.id);
    ok(res, { success: true });
  }),
};
