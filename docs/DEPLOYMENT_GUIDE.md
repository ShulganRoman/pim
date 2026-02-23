# Deployment Guide

## 1. Scope

This guide documents deployment implementation in detail:

- what each deployment file does;
- how services are wired;
- environment variables and port model;
- local and production-style deployment procedures;
- verification, rollback, and troubleshooting.

This guide is intentionally operational and implementation-focused.
For application architecture, see `docs/CODE_AND_ARCHITECTURE_GUIDE.md`.

---

## 2. Deployment Code Inventory

The deployment layer is implemented by the following files:

- `/Users/romanshulgan/pim/docker-compose.yml`
- `/Users/romanshulgan/pim/.env` and `/Users/romanshulgan/pim/.env.example`
- `/Users/romanshulgan/pim/pim-frontend/pim-project/Dockerfile`
- `/Users/romanshulgan/pim/pim-frontend/pim-project/nginx.conf`
- `/Users/romanshulgan/pim/pim-frontend/pim-project/.dockerignore`
- `/Users/romanshulgan/pim/pim-backend/Dockerfile`
- `/Users/romanshulgan/pim/db-init/00-create-role-and-db.sh`
- `/Users/romanshulgan/pim/db-init/10-run-openpim-init.sh`
- `/Users/romanshulgan/pim/db-init/20-grants.sh`
- `/Users/romanshulgan/pim/db-init/init.sql`
- `/Users/romanshulgan/pim/scripts/deploy-local.sh`
- `/Users/romanshulgan/pim/scripts/smoke-test.sh`
- `/Users/romanshulgan/pim/scripts/stop-local.sh`

---

## 3. Service Topology

```mermaid
flowchart LR
  Browser --> FE[frontend (nginx)]
  FE -->|/api/*| BE[backend (spring boot)]
  BE --> OP[openpim]
  OP --> DB[(postgres)]
  BE --> UP[(uploads volume in container)]
  OP --> FS[(filestorage bind mount)]
```

### Published host ports (default)

- frontend: `3000 -> 80`
- backend: `8080 -> 8080`
- openpim: `80 -> 80`
- postgres: `5432 -> 5432`

All published ports are configurable via `.env`.

---

## 4. Docker Compose: Detailed Explanation

## 4.1 `postgres` service

Purpose:

- provide base DB instance;
- execute SQL/bootstrap scripts from `db-init/` on first initialization.

Important settings:

- image: `postgres:15`
- bind mount: `./db-init:/docker-entrypoint-initdb.d`
- named volume: `postgres_data` for data persistence
- env:
  - `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` for superuser DB
  - `PIM_DB`, `PIM_ADMIN`, `PIM_ADMIN_PASSWORD` consumed by init scripts

Behavior note:

- `docker-entrypoint-initdb.d` scripts run only when database directory is empty.
- If volume already exists, changes in `db-init/` will not auto-apply.

## 4.2 `openpim` service

Purpose:

- run OpenPIM web app against PostgreSQL.

Important settings:

- image: `openpim/production:2.1`
- `platform: linux/amd64` for cross-architecture compatibility
- DB connection env points to `postgres` service
- filestorage bind mount from host (`FILE_STORAGE_PATH`)

Dependency:

- `depends_on: postgres`

## 4.3 `backend` service

Purpose:

- expose frontend-facing API;
- proxy/compose GraphQL calls to OpenPIM;
- handle file uploads.

Important settings:

- built from `pim-backend/Dockerfile`
- publishes `BACKEND_PORT`
- environment:
  - DB params (available if backend logic needs DB metadata)
  - `PIM_GRAPHQL_ENDPOINT=http://openpim/graphql`
  - `LOGIN`/`PASSWORD` for token acquisition in GraphQL client

Dependencies:

- `postgres`
- `openpim`

## 4.4 `frontend` service

Purpose:

- serve compiled React assets;
- route `/api` to backend to keep browser same-origin.

Important settings:

- built from `pim-frontend/pim-project/Dockerfile`
- publishes `FRONTEND_PORT`
- depends on `backend`

---

## 5. Frontend Deployment Code

## 5.1 Frontend Dockerfile (multi-stage)

Stage 1 (`node:20-alpine`):

1. copy `package*.json`
2. run `npm ci` (clean deterministic install)
3. copy source
4. run `npm run build` (generates `dist/`)

Stage 2 (`nginx:alpine`):

1. copy custom `nginx.conf`
2. copy `dist/` into `/usr/share/nginx/html`
3. expose port `80`
4. run nginx in foreground

Why this approach:

- smaller runtime image;
- no Node.js process in production container;
- static assets are immutable build artifacts.

## 5.2 Nginx config (`nginx.conf`)

### SPA routing

```nginx
location / {
  try_files $uri $uri/ /index.html;
}
```

This ensures React router/deep links work by always falling back to `index.html`.

### API proxy

```nginx
location /api/ {
  proxy_pass http://backend:8080/api/;
  ...headers...
}
```

Effects:

- browser calls `http://frontend-host/api/...`;
- nginx forwards to backend service in Docker network;
- no browser CORS issues;
- request metadata forwarded via standard proxy headers.

## 5.3 `.dockerignore`

Excludes heavy/unneeded context from frontend image build:

- `node_modules`
- `dist`
- `.git`
- npm debug logs

Result: faster builds and smaller build context transfer.

---

## 6. Backend Deployment Code

## 6.1 Backend Dockerfile

Stage 1 (`maven:3.9.6-eclipse-temurin-21`):

1. copy `pom.xml`
2. run dependency warmup (`mvn dependency:go-offline`)
3. copy `src`
4. run `mvn clean package -DskipTests`

Stage 2 (`eclipse-temurin:21-jdk-alpine`):

1. copy packaged jar
2. create `uploads` directory
3. expose `8080`
4. entrypoint: `java -jar app.jar`

Why this approach:

- reproducible Java runtime image;
- decoupled build/runtime environments;
- upload folder present by default.

---

## 7. Database Bootstrap Code (`db-init`)

Bootstrapping is split into idempotent shell scripts executed by Postgres entrypoint.

## 7.1 `00-create-role-and-db.sh`

Responsibilities:

- create or update role `${PIM_ADMIN}`;
- create database `${PIM_DB}` owned by `${PIM_ADMIN}` if it does not exist.

Important detail:

- database existence check is done via shell query;
- `CREATE DATABASE` runs outside transaction block.

## 7.2 `10-run-openpim-init.sh`

Responsibility:

- execute `init.sql` into `${PIM_DB}`.

This creates OpenPIM schema objects required by application image.

## 7.3 `20-grants.sh`

Responsibility:

- grant schema usage and table/sequence/function privileges to `${PIM_ADMIN}`;
- define default privileges for future objects.

## 7.4 `init.sql`

Contains full OpenPIM DB schema dump (tables, sequences, etc.).
This file is large and should be treated as generated infrastructure asset.

---

## 8. Environment Variables Reference

### 8.1 Required core variables

| Variable             | Meaning                          | Example           |
| -------------------- | -------------------------------- | ----------------- |
| `POSTGRES_USER`      | Postgres superuser name          | `postgres`        |
| `POSTGRES_PASSWORD`  | Postgres superuser password      | `postgres`        |
| `POSTGRES_DB`        | Initial DB for superuser session | `postgres`        |
| `PIM_DB`             | OpenPIM database name            | `pim_db`          |
| `PIM_ADMIN`          | OpenPIM DB role                  | `pim_admin`       |
| `PIM_ADMIN_PASSWORD` | OpenPIM DB role password         | `strong_password` |

### 8.2 Port mapping variables

| Variable        |    Host Port | Container Port |
| --------------- | -----------: | -------------: |
| `FRONTEND_PORT` | configurable |           `80` |
| `BACKEND_PORT`  | configurable |         `8080` |
| `OPENPIM_PORT`  | configurable |           `80` |
| `POSTGRES_PORT` | configurable |         `5432` |

### 8.3 Optional/auth variables

| Variable            | Used by | Purpose                    |
| ------------------- | ------- | -------------------------- |
| `OPENPIM_LOGIN`     | backend | GraphQL signIn login       |
| `OPENPIM_PASSWORD`  | backend | GraphQL signIn password    |
| `FILE_STORAGE_PATH` | openpim | Host path for file storage |

---

## 9. Deployment Procedures

## 9.1 First-time setup

1. Prepare env file:

```bash
cd /Users/romanshulgan/pim
cp .env.example .env
# edit .env
```

2. Build and start everything:

```bash
./scripts/deploy-local.sh
```

Equivalent raw commands:

```bash
docker compose config
docker compose up -d --build
docker compose ps
```

3. Run smoke checks:

```bash
./scripts/smoke-test.sh
```

## 9.2 Access URLs

- Frontend: `http://localhost:${FRONTEND_PORT}`
- Backend operations API: `http://localhost:${BACKEND_PORT}/api/graphql/operations`
- OpenPIM: `http://localhost:${OPENPIM_PORT}`

## 9.3 Stop stack

```bash
./scripts/stop-local.sh
```

Equivalent:

```bash
docker compose down
```

---

## 10. Update/Redeploy Workflow

Use when code changed and containers should refresh.

```bash
cd /Users/romanshulgan/pim
docker compose up -d --build
```

Service-specific rebuild examples:

```bash
# Frontend only
docker compose build frontend
docker compose up -d frontend

# Backend only
docker compose build backend
docker compose up -d backend
```

---

## 11. Health and Verification

## 11.1 Container status

```bash
docker compose ps
```

All services should be `Up`.

## 11.2 Endpoint checks

```bash
curl -fsS http://localhost:${FRONTEND_PORT}
curl -fsS http://localhost:${BACKEND_PORT}/api/graphql/operations
curl -fsS http://localhost:${OPENPIM_PORT}
```

## 11.3 Proxy path verification

Frontend endpoint should proxy backend API:

```bash
curl -fsS http://localhost:${FRONTEND_PORT}/api/graphql/operations
```

If this fails but direct backend endpoint works, inspect `nginx.conf` and frontend container logs.

---

## 12. Troubleshooting Runbook

## 12.1 Port already in use

Symptom:

- compose fails with `bind: address already in use`.

Fix:

1. change published port variable in `.env`;
2. restart stack.

Example:

```bash
BACKEND_PORT=18080
OPENPIM_PORT=8081
```

## 12.2 Backend restart loop on startup

Typical root causes:

- schema parse errors;
- wrong GraphQL endpoint;
- unreachable OpenPIM.

Checks:

```bash
docker compose logs --tail=200 backend
```

Look for:

- `Loaded X query and Y mutation operations from schema`
- any exception stack traces.

## 12.3 OpenPIM not reachable from backend

Checks:

- verify backend env `PIM_GRAPHQL_ENDPOINT=http://openpim/graphql`;
- verify openpim container is running;
- test from backend container if needed.

## 12.4 DB init scripts not re-running

Reason:

- existing `postgres_data` volume skips init scripts.

To reinitialize from scratch (destructive):

```bash
docker compose down -v
# then
docker compose up -d --build
```

Use only when safe to reset data.

---

## 13. Security and Production Hardening Checklist

Current setup is optimized for local/QA speed.
Before production use:

1. Replace all default passwords in `.env`.
2. Restrict exposed ports to required ones only.
3. Add TLS termination (reverse proxy or ingress).
4. Add secrets management (not plain `.env`).
5. Add healthchecks in compose and restart policies tuned for production.
6. Add backup/restore for `postgres_data` and filestorage.
7. Pin image digests for strict reproducibility.
8. Add log aggregation and alerting.

---

## 14. CI/CD Recommendations

Minimal pipeline:

1. frontend lint/build;
2. backend test/package;
3. docker build frontend/backend;
4. smoke test in ephemeral environment.

Suggested deploy strategy:

- immutable images tagged by commit SHA;
- environment-specific compose override files;
- staged rollout (dev -> staging -> production).

---

## 15. Fast Command Reference

```bash
# Full deploy
cd /Users/romanshulgan/pim && ./scripts/deploy-local.sh

# Health checks
cd /Users/romanshulgan/pim && ./scripts/smoke-test.sh

# Follow logs
cd /Users/romanshulgan/pim && docker compose logs -f backend frontend openpim postgres

# Rebuild specific service
cd /Users/romanshulgan/pim && docker compose up -d --build backend

# Shutdown
cd /Users/romanshulgan/pim && ./scripts/stop-local.sh
```
