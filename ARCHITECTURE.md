# Retail Billing & POS — Architecture

> Production-grade, offline-first Point-of-Sale for supermarkets, pharmacies, electronics,
> textiles, restaurants and wholesale. One Flutter client (Android / iOS / Windows / macOS /
> Linux / Web) + a Node.js sync/authority backend. This document is the **contract** every
> later part must respect.

---

## 1. System Overview

```
                         ┌──────────────────────────────────────────┐
                         │                CLIENTS                     │
                         │   Flutter single codebase, 6 platforms     │
                         │                                            │
                         │  Presentation (widgets, Cubits/Blocs)      │
                         │        │                                   │
                         │  Domain (entities, use-cases, repo iface)  │
                         │        │                                   │
                         │  Data (repo impl, Drift DAOs, Dio client)  │
                         │        │                                   │
                         │  Local Drift DB  ◄── source of truth ──►   │
                         └──────────────┬─────────────────────────────┘
                                        │  HTTPS / JSON  (only when online)
                                        │  Sync Engine: pull-changes / push-queue
                         ┌──────────────▼─────────────────────────────┐
                         │                BACKEND                     │
                         │   Node.js (ESM) + Express + JWT            │
                         │                                            │
                         │  Routes → Controllers → Services → Repos   │
                         │        │                                   │
                         │  SQLite (better-sqlite3, WAL mode)         │
                         └────────────────────────────────────────────┘
```

**Offline-first, not offline-only.** The client's Drift database is the source of truth for the
device. The backend is the *authority* for cross-device consistency (invoice number allocation,
conflict resolution, multi-branch consolidation). A terminal that never sees the network still
sells, prints, and reports; it reconciles when connectivity returns.

---

## 2. Guiding Principles

1. **Clean Architecture + MVVM.** Dependencies point inward: Presentation → Domain ← Data.
   Domain has zero Flutter/DB/HTTP imports. Cubits are the "ViewModel".
2. **Feature-first folders.** Everything for `billing` lives under `features/billing/{presentation,domain,data}`. Cross-feature primitives live in `core/` and `shared/`.
3. **Repository pattern + DI.** Domain talks to repository *interfaces*; `get_it` binds the
   concrete Data implementation at startup. Swapping local-only vs synced is a binding change.
4. **Platform abstraction.** Anything platform-specific (file storage, printing, barcode capture,
   DB backend) sits behind an interface with per-platform implementations selected via **conditional
   imports** (`stub` + `native` + `web`). Business logic never sees `dart:io` or `dart:html`.
5. **Money is never a double.** All currency is stored and computed as **integer paise**. See §6.
6. **Deterministic tax engine.** One spec (`backend/src/utils/money.js`) is ported byte-for-byte to
   Dart (`lib/core/money/tax_engine.dart`). Both sides must produce identical totals for a bill.
7. **Idempotency everywhere it syncs.** Client-generated UUIDs + server-side idempotency keys make
   every write safe to retry. A replayed checkout returns the same bill and never double-decrements
   stock or double-allocates an invoice number.
8. **No placeholder code.** Each part ships complete, tested, runnable slices.

---

## 3. Technology Stack

| Layer | Choice | Why |
|---|---|---|
| Client framework | Flutter 3.38, Dart 3.10 | one codebase, 6 targets |
| State management | `flutter_bloc` (Cubit) | explicit, testable ViewModels; predictable over Riverpod for a team handoff |
| Navigation | `go_router` | declarative, deep-link + web-URL friendly, guard support |
| Local DB | `drift` (+ `drift_flutter`, `sqlite3_flutter_libs`, `drift/wasm` for web) | typed SQL, reactive queries, native SQLite + IndexedDB-backed WASM on web |
| Models | `freezed` + `json_serializable` | immutable entities, value equality, safe unions for state |
| DI | `get_it` | simple service locator, no build step |
| HTTP | `dio` | interceptors for JWT refresh + retry |
| Misc | `connectivity_plus`, `shared_preferences`, `path_provider`, `intl`, `uuid`, `equatable` | |
| Backend runtime | Node.js 22 (ESM) | modern, LTS-adjacent |
| Web framework | Express 4 | ubiquitous, middleware ecosystem |
| Server DB | `better-sqlite3` (WAL) | synchronous, fast, zero external service; fits single-tenant shop deployments |
| Auth | `jsonwebtoken` (access + refresh), `bcrypt` | standard JWT + hashed passwords |
| Hardening | `helmet`, `express-rate-limit`, `zod` validation | XSS/headers, brute-force, input validation |

> **Note on the original brief:** it named Riverpod. This build standardises on **flutter_bloc
> (Cubit)** for the ViewModel layer — a deliberate, documented deviation for testability and a
> cleaner team handoff. Everything else in the brief's stack is honoured.

---

## 4. Backend Architecture

**Layering (per feature module):**

```
routes/         Express Router; maps HTTP verb+path → controller. Thin.
controllers/    Parse/validate (zod) req, call service, shape HTTP response. No business logic.
services/       Business rules, transactions, invariants (stock, invoice #, idempotency).
repositories/   SQL against better-sqlite3. Only place that knows the schema.
```

**Cross-cutting middleware:** `helmet` → CORS → rate-limit → JSON body → **auth (JWT verify)** →
**RBAC (role guard)** → route → **error handler** (last) → **audit logger**.

**Modules:** `auth`, `products`, `customers`, `suppliers`, `inventory`, `transactions` (billing /
checkout / returns), `sync`, `reports`, `settings`.

**Key server invariants**
- **Invoice numbers** are allocated *only* by the server, from a per-branch monotonic counter inside
  a transaction — clients hold a provisional local number until sync confirms the authoritative one.
- **Checkout is idempotent**: `POST /transactions` carries a client UUID `bill_id` + `idempotency_key`.
  Replays return the stored bill; stock decrements exactly once.
- **Negative stock** is blocked unless the caller has manager role and passes an explicit override flag
  (audited).
- Reports are **role-gated** (profit/expense = manager only).

---

## 5. Flutter Client Architecture

### 5.1 Layer rules
- **Presentation**: `Screen`/widgets + a `Cubit` per screen/flow emitting immutable `State`
  (freezed). No repository or Drift imports in widgets — only the Cubit.
- **Domain**: pure Dart `entities`, `usecases` (single-responsibility callables), and abstract
  `repositories`. No Flutter, no Drift, no Dio.
- **Data**: `repositories_impl` implementing domain interfaces, backed by **Drift DAOs** (local)
  and **Dio remote data sources** (sync). Maps Drift rows / JSON ↔ domain entities.

### 5.2 `pos_app/` structure (feature-first)

```
lib/
├── main.dart                      # bootstrap: DI init → runApp
├── app/
│   ├── app.dart                   # MaterialApp.router
│   ├── router.dart                # GoRouter + auth/role guards
│   ├── theme.dart                 # light/dark, design tokens
│   └── shell_screen.dart          # adaptive nav shell (rail/bottom-bar)
├── core/
│   ├── config/                    # AppConfig + ConfigStore (JSON native / localStorage web)
│   │   ├── config_store.dart              # interface
│   │   ├── config_store_native.dart       # dart:io JSON file
│   │   ├── config_store_web.dart          # localStorage
│   │   └── config_store_factory.dart      # conditional import selector
│   ├── di/injector.dart           # get_it registrations
│   ├── error/failures.dart        # typed failures (freezed union)
│   ├── money/tax_engine.dart      # PORT of backend money.js (byte-equivalent)
│   ├── network/
│   │   ├── dio_client.dart        # base Dio + JWT refresh interceptor
│   │   └── connectivity_service.dart
│   └── platform/                  # platform abstractions (printing, barcode, storage)
├── features/
│   ├── auth/          {presentation,domain,data}
│   ├── dashboard/     {presentation,domain,data}
│   ├── products/      {presentation,domain,data}
│   ├── customers/     {presentation,domain,data}
│   ├── suppliers/     {presentation,domain,data}
│   ├── inventory/     {presentation,domain,data}
│   ├── billing/       {presentation,domain,data}
│   ├── sync/          {presentation,domain,data}
│   ├── reports/       {presentation,domain,data}
│   └── settings/      {presentation,domain,data}
├── data/
│   └── local/                     # Drift database + tables + DAOs (shared across features)
│       ├── database.dart
│       ├── tables/ …
│       ├── daos/ …
│       ├── connection/native.dart # sqlite3 (io)
│       └── connection/web.dart     # drift wasm
└── shared/
    ├── widgets/                   # reusable UI (buttons, adaptive scaffold, data tables)
    └── utils/                     # formatters, extensions, keyboard intents
```

### 5.3 Platform matrix

| Concern | Desktop (Win/mac/Linux) | Mobile (Android/iOS) | Web |
|---|---|---|---|
| Local DB | Drift → native SQLite | Drift → native SQLite | Drift → WASM/IndexedDB |
| Config storage | JSON file (`path_provider`) | JSON file | `localStorage` |
| Barcode input | USB/BT HID keyboard listener | camera continuous scan | camera or USB HID |
| Receipt printing | ESC/POS (USB/BT/Network), no preview | share/OS print | 80mm HTML + CSS `@media print` |

Each is a single interface with conditional-import implementations; `injector.dart` wires the right
one. **Business logic is identical on all six platforms.**

---

## 6. Money & Tax Rules (shared spec)

- **Unit: integer paise.** ₹123.45 → `12345`. No `double` ever touches money.
- **Rounding:** line and tax computations use integer arithmetic; the grand total is rounded to the
  nearest rupee and the delta is stored as `round_off`.
- **GST slabs:** 0 / 5 / 12 / 18 / 28 %. **Intra-state** → split into CGST + SGST (half each).
  **Inter-state** → single IGST.
- **Order of operations:** item discount → taxable value → tax → line total → bill discount →
  round-off → grand total. Documented and unit-tested identically on client and server.

---

## 7. Data Conventions (client ↔ server)

| Rule | Value |
|---|---|
| Money | INTEGER paise |
| Timestamps | epoch milliseconds (INTEGER) |
| Syncable primary keys | client-generated UUID v4 (TEXT) |
| Soft delete | `deleted_at` epoch-ms nullable (never hard-delete syncable rows) |
| Change tracking | `updated_at` + `dirty`/`sync_state` flag on client tables |
| Idempotency | `idempotency_key` on checkout & every pushed mutation |

---

## 8. Security Model

JWT access (short-lived) + refresh (rotated) · bcrypt password hashing · zod input validation on
every endpoint · parameterised SQL only (no string-built queries) · helmet headers + output encoding
(XSS) · per-IP + per-account rate limiting · RBAC (`manager` / `staff` + granular permissions) ·
append-only audit log for sensitive actions (overrides, price edits, voids, logins).

---

## 9. Sync Engine (design, built in Part 6)

Write-ahead **outbox queue** on the client: every local mutation enqueues an idempotent operation.
Background worker (never blocks UI) pushes pending ops with exponential backoff + retry; pulls only
changed rows since a per-entity `last_pulled_at` cursor. Conflicts resolved last-write-wins on
`updated_at`, except invoice numbers (server authority) and stock (server recomputes from the ledger).
Duplicate invoices are impossible: provisional local number + server-allocated authoritative number
keyed by the bill UUID.

---

## 10. Build & Delivery Plan (approval-gated)

| Part | Deliverable |
|---|---|
| **1** | Architecture + Folder Structure *(this document + scaffold)* |
| 2 | Backend APIs (schema, modules, checkout, tax engine, seed) |
| 3 | Flutter core setup (DI, router, theme, config, network, tax port) |
| 4 | Drift offline DB (tables, DAOs, native + web) |
| 5 | Billing module (cart Cubit, barcode, F2–F12 shortcuts) |
| 6 | Sync engine (outbox, retry/backoff, conflict resolver) |
| 7 | Printing (ESC/POS native + web HTML receipt) |
| 8 | Auth UI (login, token storage, role guards) |
| 9 | Reports UI (+ PDF/Excel/CSV export) |
| 10 | Deployment (build recipes, packaging, docs) |

Each part ends with a summary, a file list, and **waits for approval** before the next.
