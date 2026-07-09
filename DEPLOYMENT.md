# Deployment Guide

How to build, configure, and ship the POS in production. Two artifacts: the
**backend** (one per shop/branch, the authority server) and the **Flutter client**
(the six platform builds, all from one codebase).

---

## 0. Configuration surface

| What | Where | Notes |
|---|---|---|
| Backend port / secrets / DB path / branch | `backend/.env` (copy from `.env.example`) | **Set strong `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` in production** — the server refuses to boot in `NODE_ENV=production` with the dev defaults. |
| Client → backend URL | `--dart-define=API_BASE_URL=...` at build time | defaults to `http://localhost:4000/api/v1` |
| Company profile / printer | in-app **Settings** screen (stored per device: JSON file native / localStorage web) | drives receipts |

One `BRANCH_ID` per backend instance — it namespaces invoice-number allocation.

---

## 1. Backend

### 1a. Bare metal / VM
```bash
cd backend
cp .env.example .env         # then edit: set real JWT secrets, PORT, BRANCH_ID
npm ci --omit=dev            # or: npm install --omit=dev
node scripts/setup.js        # apply schema + seed (first run only)
NODE_ENV=production node src/server.js
```

Keep it running with a process manager:
```bash
# pm2
pm2 start src/server.js --name pos-backend --env production
pm2 save && pm2 startup
```
or a systemd unit (`/etc/systemd/system/pos-backend.service`):
```ini
[Unit]
Description=POS Backend
After=network.target
[Service]
WorkingDirectory=/opt/pos/backend
ExecStart=/usr/bin/node src/server.js
Environment=NODE_ENV=production
EnvironmentFile=/opt/pos/backend/.env
Restart=always
[Install]
WantedBy=multi-user.target
```

### 1b. Docker
```bash
cd backend
docker build -t pos-backend .
docker run -d --name pos-backend -p 4000:4000 \
  -e JWT_ACCESS_SECRET=$(openssl rand -hex 32) \
  -e JWT_REFRESH_SECRET=$(openssl rand -hex 32) \
  -e BRANCH_ID=BR01 \
  -v pos-data:/data \
  pos-backend
```
The SQLite file lives on the `pos-data` volume (WAL mode). Back it up by copying
`/data/pos.sqlite*` while the container is stopped, or use `sqlite3 .backup`.

### 1c. Hardening checklist
- [ ] Real JWT secrets (32+ random bytes each), rotated periodically.
- [ ] Put it behind TLS (nginx/Caddy reverse proxy) — never serve JWT over plain HTTP in production.
- [ ] Restrict `CORS_ORIGINS` to the client's real origin(s).
- [ ] Firewall the port; only the reverse proxy reaches :4000.
- [ ] Schedule DB backups; test a restore.

---

## 2. Flutter client

Always pass the production API URL at build time:
```
--dart-define=API_BASE_URL=https://pos.example.com/api/v1
```
Regenerate code first if building from a fresh checkout (generated files are gitignored):
```bash
cd pos_app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Web
```bash
flutter build web --release --dart-define=API_BASE_URL=https://pos.example.com/api/v1
# serve build/web/ behind the same TLS host (nginx/Caddy/static host).
```
`web/sqlite3.wasm` and `web/drift_worker.js` are bundled automatically — the
offline IndexedDB-backed database needs them. Serve them with correct MIME types
(`application/wasm`).

### Windows / macOS / Linux (desktop)
```bash
flutter build windows --release --dart-define=API_BASE_URL=...
flutter build macos   --release --dart-define=API_BASE_URL=...
flutter build linux   --release --dart-define=API_BASE_URL=...
```
Package with the platform's tooling (MSIX / DMG / AppImage or `.deb`). Network
thermal printing (RAW 9100) works out of the box; USB/Bluetooth dispatch plugs
into the seam in `receipt_printer_native.dart`.

### Android / iOS
```bash
flutter build apk --release --dart-define=API_BASE_URL=...      # or appbundle
flutter build ipa --release --dart-define=API_BASE_URL=...
```
Camera barcode scanning uses the device camera; add the camera permission strings
when you wire a camera scanner package (the HID/keyboard-wedge path needs none).

---

## 3. First-run flow (per terminal)

1. Point the client at the backend (`API_BASE_URL`).
2. Sign in (`manager/manager123`, `staff/staff123` from the seed — **change these**).
3. Open **Settings**, fill company profile + printer, Save.
4. Open **Products → Sync** to pull the catalog into the local cache.
5. Bill offline all day; the sync engine drains the outbox and pulls updates
   whenever the network is up (watch the cloud badge in the billing bar).

---

## 4. Verify a release

```bash
# backend
cd backend && npm test && NODE_ENV=production node src/server.js   # boots only with real secrets

# client
cd pos_app && flutter analyze && flutter test
flutter build web --release --dart-define=API_BASE_URL=<url>
# End-to-end (backend up): the sync + auth integration tests exercise the full loop:
flutter test --dart-define=API_BASE_URL=http://127.0.0.1:4000/api/v1 \
  test/sync_integration_test.dart test/auth_integration_test.dart
```

---

## 5. Upgrades

- **Backend schema**: `schema.sql` is idempotent (`CREATE ... IF NOT EXISTS`).
  Additive changes apply on boot. For column changes, add a migration step before
  shipping (bump an internal version + run ALTERs).
- **Client DB**: bump `schemaVersion` in `database.dart` and add a Drift migration
  in `MigrationStrategy` when tables change.
- Clients are backward-tolerant: they keep selling offline and reconcile against
  whatever backend version answers `/sync`.
