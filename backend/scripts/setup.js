// One-shot setup: apply schema + seed baseline data.
import { seed } from '../src/db/seed.js';

seed()
  .then(() => {
    console.log('✔ setup done');
    process.exit(0);
  })
  .catch((err) => {
    console.error('setup failed:', err);
    process.exit(1);
  });
