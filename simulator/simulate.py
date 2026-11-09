"""AgriTwin sensor simulator: publishes contract-v1 telemetry to MQTT, like a Home Gateway would.

Every message is marked source="simulator" so the app can label it as simulated data.

Examples:
  python simulate.py                          # 2 devices, every 10 s, forever
  python simulate.py --devices 3 --interval 5
  python simulate.py --count 1                # one message per device, then exit
  python simulate.py --bad                    # also send 1 malformed message per round (tests quarantine)
  python simulate.py --duplicate              # re-send each message once (tests idempotency)
"""

from __future__ import annotations

import argparse
import json
import random
import time
import uuid
from datetime import datetime, timezone

import paho.mqtt.client as mqtt

# Mirrors backend/app/contract.py SENSOR_CATALOG (kept separate so this script can run on a gateway
# machine without the backend code). name: (unit, start, min, max, max_step)
SENSORS = {
    "soil_moisture": ("%", 45.0, 15.0, 85.0, 1.5),
    "soil_temperature": ("°C", 27.0, 20.0, 38.0, 0.3),
    "air_temperature": ("°C", 30.0, 18.0, 40.0, 0.5),
    "air_humidity": ("%RH", 70.0, 35.0, 98.0, 2.0),
    "rainfall": ("mm", 0.0, 0.0, 20.0, 0.0),
    "wind_speed": ("m/s", 2.0, 0.0, 12.0, 0.8),
}


class FakeNode:
    def __init__(self, device_id: str, rng: random.Random):
        self.device_id = device_id
        self.rng = rng
        self.seq = 0
        self.state = {name: spec[1] + rng.uniform(-3, 3) for name, spec in SENSORS.items()}

    def next_payload(self) -> dict:
        readings = []
        for name, (unit, _start, lo, hi, step) in SENSORS.items():
            if name == "rainfall":  # rain since last message: mostly 0, sometimes a shower
                value = round(self.rng.uniform(0.2, 5.0), 1) if self.rng.random() < 0.08 else 0.0
            else:
                value = min(hi, max(lo, self.state[name] + self.rng.uniform(-step, step)))
                self.state[name] = value
            readings.append({"sensor_type": name, "value": round(value, 1), "unit": unit})
        self.seq += 1
        return {
            "schema_version": "1.0",
            "message_id": str(uuid.uuid4()),
            "device_id": self.device_id,
            "seq": self.seq,
            "ts": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
            "source": "simulator",
            "readings": readings,
        }


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--host", default="localhost")
    ap.add_argument("--port", type=int, default=1883)
    ap.add_argument("--env", default="dev", help="topic env segment (default: dev)")
    ap.add_argument("--devices", type=int, default=2)
    ap.add_argument("--interval", type=float, default=10.0, help="seconds between rounds")
    ap.add_argument("--count", type=int, default=0, help="rounds to send, 0 = forever")
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--bad", action="store_true", help="also publish one invalid message per round")
    ap.add_argument("--duplicate", action="store_true", help="publish every message twice")
    args = ap.parse_args()

    rng = random.Random(args.seed)
    nodes = [FakeNode(f"sim-node-{i + 1:02d}", rng) for i in range(args.devices)]

    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=f"agritwin-sim-{uuid.uuid4().hex[:6]}")
    client.connect(args.host, args.port, keepalive=30)
    client.loop_start()
    print(f"connected to mqtt://{args.host}:{args.port}  (Ctrl+C to stop)")

    rounds = 0
    try:
        while True:
            for node in nodes:
                payload = node.next_payload()
                topic = f"agritwin/{args.env}/devices/{node.device_id}/telemetry"
                body = json.dumps(payload, ensure_ascii=False)
                client.publish(topic, body, qos=1).wait_for_publish(timeout=5)
                if args.duplicate:
                    client.publish(topic, body, qos=1).wait_for_publish(timeout=5)
                soil = next(r["value"] for r in payload["readings"] if r["sensor_type"] == "soil_moisture")
                print(f"{payload['ts']}  {topic}  seq={payload['seq']}  soil_moisture={soil}%")
            if args.bad:
                topic = f"agritwin/{args.env}/devices/{nodes[0].device_id}/telemetry"
                bad = {"schema_version": "1.0", "device_id": nodes[0].device_id, "readings": "oops"}
                client.publish(topic, json.dumps(bad), qos=1).wait_for_publish(timeout=5)
                print(f"sent 1 INVALID message to {topic} (should land in ingest_rejects)")
            rounds += 1
            if args.count and rounds >= args.count:
                break
            time.sleep(args.interval)
    except KeyboardInterrupt:
        pass
    finally:
        client.loop_stop()
        client.disconnect()


if __name__ == "__main__":
    main()
