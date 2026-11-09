"""Telemetry data contract v1.0 (MQTT payload).

This module is the single source of truth for the telemetry payload.
Docs: docs/DATA_CONTRACT.md. JSON Schema: contracts/telemetry.v1.schema.json
(regenerate with: python -m app.contract > ../contracts/telemetry.v1.schema.json)
"""

from __future__ import annotations

import json
import math
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

SCHEMA_VERSION = "1.0"

# Max allowed clock skew into the future. Older timestamps are accepted
# (the gateway may flush a queue after a network outage).
MAX_FUTURE_SKEW = timedelta(minutes=5)

DEVICE_ID_PATTERN = r"^[a-z0-9][a-z0-9_-]{1,63}$"


@dataclass(frozen=True)
class SensorSpec:
    unit: str
    plausible_min: float
    plausible_max: float


# Sensor catalog v1. One fixed unit per sensor type; the server rejects any other unit.
# Values outside the plausible range are stored with quality="suspect" (not rejected).
SENSOR_CATALOG: dict[str, SensorSpec] = {
    "air_temperature": SensorSpec("°C", -10, 60),
    "air_humidity": SensorSpec("%RH", 0, 100),
    "soil_temperature": SensorSpec("°C", -10, 70),
    "soil_moisture": SensorSpec("%", 0, 100),
    "rainfall": SensorSpec("mm", 0, 500),
    "wind_speed": SensorSpec("m/s", 0, 60),
}

Source = Literal["simulator", "gateway", "test"]
Quality = Literal["ok", "suspect"]


class Reading(BaseModel):
    model_config = ConfigDict(extra="forbid")

    sensor_type: str = Field(description="Key from the sensor catalog, e.g. soil_moisture")
    value: float
    unit: str

    @field_validator("value")
    @classmethod
    def _finite(cls, v: float) -> float:
        if not math.isfinite(v):
            raise ValueError("value must be a finite number")
        return v

    @model_validator(mode="after")
    def _check_catalog(self) -> "Reading":
        spec = SENSOR_CATALOG.get(self.sensor_type)
        if spec is None:
            raise ValueError(
                f"unknown sensor_type '{self.sensor_type}'; allowed: {sorted(SENSOR_CATALOG)}"
            )
        if self.unit != spec.unit:
            raise ValueError(
                f"unit '{self.unit}' not allowed for {self.sensor_type}; expected '{spec.unit}'"
            )
        return self

    def quality(self) -> Quality:
        spec = SENSOR_CATALOG[self.sensor_type]
        return "ok" if spec.plausible_min <= self.value <= spec.plausible_max else "suspect"


class TelemetryV1(BaseModel):
    """Payload published to agritwin/{env}/devices/{device_id}/telemetry."""

    model_config = ConfigDict(extra="forbid")

    schema_version: Literal["1.0"]
    message_id: str = Field(min_length=1, max_length=128, description="Idempotency key, unique per message")
    device_id: str = Field(pattern=DEVICE_ID_PATTERN)
    seq: int | None = Field(default=None, ge=0, description="Node frame counter, optional")
    ts: datetime = Field(description="Measurement time, ISO 8601 with timezone (UTC recommended)")
    source: Source
    readings: list[Reading] = Field(min_length=1, max_length=32)

    @field_validator("ts")
    @classmethod
    def _aware_and_not_future(cls, v: datetime) -> datetime:
        if v.tzinfo is None or v.utcoffset() is None:
            raise ValueError("ts must include a timezone, e.g. 2026-11-09T13:30:00Z")
        if v - datetime.now(timezone.utc) > MAX_FUTURE_SKEW:
            raise ValueError("ts is more than 5 minutes in the future (check device/gateway clock)")
        return v.astimezone(timezone.utc)

    @model_validator(mode="after")
    def _unique_sensor_types(self) -> "TelemetryV1":
        types = [r.sensor_type for r in self.readings]
        if len(types) != len(set(types)):
            raise ValueError("each sensor_type may appear only once per message")
        return self


def telemetry_topic(env: str, device_id: str) -> str:
    return f"agritwin/{env}/devices/{device_id}/telemetry"


def telemetry_subscription(env: str) -> str:
    return f"agritwin/{env}/devices/+/telemetry"


def device_id_from_topic(topic: str) -> str | None:
    parts = topic.split("/")
    if len(parts) == 5 and parts[0] == "agritwin" and parts[2] == "devices" and parts[4] == "telemetry":
        return parts[3]
    return None


if __name__ == "__main__":
    print(json.dumps(TelemetryV1.model_json_schema(), indent=2, ensure_ascii=False))
