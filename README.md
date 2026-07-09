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

## Build plan

Delivered in 10 approval-gated parts (see `ARCHITECTURE.md §10`). **Part 1 (this) = architecture +
folder structure.** Next: Part 2, the backend.

## Getting started (per part)

- **Backend:** `cd backend && npm install --cache <scratchpad>/npm-cache --maxsockets=3 && npm run setup && npm start` (port 4000) — *available from Part 2.*
- **Flutter:** `cd pos_app && flutter pub get && flutter run -d chrome` — *available from Part 3.*

## Toolchain (verified on this machine)

Node 22.8 · npm 10.8 · Flutter 3.38.5 · Dart 3.10.4
