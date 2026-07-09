// Express application factory: middleware pipeline + route mounting.
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import env from './config/env.js';

import authRoutes from './modules/auth/routes/auth.routes.js';
import productsRoutes from './modules/products/routes/products.routes.js';
import customersRoutes from './modules/customers/routes/customers.routes.js';
import suppliersRoutes from './modules/suppliers/routes/suppliers.routes.js';
import inventoryRoutes from './modules/inventory/routes/inventory.routes.js';
import transactionsRoutes from './modules/transactions/routes/transactions.routes.js';
import syncRoutes from './modules/sync/routes/sync.routes.js';
import reportsRoutes from './modules/reports/routes/reports.routes.js';
import settingsRoutes from './modules/settings/routes/settings.routes.js';

import { notFoundHandler, errorHandler } from './middleware/error.js';

export function createApp() {
  const app = express();
  app.set('trust proxy', 1);

  app.use(helmet());
  app.use(
    cors({
      origin: env.corsOrigins.includes('*') ? true : env.corsOrigins,
      credentials: true,
    }),
  );
  app.use(express.json({ limit: '2mb' }));
  if (!env.isProd) app.use(morgan('dev'));

  // Global rate limit (login has its own tighter limiter).
  app.use(rateLimit({ windowMs: 60 * 1000, max: 300, standardHeaders: true, legacyHeaders: false }));

  app.get('/health', (_req, res) => res.json({ status: 'ok', time: Date.now(), branch: env.branchId }));

  const api = express.Router();
  api.use('/auth', authRoutes);
  api.use('/products', productsRoutes);
  api.use('/customers', customersRoutes);
  api.use('/suppliers', suppliersRoutes);
  api.use('/inventory', inventoryRoutes);
  api.use('/transactions', transactionsRoutes);
  api.use('/sync', syncRoutes);
  api.use('/reports', reportsRoutes);
  api.use('/settings', settingsRoutes);
  app.use('/api/v1', api);

  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}
