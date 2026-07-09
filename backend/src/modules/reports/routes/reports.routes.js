import { Router } from 'express';
import { ReportsService } from '../services/reports.service.js';
import { authenticate, requireRole } from '../../../middleware/auth.js';
import { asyncHandler, ok } from '../../../utils/http.js';

const router = Router();
router.use(authenticate);

// Default range = last 30 days if not supplied.
function range(req) {
  const to = req.query.to ? Number(req.query.to) : Date.now();
  const from = req.query.from ? Number(req.query.from) : to - 30 * 24 * 60 * 60 * 1000;
  return { from, to };
}

router.get('/dashboard', requireRole('manager'), asyncHandler((_req, res) => ok(res, ReportsService.dashboard())));
router.get('/sales', asyncHandler((req, res) => ok(res, ReportsService.salesByDay(range(req)))));
router.get('/gst', asyncHandler((req, res) => ok(res, ReportsService.gstReport(range(req)))));
router.get('/profit', requireRole('manager'), asyncHandler((req, res) => ok(res, ReportsService.profitReport(range(req)))));
router.get('/inventory', asyncHandler((_req, res) => ok(res, ReportsService.inventoryReport())));

// Sold-products listing + per-product drill-down (available to all staff).
router.get('/sold', asyncHandler((req, res) => ok(res, ReportsService.soldProducts(range(req)))));
router.get('/sold/:productId', asyncHandler((req, res) =>
  ok(res, ReportsService.soldProductDetail({ ...range(req), productId: req.params.productId }))));

export default router;
