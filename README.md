# PIM Workspace Documentation

This workspace contains a full Product Information Management stack:
- `pim-frontend`: React + Vite + Nginx frontend (`PIM Console`)
- `pim-backend`: Spring Boot API gateway for file upload, dynamic GraphQL execution, and Excel import execution
- `openpim`: OpenPIM application container
- `postgres`: PostgreSQL database initialized by `db-init/`

The project is documented in detail to support fast onboarding and fast iteration.

## Documentation Index

1. [Code & Architecture Guide](./docs/CODE_AND_ARCHITECTURE_GUIDE.md)
2. [Deployment Guide](./docs/DEPLOYMENT_GUIDE.md)
3. [Excel Import Guide](./docs/EXCEL_IMPORT_GUIDE.md)
4. [Environment Template](./.env.example)

## Quick Start (Docker)

```bash
cd /Users/romanshulgan/pim
cp .env.example .env
# edit .env values for your environment

docker compose up -d --build
```

Then open:
- Frontend: `http://localhost:${FRONTEND_PORT:-3000}`
- Backend API: `http://localhost:${BACKEND_PORT:-8080}`
- OpenPIM: `http://localhost:${OPENPIM_PORT:-80}`

## Useful Scripts

- `./scripts/deploy-local.sh`: build and start all services
- `./scripts/smoke-test.sh`: check frontend and backend API health
- `./scripts/stop-local.sh`: stop and remove stack
