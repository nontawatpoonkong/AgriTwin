# AGENTS.md — rules for AI coding tools (Codex, Claude, etc.)

AgriTwin: IoT multi-plot farm monitoring, university research prototype. One developer.
Stack (fixed): Flutter · FastAPI · PostgreSQL · MQTT (Mosquitto) · Home Gateway (LoRa, later).
Owner reads Thai best; write user-facing text and docs in Thai, code/comments/identifiers in English.

## Read first
- `docs/ARCHITECTURE.md` — data flow and decisions (do not re-architect without a task asking for it)
- `docs/DATA_CONTRACT.md` — MQTT payload v1 + REST API
- `docs/NEXT_TASKS.md` — pick tasks by ID; tick them off when done

## Layout
- `backend/app/contract.py` — single source of truth for the telemetry payload + sensor catalog
- `backend/app/ingest.py` — validate/store one message (transport-agnostic)
- `backend/app/mqtt_worker.py` — paho-mqtt subscriber inside the FastAPI process
- `backend/app/api.py` — REST `/api/v1/...`
- `backend/migrations/versions/` — Alembic migrations
- `simulator/simulate.py` — fake devices; `backend/scripts/smoke_test.py` — end-to-end check
- `app/lib/` — Flutter: `core/` (config, tokens, catalog), `data/` (models, API client), `features/<name>/`

## Commands (Windows PowerShell, from repo root)
```
copy infra\.env.example infra\.env; copy backend\.env.example backend\.env   # first time, then set passwords
docker compose -f infra/docker-compose.yml up -d
cd backend; .\.venv\Scripts\Activate.ps1; alembic upgrade head; uvicorn app.main:app --reload --port 8000
cd backend; pytest -v                      # needs TEST_DATABASE_URL in backend/.env
cd backend; python scripts/smoke_test.py   # API must be running
cd app; flutter analyze; flutter test
```

## Hard rules
1. **Scope:** do NOT add Camera/360, NPK/pH/EC/BLE, AI Insight or 3D unless the task explicitly asks.
2. **Contract changes:** edit `contract.py` → regenerate `contracts/telemetry.v1.schema.json`
   (`cd backend; python -m app.contract > ../contracts/telemetry.v1.schema.json`) → update
   `docs/DATA_CONTRACT.md` → update `app/lib/core/sensor_catalog.dart` and Flutter models. Follow the
   versioning rules in DATA_CONTRACT.md §6. Never break existing v1.0 senders silently.
3. **Database:** every schema change is a new Alembic revision with a working `downgrade()`. Never edit a
   migration that has already been applied. Update `models.py` to match.
4. **Real vs simulated data:** keep `source` end-to-end; the app must keep labelling non-`gateway` data as
   "ข้อมูลจำลอง". Never present simulated values as field results.
5. **Bad data:** invalid messages go to `ingest_rejects`, never into `sensor_readings`.
6. **UI styling:** colours/spacing/radii/type sizes live only in `app/lib/core/theme/tokens.dart`.
   Current values are placeholders. Do not claim a design matches Kaset App without reference images
   from the owner.
7. **Flutter screens** must handle loading, empty, error and stale/offline states.
8. **Secrets:** never commit `.env` files or passwords (`infra/.env`, `backend/.env` are git-ignored). Add new
   settings to `config.py` + the matching `.env.example` with placeholder values only.
9. **Dependencies:** prefer none. Ask/justify before adding a package; pin backend versions in requirements.

## Definition of Done (from the team's Sprint plan)
- Tests added/updated and passing: `pytest` (backend) and `flutter analyze` + `flutter test` (app)
- Migrations run up and down on a fresh database
- API/MQTT/schema docs updated when an interface changes
- Known issues and limitations written down in `docs/NEXT_TASKS.md`
