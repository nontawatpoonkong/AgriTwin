"""End-to-end smoke test: MQTT -> FastAPI ingest -> PostgreSQL -> REST API.

Prerequisites: docker compose services up, migrations applied, API running.
Run from backend/:  python scripts/smoke_test.py
Exit code 0 = pass.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timezone

import paho.mqtt.client as mqtt


def get_json(url: str):
    with urllib.request.urlopen(url, timeout=5) as resp:
        return json.loads(resp.read().decode("utf-8"))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--api", default="http://localhost:8000")
    ap.add_argument("--mqtt-host", default="localhost")
    ap.add_argument("--mqtt-port", type=int, default=1883)
    ap.add_argument("--env", default="dev")
    args = ap.parse_args()

    health = get_json(f"{args.api}/api/v1/health")
    print("health:", health)
    if health["database"] != "up" or health["mqtt"] != "connected":
        print("FAIL: API is not connected to both PostgreSQL and MQTT")
        return 1

    device_id = "smoke-test-node"
    marker = round(10 + (uuid.uuid4().int % 800) / 10, 1)  # unique-ish value to look for
    payload = {
        "schema_version": "1.0",
        "message_id": f"smoke-{uuid.uuid4()}",
        "device_id": device_id,
        "seq": 1,
        "ts": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
        "source": "test",
        "readings": [{"sensor_type": "soil_moisture", "value": marker, "unit": "%"}],
    }
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    client.connect(args.mqtt_host, args.mqtt_port)
    client.loop_start()
    topic = f"agritwin/{args.env}/devices/{device_id}/telemetry"
    client.publish(topic, json.dumps(payload), qos=1).wait_for_publish(timeout=5)
    client.loop_stop()
    client.disconnect()
    print(f"published soil_moisture={marker} to {topic}")

    for _ in range(20):
        time.sleep(0.5)
        try:
            latest = get_json(f"{args.api}/api/v1/devices/{device_id}/latest")
        except urllib.error.HTTPError:
            continue
        values = [r["value"] for r in latest["readings"] if r["sensor_type"] == "soil_moisture"]
        if values and values[0] == marker:
            print("PASS: value travelled MQTT -> API -> PostgreSQL -> REST")
            return 0
    print("FAIL: value did not appear in /api/v1/devices/{id}/latest within 10 s")
    return 1


if __name__ == "__main__":
    sys.exit(main())
