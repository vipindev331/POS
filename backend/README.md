# POS Backend

Node.js (ESM) + Express + better-sqlite3 + JWT. Authority server for the offline-first POS client:
allocates invoice numbers, resolves conflicts, and holds the consolidated ledger.

## Run

```bash
npm install                 # if ~/.npm gives EACCES: add --cache <dir> --maxsockets=3
npm run setup               # apply schema + seed sample data & users
npm start                   # http://localhost:4000
npm test                    # tax-engine unit tests
```

Seeded logins: **manager / manager123**, **staff / staff123**.

## Layout

```
src/
  config/env.js             config + tiny .env loader
  db/                       schema.sql, migrate.js, seed.js, connection (WAL)
  middleware/               auth (JWT), validate (zod), error handler
  utils/                    money.js (TAX ENGINE — canonical spec), jwt, http, audit
  modules/<feature>/        routes → controllers → services → repositories
  app.js, server.js
tests/money.test.js
```

## API (base `/api/v1`)

| Method | Path | Role | Notes |
|---|---|---|---|
| POST | `/auth/login` | – | returns access + refresh tokens |
| POST | `/auth/refresh` | – | rotates refresh token |
| GET | `/auth/me` | any | current user |
| POST | `/auth/users` | manager | create staff/manager |
| GET | `/products`, `/products/search?q=`, `/products/barcode/:code`, `/products/:id` | any | |
| POST/PUT/DELETE | `/products…` | manager | |
| CRUD | `/customers`, `/suppliers` | any read / manager delete | + `/customers/:id/ledger`,`/history` |
| POST | `/inventory/adjust` | any (neg. needs manager) | stock movements |
| POST | `/transactions/checkout` | any | **idempotent** (idempotencyKey) |
| POST | `/transactions/return` | any | restock + reverse credit |
| GET | `/transactions`, `/transactions/:id` | any | |
| POST | `/sync/pull`, `/sync/push` | any | delta sync + idempotent op batch |
| GET | `/reports/dashboard`, `/profit` | manager | `/sales`,`/gst`,`/inventory` any |
| GET/PUT | `/settings`, `/settings/:key` | any / manager | |

## Invariants

- Money = **integer paise**; timestamps = **epoch-ms**; syncable PKs = **client UUID**.
- Checkout is **idempotent**: replaying an `idempotencyKey` (or bill id) returns the stored bill;
  stock decrements exactly once; invoice numbers are server-allocated per branch.
- **Negative stock** blocked unless a **manager** passes `allowNegativeStock` (audited).
- Reports for profit/dashboard are **manager-only**. All sensitive actions hit the **audit log**.
- The tax engine (`utils/money.js`) is the shared spec ported byte-for-byte to Dart.
