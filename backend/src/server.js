// Entry point: ensure schema, then listen.
import env from './config/env.js';
import { migrate } from './db/migrate.js';
import { createApp } from './app.js';

migrate(); // idempotent — safe on every boot
const app = createApp();

const server = app.listen(env.port, () => {
  console.log(`▶ POS backend listening on http://localhost:${env.port} (branch ${env.branchId})`);
});

for (const sig of ['SIGINT', 'SIGTERM']) {
  process.on(sig, () => {
    console.log(`\n${sig} received, shutting down…`);
    server.close(() => process.exit(0));
  });
}
