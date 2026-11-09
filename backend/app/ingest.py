"""Validate and store one telemetry message. Transport-agnostic (used by the MQTT worker and tests)."""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from typing import Literal

from pydantic import ValidationError
from sqlalchemy import func
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from .contract import TelemetryV1, device_id_from_topic
from .models import Device, IngestReject, SensorReading, TelemetryMessage

log = logging.getLogger(__name__)

MAX_STORED_PAYLOAD_CHARS = 10_000

Outcome = Literal["accepted", "duplicate", "rejected"]


@dataclass
class IngestResult:
    outcome: Outcome
    message_id: str | None = None
    error: str | None = None


def _format_validation_error(exc: ValidationError) -> str:
    parts = []
    for err in exc.errors():
        loc = ".".join(str(p) for p in err["loc"]) or "(root)"
        parts.append(f"{loc}: {err['msg']}")
    return "; ".join(parts)


def _reject(session: Session, topic: str, raw_text: str, error: str) -> IngestResult:
    session.rollback()
    session.add(IngestReject(topic=topic, payload=raw_text[:MAX_STORED_PAYLOAD_CHARS], error=error))
    session.commit()
    log.warning("rejected message on %s: %s", topic, error)
    return IngestResult("rejected", error=error)


def ingest_message(session: Session, topic: str, payload: bytes | str) -> IngestResult:
    raw_text = payload.decode("utf-8", errors="replace") if isinstance(payload, bytes) else payload

    # 1) Parse + validate against contract v1
    try:
        data = json.loads(raw_text)
    except json.JSONDecodeError as exc:
        return _reject(session, topic, raw_text, f"invalid JSON: {exc.msg}")
    try:
        msg = TelemetryV1.model_validate(data)
    except ValidationError as exc:
        return _reject(session, topic, raw_text, _format_validation_error(exc))

    topic_device = device_id_from_topic(topic)
    if topic_device != msg.device_id:
        return _reject(
            session, topic, raw_text, f"device_id '{msg.device_id}' does not match topic device '{topic_device}'"
        )

    # 2) Store (idempotent on message_id)
    session.execute(
        insert(Device)
        .values(device_id=msg.device_id, last_source=msg.source)
        .on_conflict_do_nothing(index_elements=[Device.device_id])
    )
    message_pk = session.execute(
        insert(TelemetryMessage)
        .values(
            message_id=msg.message_id,
            device_id=msg.device_id,
            schema_version=msg.schema_version,
            source=msg.source,
            seq=msg.seq,
            measured_at=msg.ts,
            topic=topic,
            raw=data,
        )
        .on_conflict_do_nothing(index_elements=[TelemetryMessage.message_id])
        .returning(TelemetryMessage.id)
    ).scalar_one_or_none()

    if message_pk is None:
        session.rollback()
        log.info("duplicate message_id %s ignored", msg.message_id)
        return IngestResult("duplicate", message_id=msg.message_id)

    session.add_all(
        SensorReading(
            message_pk=message_pk,
            device_id=msg.device_id,
            sensor_type=r.sensor_type,
            value=r.value,
            unit=r.unit,
            quality=r.quality(),
            source=msg.source,
            measured_at=msg.ts,
        )
        for r in msg.readings
    )
    session.query(Device).filter(Device.device_id == msg.device_id).update(
        {Device.last_seen_at: func.now(), Device.last_source: msg.source}
    )
    session.commit()
    return IngestResult("accepted", message_id=msg.message_id)
