"""REST API v1 used by the Flutter app. Contract documented in docs/DATA_CONTRACT.md."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import distinct_on
from sqlalchemy.orm import Session

from .config import get_settings
from .db import db_ok, get_session
from .models import Device, SensorReading

router = APIRouter(prefix="/api/v1")


# ---------- response models ----------
class HealthOut(BaseModel):
    status: Literal["ok", "degraded"]
    database: Literal["up", "down"]
    mqtt: Literal["connected", "disconnected", "disabled"]
    ingest_counts: dict[str, int]
    server_time: datetime


class LatestReadingOut(BaseModel):
    sensor_type: str
    value: float
    unit: str
    quality: Literal["ok", "suspect"]
    source: str
    measured_at: datetime


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
