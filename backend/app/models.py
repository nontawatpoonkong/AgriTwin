"""ORM models. Schema changes must go through an Alembic migration in migrations/versions."""

from datetime import datetime

from sqlalchemy import BigInteger, CheckConstraint, DateTime, Float, ForeignKey, Index, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class Device(Base):
    """Auto-registered on first valid message. Farm/plot assignment comes in Sprint 3."""

    __tablename__ = "devices"

    device_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    display_name: Mapped[str | None] = mapped_column(String(128))
    first_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    last_source: Mapped[str] = mapped_column(String(16))


class TelemetryMessage(Base):
    """One accepted MQTT message (provenance + raw payload)."""

    __tablename__ = "telemetry_messages"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    message_id: Mapped[str] = mapped_column(String(128), unique=True)
    device_id: Mapped[str] = mapped_column(ForeignKey("devices.device_id"))
    schema_version: Mapped[str] = mapped_column(String(8))
    source: Mapped[str] = mapped_column(String(16))
    seq: Mapped[int | None] = mapped_column(Integer)
    measured_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    received_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    topic: Mapped[str] = mapped_column(Text)
    raw: Mapped[dict] = mapped_column(JSONB)


class SensorReading(Base):
    __tablename__ = "sensor_readings"
    __table_args__ = (
        CheckConstraint("quality IN ('ok', 'suspect')", name="ck_sensor_readings_quality"),
        Index("ix_sensor_readings_latest", "device_id", "sensor_type", "measured_at"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    message_pk: Mapped[int] = mapped_column(ForeignKey("telemetry_messages.id", ondelete="CASCADE"))
    device_id: Mapped[str] = mapped_column(ForeignKey("devices.device_id"))
    sensor_type: Mapped[str] = mapped_column(String(32))
    value: Mapped[float] = mapped_column(Float)
    unit: Mapped[str] = mapped_column(String(16))
    quality: Mapped[str] = mapped_column(String(16))
    source: Mapped[str] = mapped_column(String(16))
    measured_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class IngestReject(Base):
    """Quarantine: messages that failed validation. Never shown on the dashboard."""

    __tablename__ = "ingest_rejects"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    received_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    topic: Mapped[str] = mapped_column(Text)
    payload: Mapped[str] = mapped_column(Text)
    error: Mapped[str] = mapped_column(Text)
