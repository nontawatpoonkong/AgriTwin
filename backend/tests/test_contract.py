import json
from datetime import datetime, timedelta, timezone

import pytest
from pydantic import ValidationError

from app.contract import TelemetryV1, device_id_from_topic, schema_json, telemetry_topic, write_schema
from conftest import REPO_DIR

EXAMPLES = REPO_DIR / "contracts" / "examples"


def load(name: str) -> dict:
    return json.loads((EXAMPLES / name).read_text(encoding="utf-8"))


def valid() -> dict:
    return load("telemetry.valid.json")


def test_valid_example_passes():
    msg = TelemetryV1.model_validate(valid())
    assert msg.device_id == "node-01"
    assert msg.ts.tzinfo is not None
    assert all(r.quality() == "ok" for r in msg.readings)


def test_invalid_unit_example_fails():
    with pytest.raises(ValidationError, match="unit"):
        TelemetryV1.model_validate(load("telemetry.invalid-unit.json"))


@pytest.mark.parametrize(
    "mutate, match",
    [
        (lambda d: d.update(schema_version="2.0"), "schema_version"),
        (lambda d: d.update(device_id="Node 01"), "device_id"),
        (lambda d: d.update(ts="2026-11-09T13:30:00"), "timezone"),
        (lambda d: d.update(source="excel"), "source"),
        (lambda d: d.update(readings=[]), "readings"),
        (lambda d: d.update(extra_field=1), "extra"),
        (lambda d: d["readings"].append({"sensor_type": "npk", "value": 1, "unit": "mg/kg"}), "unknown sensor_type"),
        (lambda d: d["readings"].append(dict(d["readings"][0])), "only once"),
        (lambda d: d["readings"][0].update(value="wet"), "value"),
    ],
)
def test_invalid_payloads(mutate, match):
    data = valid()
    mutate(data)
    with pytest.raises(ValidationError, match=match):
        TelemetryV1.model_validate(data)


def test_future_timestamp_rejected():
    data = valid()
    data["ts"] = (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()
    with pytest.raises(ValidationError, match="future"):
        TelemetryV1.model_validate(data)


def test_non_utc_offset_is_normalised_to_utc():
    data = valid()
    data["ts"] = "2026-11-09T20:00:00+07:00"
    assert TelemetryV1.model_validate(data).ts == datetime(2026, 11, 9, 13, 0, tzinfo=timezone.utc)


def test_out_of_range_value_is_suspect_not_rejected():
    data = valid()
    data["readings"] = [{"sensor_type": "soil_moisture", "value": 140, "unit": "%"}]
    assert TelemetryV1.model_validate(data).readings[0].quality() == "suspect"


def test_topic_helpers():
    topic = telemetry_topic("dev", "node-01")
    assert topic == "agritwin/dev/devices/node-01/telemetry"
    assert device_id_from_topic(topic) == "node-01"
    assert device_id_from_topic("agritwin/dev/devices/node-01/status") is None


def test_json_schema_file_is_up_to_date():
    """If this fails: cd backend && python -m app.contract --write"""
    on_disk = json.loads((REPO_DIR / "contracts" / "telemetry.v1.schema.json").read_text(encoding="utf-8"))
    assert on_disk == TelemetryV1.model_json_schema()


def test_write_schema_is_utf8_without_bom_and_lf(tmp_path):
    target = tmp_path / "schema.json"
    assert write_schema(target) is True
    raw = target.read_bytes()
    assert not raw.startswith(b"\xef\xbb\xbf")
    assert b"\r\n" not in raw
    assert json.loads(raw.decode("utf-8")) == TelemetryV1.model_json_schema()
    assert write_schema(target) is False  # unchanged content is left alone


def test_write_schema_repairs_file_saved_by_powershell_redirect(tmp_path):
    # Windows PowerShell 5.1 `>` saves UTF-16 with a BOM; json.loads cannot read that as UTF-8.
    target = tmp_path / "schema.json"
    target.write_text(schema_json(), encoding="utf-16")
    assert write_schema(target) is True
    assert json.loads(target.read_text(encoding="utf-8")) == TelemetryV1.model_json_schema()
