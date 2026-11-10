"""Test setup.

Contract tests need nothing. Integration tests need a *disposable* PostgreSQL database given by
TEST_DATABASE_URL (env var or backend/.env). They are skipped when it is not set.
WARNING: integration tests drop and recreate all tables in that database, so the run stops unless
the database name ends with "_test" and differs from the one in DATABASE_URL.
"""

import os
from pathlib import Path

import pytest
from sqlalchemy.engine import make_url

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


def unsafe_test_database_reason(test_url: str | None, dev_url: str | None) -> str | None:
    """Why ``test_url`` must not be used by the destructive integration tests (None when it is safe)."""
    if not test_url:
        return None
    name = make_url(test_url).database or ""
    if not name.endswith("_test"):
        return f"TEST_DATABASE_URL points at database '{name}', whose name does not end with '_test'"
    if dev_url and make_url(dev_url).database == name:
        return f"TEST_DATABASE_URL and DATABASE_URL both point at database '{name}'"
    return None


TEST_DATABASE_URL = os.environ.get("TEST_DATABASE_URL") or _read_dotenv_value("TEST_DATABASE_URL")
_UNSAFE_REASON = unsafe_test_database_reason(
    TEST_DATABASE_URL, os.environ.get("DATABASE_URL") or _read_dotenv_value("DATABASE_URL")
)

# Must happen before app modules create cached settings/engines.
if TEST_DATABASE_URL:
    os.environ["DATABASE_URL"] = TEST_DATABASE_URL
os.environ["MQTT_ENABLED"] = "false"


def pytest_configure(config):
    if _UNSAFE_REASON:
        raise pytest.UsageError(f"{_UNSAFE_REASON}. Integration tests drop every table, so the run stops here.")


def pytest_report_header(config):
    if not TEST_DATABASE_URL:
        return "integration tests: skipped (TEST_DATABASE_URL not set)"
    url = make_url(TEST_DATABASE_URL)
    return f"integration test database: {url.database} @ {url.host}:{url.port}"


def alembic_cfg():
    from alembic.config import Config

    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
    cfg.attributes["database_url"] = TEST_DATABASE_URL
    return cfg


@pytest.fixture()
def db():
    """A fresh schema in the test database for every test (all tables are dropped first)."""
    from alembic import command

    from app.db import get_sessionmaker

    cfg = alembic_cfg()
    command.downgrade(cfg, "base")
    command.upgrade(cfg, "head")
    with get_sessionmaker()() as session:
        yield session


@pytest.fixture()
def client(db):
    from fastapi.testclient import TestClient

    from app.main import create_app

    with TestClient(create_app()) as c:
        yield c
