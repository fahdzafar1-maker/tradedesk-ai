# TradeDesk AI - Dashboard API

FastAPI service that reads the TradeDesk Postgres database and renders the
owner-facing report. Read-only: it never writes.

## Deploy on Railway

1. Push this folder to GitHub.
2. Railway project -> Create -> GitHub Repo -> pick the repo, set root to `api/`.
3. Add variables:
   - `DATABASE_URL` - reference the pgvector service's own `DATABASE_URL`
   - `DASHBOARD_TOKEN` - any long random string (leave unset only for a local demo)
4. Start command: `uvicorn main:app --host 0.0.0.0 --port $PORT`

## Endpoints

| Route | Purpose |
|---|---|
| `GET /` | the dashboard page |
| `GET /api/summary?business_id=&days=&token=` | JSON behind the page |
| `GET /health` | liveness check |
| `GET /docs` | auto-generated OpenAPI docs |

Open the dashboard with:
`/?business_id=11111111-1111-1111-1111-111111111111&token=YOUR_TOKEN`

## Run locally

```
pip install -r requirements.txt
export DATABASE_URL="postgresql://..."
uvicorn main:app --reload
```
