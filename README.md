# Retail Billing & POS

Offline-first, enterprise-grade Point-of-Sale for retail (supermarkets, pharmacies, electronics,
textiles, restaurants, wholesale). One **Flutter** client across Android / iOS / Windows / macOS /
Linux / Web, backed by a **Node.js + SQLite** sync/authority server.

## Repository layout

```
ARCHITECTURE.md      ← the design contract; read this first
backend/             ← Node.js (ESM) + Express + better-sqlite3 + JWT
  src/modules/…        feature-first (auth, products, transactions, sync, reports, …)
  src/{db,middleware,utils,config}
pos_app/             ← Flutter client (Clean Architecture + MVVM/Cubit)
  lib/app             MaterialApp.router, GoRouter, theme, nav shell
  lib/core            config, DI, errors, money/tax engine, network, platform abstraction
  lib/features/…      billing, products, customers, inventory, reports, …
  lib/data/local      Drift database, tables, DAOs (native SQLite + web WASM)
  lib/shared          reusable widgets & utils
```

## Core conventions (client + server, non-negotiable)

- Money is **integer paise** — never a `double`.
- Timestamps are **epoch-ms**; syncable primary keys are **client-generated UUID (TEXT)**.
- GST slabs 0/5/12/18/28; intra-state → CGST+SGST, inter-state → IGST.
- The tax engine is one spec, ported byte-for-byte between JS and Dart.

## Status — all 10 parts complete

| Part | Area | State |
|---|---|---|
| 1 | Architecture + folder structure | ✅ |
| 2 | Backend APIs (Express + SQLite + JWT, idempotent checkout, tax engine) | ✅ verified E2E |
| 3 | Flutter core (DI, router, theme, config, network, tax port) | ✅ |
| 4 | Drift offline DB (tables, DAOs, native + web) | ✅ |
| 5 | Billing (cart Cubit, barcode, F2–F12 shortcuts) | ✅ |
| 6 | Sync engine (outbox, backoff, delta pull, conflict) | ✅ verified E2E |
| 7 | Printing (ESC/POS thermal + web HTML 80mm) | ✅ |
| 8 | Auth UI (login, guards, session) | ✅ verified E2E |
| 9 | Reports + dashboard, products/customers/settings, CSV export | ✅ |
| 10 | Deployment (Docker, build recipes, docs) | ✅ |

See `ARCHITECTURE.md` for the design contract and **`DEPLOYMENT.md`** for shipping.

## Getting started

- **Backend:** `cd backend && npm install && npm run setup && npm start` (port 4000).
  Logins: `manager/manager123`, `staff/staff123`. If `~/.npm` gives EACCES, add
  `--cache <dir> --maxsockets=3` to the install.
- **Flutter:** `cd pos_app && flutter pub get && dart run build_runner build --delete-conflicting-outputs && flutter run -d chrome`
  (point at the backend with `--dart-define=API_BASE_URL=http://localhost:4000/api/v1`).

## Testing

- Backend: `cd backend && npm test` (tax engine).
- Client: `cd pos_app && flutter analyze && flutter test`. Integration tests
  (`test/*_integration_test.dart`) drive the live backend and auto-skip when it's down;
  run them with `--dart-define=API_BASE_URL=http://127.0.0.1:4000/api/v1`.

## Toolchain (verified on this machine)

Node 22.8 · npm 10.8 · Flutter 3.38.5 · Dart 3.10.4
