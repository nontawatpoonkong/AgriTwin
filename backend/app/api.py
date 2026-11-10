"""REST API v1 used by the Flutter app. Contract documented in docs/DATA_CONTRACT.md."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import distinct_on
from sqlalchemy.orm import Session

from .config import get_settings
from .contract import SENSOR_CATALOG
from .db import db_ok, get_session
from .models import Device, SensorReading

router = APIRouter(prefix="/api/v1")

HISTORY_DEFAULT_LIMIT = 1000
HISTORY_MAX_LIMIT = 5000


# ---------- response models ----------
class HealthOut(BaseModel):
    status: Literal["ok", "degraded"]
    database: Literal["up", "down"]
    mqtt: Literal["connected", "disconnected", "disabled"]
    ingest_counts: dict[str, int]
    server_time: datetime


class ReadingOut(BaseModel):
    sensor_type: str
    value: float
    unit: str
    quality: Literal["ok", "suspect"]
    source: str
    measured_at: datetime


class LatestReadingOut(ReadingOut):
    """Latest value of one sensor type."""


class ReadingHistoryOut(BaseModel):
    device_id: str
    sensor_type: str | None
    from_: datetime | None = Field(serialization_alias="from")
    to: datetime | None
    limit: int
    count: int
    truncated: bool
    readings: list[ReadingOut]


class DeviceOut(BaseModel):
    device_id: str
    display_name: str | None
    status: Literal["online", "offline"]
    last_seen_at: datetime
    last_source: str


class DeviceLatestOut(DeviceOut):
    readings: list[LatestReadingOut]


class DashboardLatestOut(BaseModel):
    server_time: datetime
    offline_after_seconds: int
    devices: list[DeviceLatestOut]


# ---------- helpers ----------
def _device_out(d: Device, now: datetime) -> dict:
    limit = timedelta(seconds=get_settings().device_offline_after_seconds)
    return {
        "device_id": d.device_id,
        "display_name": d.display_name,
        "status": "online" if now - d.last_seen_at <= limit else "offline",
        "last_seen_at": d.last_seen_at,
        "last_source": d.last_source,
    }


def _latest_readings(session: Session, device_id: str | None = None) -> dict[str, list[LatestReadingOut]]:
    """Latest value per (device, sensor_type) by measurement time, so late/out-of-order
    messages from a gateway queue never overwrite newer values."""
    stmt = (
        select(SensorReading)
        .ext(distinct_on(SensorReading.device_id, SensorReading.sensor_type))
        .order_by(
            SensorReading.device_id,
            SensorReading.sensor_type,
            SensorReading.measured_at.desc(),
            SensorReading.id.desc(),
        )
    )
    if device_id is not None:
        stmt = stmt.where(SensorReading.device_id == device_id)
    out: dict[str, list[LatestReadingOut]] = {}
    for r in session.scalars(stmt):
        out.setdefault(r.device_id, []).append(LatestReadingOut.model_validate(r, from_attributes=True))
    return out


# ---------- endpoints ----------
@router.get("/health", response_model=HealthOut)
def health(request: Request) -> HealthOut:
    worker = getattr(request.app.state, "mqtt_worker", None)
    if worker is None:
        mqtt_state, counts = "disabled", {}
    else:
        mqtt_state = "connected" if worker.connected.is_set() else "disconnected"
        counts = dict(worker.counts)
    database = "up" if db_ok() else "down"
    ok = database == "up" and mqtt_state != "disconnected"
    return HealthOut(
        status="ok" if ok else "degraded",
        database=database,
        mqtt=mqtt_state,
        ingest_counts=counts,
        server_time=datetime.now(timezone.utc),
    )


@router.get("/devices", response_model=list[DeviceOut])
def list_devices(session: Session = Depends(get_session)):
    now = datetime.now(timezone.utc)
    devices = session.scalars(select(Device).order_by(Device.device_id))
    return [_device_out(d, now) for d in devices]


@router.get("/devices/{device_id}/latest", response_model=DeviceLatestOut)
def device_latest(device_id: str, session: Session = Depends(get_session)):
    device = session.get(Device, device_id)
    if device is None:
        raise HTTPException(status_code=404, detail=f"device '{device_id}' not found")
    now = datetime.now(timezone.utc)
    readings = _latest_readings(session, device_id).get(device_id, [])
    return {**_device_out(device, now), "readings": readings}


@router.get("/devices/{device_id}/readings", response_model=ReadingHistoryOut)
def device_readings(
    device_id: str,
    sensor_type: str | None = Query(None, description="Sensor type from the catalog, e.g. soil_moisture"),
    from_: datetime | None = Query(
        None, alias="from", description="Inclusive lower bound on measured_at, ISO 8601 with timezone"
    ),
    to: datetime | None = Query(None, description="Exclusive upper bound on measured_at, ISO 8601 with timezone"),
    limit: int = Query(HISTORY_DEFAULT_LIMIT, ge=1, le=HISTORY_MAX_LIMIT),
    session: Session = Depends(get_session),
):
    """Readings of one device, oldest first.

    When more than `limit` readings match, the newest `limit` of them are returned and `truncated`
    is true; older ones can be fetched by passing the first returned `measured_at` as `to`.
    """
    if sensor_type is not None and sensor_type not in SENSOR_CATALOG:
        raise HTTPException(
            status_code=422, detail=f"unknown sensor_type '{sensor_type}'; allowed: {sorted(SENSOR_CATALOG)}"
        )
    for name, value in (("from", from_), ("to", to)):
        if value is not None and value.utcoffset() is None:
            raise HTTPException(
                status_code=422, detail=f"'{name}' must include a timezone, e.g. 2026-11-09T13:00:00Z"
            )
    if from_ is not None and to is not None and from_ >= to:
        raise HTTPException(status_code=422, detail="'from' must be earlier than 'to'")
    if session.get(Device, device_id) is None:
        raise HTTPException(status_code=404, detail=f"device '{device_id}' not found")

    stmt = select(SensorReading).where(SensorReading.device_id == device_id)
    if sensor_type is not None:
        stmt = stmt.where(SensorReading.sensor_type == sensor_type)
    if from_ is not None:
        stmt = stmt.where(SensorReading.measured_at >= from_)
    if to is not None:
        stmt = stmt.where(SensorReading.measured_at < to)
    # Newest first so a cut keeps the most recent part of the range; flipped to oldest first below.
    stmt = stmt.order_by(SensorReading.measured_at.desc(), SensorReading.id.desc()).limit(limit + 1)
    rows = list(session.scalars(stmt))
    readings = [ReadingOut.model_validate(r, from_attributes=True) for r in reversed(rows[:limit])]
    return ReadingHistoryOut(
        device_id=device_id,
        sensor_type=sensor_type,
        from_=from_.astimezone(timezone.utc) if from_ else None,
        to=to.astimezone(timezone.utc) if to else None,
        limit=limit,
        count=len(readings),
        truncated=len(rows) > limit,
        readings=readings,
    )


@router.get("/dashboard/latest", response_model=DashboardLatestOut)
def dashboard_latest(session: Session = Depends(get_session)):
    """Everything the dashboard needs in one call."""
    now = datetime.now(timezone.utc)
    latest = _latest_readings(session)
    devices = session.scalars(select(Device).order_by(Device.device_id))
    return {
        "server_time": now,
        "offline_after_seconds": get_settings().device_offline_after_seconds,
        "devices": [{**_device_out(d, now), "readings": latest.get(d.device_id, [])} for d in devices],
    }
