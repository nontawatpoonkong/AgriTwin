"""Integration tests: ingest -> PostgreSQL -> REST API. Requires TEST_DATABASE_URL (see conftest.py)."""

import json
from copy import deepcopy
from datetime import datetime, timedelta, timezone

import pytest
from alembic import command
from alembic.config import Config
from sqlalchemy import func, select, text, update

from conftest import BACKEND_DIR, REPO_DIR, TEST_DATABASE_URL

pytestmark = pytest.mark.skipif(not TEST_DATABASE_URL, reason="TEST_DATABASE_URL not set")

TOPIC = "agritwin/dev/devices/node-01/telemetry"


def alembic_cfg() -> Config:
    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
    cfg.attributes["database_url"] = TEST_DATABASE_URL
    return cfg


@pytest.fixture()
def db():
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


def payload(**overrides) -> str:
    data = json.loads((REPO_DIR / "contracts/examples/telemetry.valid.json").read_text(encoding="utf-8"))
    data.update(overrides)
    return json.dumps(data)


def count(db, model) -> int:
    return db.scalar(select(func.count()).select_from(model))


def test_migration_down_and_up_is_repeatable(db):
    cfg = alembic_cfg()
    db.rollback()  # release locks/snapshot held by the test session
    command.downgrade(cfg, "base")
    assert db.execute(text("SELECT to_regclass('sensor_readings')")).scalar() is None
    db.rollback()
    command.upgrade(cfg, "head")
    assert db.execute(text("SELECT to_regclass('sensor_readings')")).scalar() == "sensor_readings"


def test_accept_and_show_on_dashboard(db, client):
    from app.ingest import ingest_message

    assert ingest_message(db, TOPIC, payload().encode()).outcome == "accepted"

    body = client.get("/api/v1/dashboard/latest").json()
    assert len(body["devices"]) == 1
    device = body["devices"][0]
    assert device["device_id"] == "node-01"
    assert device["status"] == "online"
    assert device["last_source"] == "simulator"
    by_type = {r["sensor_type"]: r for r in device["readings"]}
    assert by_type["soil_moisture"]["value"] == 41.2
    assert by_type["soil_moisture"]["unit"] == "%"
    assert by_type["soil_moisture"]["quality"] == "ok"
    assert by_type["soil_moisture"]["source"] == "simulator"
    assert len(by_type) == 6


def test_duplicate_message_is_ignored(db):
    from app.ingest import ingest_message
    from app.models import SensorReading

    assert ingest_message(db, TOPIC, payload()).outcome == "accepted"
    assert ingest_message(db, TOPIC, payload()).outcome == "duplicate"
    assert count(db, SensorReading) == 6


@pytest.mark.parametrize(
    "topic, body",
    [
        (TOPIC, "not json"),
        (TOPIC, payload(schema_version="9.9")),
        ("agritwin/dev/devices/node-99/telemetry", payload()),  # topic/payload device mismatch
    ],
)
def test_rejected_messages_are_quarantined(db, client, topic, body):
    from app.ingest import ingest_message
    from app.models import IngestReject, SensorReading

    result = ingest_message(db, topic, body)
    assert result.outcome == "rejected" and result.error
    assert count(db, IngestReject) == 1
    assert count(db, SensorReading) == 0
    assert client.get("/api/v1/dashboard/latest").json()["devices"] == []


def test_out_of_order_message_does_not_override_latest(db, client):
    from app.ingest import ingest_message

    new = payload(message_id="m-new", ts="2026-11-09T13:00:00Z")
    old = json.loads(payload(message_id="m-old", ts="2026-11-09T12:00:00Z"))
    old["readings"] = [{"sensor_type": "soil_moisture", "value": 10.0, "unit": "%"}]
    assert ingest_message(db, TOPIC, new).outcome == "accepted"
    assert ingest_message(db, TOPIC, json.dumps(old)).outcome == "accepted"

    readings = client.get("/api/v1/devices/node-01/latest").json()["readings"]
    soil = next(r for r in readings if r["sensor_type"] == "soil_moisture")
    assert soil["value"] == 41.2


def test_suspect_value_is_stored_and_flagged(db, client):
    from app.ingest import ingest_message

    data = json.loads(payload())
    data["readings"] = [{"sensor_type": "soil_moisture", "value": 140.0, "unit": "%"}]
    assert ingest_message(db, TOPIC, json.dumps(data)).outcome == "accepted"
    reading = client.get("/api/v1/devices/node-01/latest").json()["readings"][0]
    assert reading["quality"] == "suspect"


def test_device_goes_offline(db, client):
    from app.ingest import ingest_message
    from app.models import Device

    ingest_message(db, TOPIC, payload())
    db.execute(update(Device).values(last_seen_at=datetime.now(timezone.utc) - timedelta(hours=1)))
    db.commit()
    assert client.get("/api/v1/devices").json()[0]["status"] == "offline"


def test_unknown_device_404(client):
    assert client.get("/api/v1/devices/nope/latest").status_code == 404


def test_health_reports_database_and_mqtt_disabled(client):
    body = client.get("/api/v1/health").json()
    assert body["database"] == "up"
    assert body["mqtt"] == "disabled"
    assert body["status"] == "ok"
