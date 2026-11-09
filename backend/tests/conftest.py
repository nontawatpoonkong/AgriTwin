"""Test setup.

Contract tests need nothing. Integration tests need a *disposable* PostgreSQL database given by
TEST_DATABASE_URL (env var or backend/.env). They are skipped when it is not set.
WARNING: integration tests drop and recreate all tables in that database.
"""

import os
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parents[1]
REPO_DIR = BACKEND_DIR.parent


def _read_dotenv_value(key: str) -> str | None:
    env_file = BACKEND_DIR / ".env"
    if not env_file.exists():
        return None
    for line in env_file.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith(f"{key}="):
            return line.split("=", 1)[1].strip()
    return None


TEST_DATABASE_URL = os.environ.get("TEST_DATABASE_URL") or _read_dotenv_value("TEST_DATABASE_URL")

# Must happen before app modules create cached settings/engines.
if TEST_DATABASE_URL:
    os.environ["DATABASE_URL"] = TEST_DATABASE_URL
os.environ["MQTT_ENABLED"] = "false"
