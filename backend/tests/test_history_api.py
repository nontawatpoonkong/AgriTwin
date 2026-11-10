"""History API (BE-1): GET /api/v1/devices/{device_id}/readings. Requires TEST_DATABASE_URL (see conftest.py)."""

import json
from datetime import datetime, timezone
from itertools import count

import pytest

from app.contract import SENSOR_CATALOG
from conftest import TEST_DATABASE_URL

pytestmark = pytest.mark.skipif(not TEST_DATABASE_URL, reason="TEST_DATABASE_URL not set")

URL = "/api/v1/devices/node-01/readings"
_message_ids = count(1)


def send(db, ts: str, source: str = "simulator", device: str = "node-01", **values: float) -> None:
    """Ingest one contract-v1 message measured at `ts` with the given sensor values."""
    from app.ingest import ingest_message

    body = {
        "schema_version": "1.0",
        "message_id": f"history-{next(_message_ids)}",
        "device_id": device,
        "ts": ts,
        "source": source,
        "readings": [{"sensor_type": t, "value": v, "unit": SENSOR_CATALOG[t].unit} for t, v in values.items()],
    }
    result = ingest_message(db, f"agritwin/dev/devices/{device}/telemetry", json.dumps(body))
    assert result.outcome == "accepted", result.error


def at(text: str) -> datetime:
    return datetime.fromisoformat(text)


def values(client, **params) -> list[float]:
    response = client.get(URL, params=params)
    assert response.status_code == 200, response.text
    return [r["value"] for r in response.json()["readings"]]


def test_readings_come_back_oldest_first(db, client):
    for ts, value in [("2026-11-09T12:00:00Z", 30.0), ("2026-11-09T10:00:00Z", 10.0), ("2026-11-09T11:00:00Z", 20.0)]:
        send(db, ts, soil_moisture=value)

    body = client.get(URL, params={"sensor_type": "soil_moisture"}).json()

    assert [r["value"] for r in body["readings"]] == [10.0, 20.0, 30.0]
    assert [at(r["measured_at"]) for r in body["readings"]] == [
        datetime(2026, 11, 9, hour, tzinfo=timezone.utc) for hour in (10, 11, 12)
    ]
    assert body["device_id"] == "node-01" and body["sensor_type"] == "soil_moisture"
    assert body["count"] == 3 and body["truncated"] is False
    first = body["readings"][0]
    assert {k: first[k] for k in ("sensor_type", "value", "unit", "quality", "source")} == {
        "sensor_type": "soil_moisture",
        "value": 10.0,
        "unit": "%",
        "quality": "ok",
        "source": "simulator",
    }


def test_filters_by_sensor_type_and_never_mixes_devices(db, client):
    send(db, "2026-11-09T10:00:00Z", soil_moisture=40.0, air_temperature=28.0)
    send(db, "2026-11-09T11:00:00Z", soil_moisture=41.0, air_temperature=29.0)
    send(db, "2026-11-09T10:30:00Z", device="node-02", air_temperature=99.0)

    assert values(client, sensor_type="air_temperature") == [28.0, 29.0]

    everything = client.get(URL).json()
    assert everything["sensor_type"] is None
    assert sorted(r["value"] for r in everything["readings"]) == [28.0, 29.0, 40.0, 41.0]
    stamps = [at(r["measured_at"]) for r in everything["readings"]]
    assert stamps == sorted(stamps)


def test_time_range_includes_from_and_excludes_to(db, client):
    for hour in (10, 11, 12, 13):
        send(db, f"2026-11-09T{hour}:00:00Z", soil_moisture=float(hour))

    assert values(client, **{"from": "2026-11-09T11:00:00Z", "to": "2026-11-09T13:00:00Z"}) == [11.0, 12.0]
    assert values(client, **{"from": "2026-11-09T11:00:00Z"}) == [11.0, 12.0, 13.0]
    assert values(client, to="2026-11-09T11:00:00Z") == [10.0]


def test_range_accepts_utc_offsets_and_echoes_utc(db, client):
    for hour in (10, 11, 12):
        send(db, f"2026-11-09T{hour}:00:00Z", soil_moisture=float(hour))

    # 18:00+07:00 is 11:00Z; "+" has to be percent-encoded in a query string.
    body = client.get(f"{URL}?from=2026-11-09T18:00:00%2B07:00").json()

    assert [r["value"] for r in body["readings"]] == [11.0, 12.0]
    assert body["from"] == "2026-11-09T11:00:00Z"
    assert body["to"] is None


def test_limit_keeps_the_newest_readings_and_flags_truncation(db, client):
    for hour in (10, 11, 12, 13, 14):
        send(db, f"2026-11-09T{hour}:00:00Z", soil_moisture=float(hour))

    cut = client.get(URL, params={"limit": 2}).json()
    assert [r["value"] for r in cut["readings"]] == [13.0, 14.0]
    assert cut["limit"] == 2 and cut["count"] == 2 and cut["truncated"] is True

    # Paging back: the first returned time becomes the next request's exclusive `to`.
    older = client.get(URL, params={"limit": 2, "to": cut["readings"][0]["measured_at"]}).json()
    assert [r["value"] for r in older["readings"]] == [11.0, 12.0]
    assert older["truncated"] is True

    exact = client.get(URL, params={"limit": 5}).json()
    assert exact["count"] == 5 and exact["truncated"] is False


@pytest.mark.parametrize("limit, status", [(0, 422), (-1, 422), (5001, 422), (1, 200), (5000, 200)])
def test_limit_must_be_between_1_and_5000(db, client, limit, status):
    send(db, "2026-11-09T10:00:00Z", soil_moisture=40.0)
    assert client.get(URL, params={"limit": limit}).status_code == status


def test_default_limit_is_1000(db, client):
    send(db, "2026-11-09T10:00:00Z", soil_moisture=40.0)
    assert client.get(URL).json()["limit"] == 1000


@pytest.mark.parametrize(
    "params",
    [
        {"from": "2026-11-10T00:00:00Z"},  # nothing measured in that range
        {"sensor_type": "rainfall"},  # a catalog sensor this device never reported
    ],
)
def test_no_data_is_an_empty_list_not_an_error(db, client, params):
    send(db, "2026-11-09T10:00:00Z", soil_moisture=40.0)

    response = client.get(URL, params=params)

    assert response.status_code == 200
    body = response.json()
    assert body["readings"] == [] and body["count"] == 0 and body["truncated"] is False


def test_unknown_device_is_404(client):
    assert client.get("/api/v1/devices/nope/readings").status_code == 404


@pytest.mark.parametrize(
    "query",
    [
        "sensor_type=npk",  # not in the sensor catalog
        "from=2026-11-09T10:00:00",  # no timezone
        "to=2026-11-09T10:00:00",
        "from=2026-11-09T12:00:00Z&to=2026-11-09T12:00:00Z",  # empty window
        "from=2026-11-09T13:00:00Z&to=2026-11-09T12:00:00Z",  # reversed window
        "from=yesterday",  # not a timestamp
    ],
)
def test_bad_parameters_are_422(db, client, query):
    send(db, "2026-11-09T10:00:00Z", soil_moisture=40.0)
    assert client.get(f"{URL}?{query}").status_code == 422


def test_source_and_quality_are_kept_per_reading(db, client):
    send(db, "2026-11-09T10:00:00Z", source="gateway", soil_moisture=40.0)
    send(db, "2026-11-09T11:00:00Z", source="simulator", soil_moisture=140.0)  # out of range -> suspect

    readings = client.get(URL, params={"sensor_type": "soil_moisture"}).json()["readings"]

    assert [(r["source"], r["quality"]) for r in readings] == [("gateway", "ok"), ("simulator", "suspect")]
