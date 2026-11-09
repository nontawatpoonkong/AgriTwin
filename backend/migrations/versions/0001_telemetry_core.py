"""telemetry core: devices, telemetry_messages, sensor_readings, ingest_rejects

Revision ID: 0001
Revises:
Create Date: 2026-11-09
"""
import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "devices",
        sa.Column("device_id", sa.String(64), primary_key=True),
        sa.Column("display_name", sa.String(128)),
        sa.Column("first_seen_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("last_source", sa.String(16), nullable=False),
    )
    op.create_table(
        "telemetry_messages",
        sa.Column("id", sa.BigInteger, primary_key=True, autoincrement=True),
        sa.Column("message_id", sa.String(128), nullable=False, unique=True),
        sa.Column("device_id", sa.String(64), sa.ForeignKey("devices.device_id"), nullable=False),
        sa.Column("schema_version", sa.String(8), nullable=False),
        sa.Column("source", sa.String(16), nullable=False),
        sa.Column("seq", sa.Integer),
        sa.Column("measured_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("received_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("topic", sa.Text, nullable=False),
        sa.Column("raw", postgresql.JSONB, nullable=False),
    )
    op.create_table(
        "sensor_readings",
        sa.Column("id", sa.BigInteger, primary_key=True, autoincrement=True),
        sa.Column(
            "message_pk",
            sa.BigInteger,
            sa.ForeignKey("telemetry_messages.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("device_id", sa.String(64), sa.ForeignKey("devices.device_id"), nullable=False),
        sa.Column("sensor_type", sa.String(32), nullable=False),
        sa.Column("value", sa.Float, nullable=False),
        sa.Column("unit", sa.String(16), nullable=False),
        sa.Column("quality", sa.String(16), nullable=False),
        sa.Column("source", sa.String(16), nullable=False),
        sa.Column("measured_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("quality IN ('ok', 'suspect')", name="ck_sensor_readings_quality"),
    )
    op.create_index(
        "ix_sensor_readings_latest", "sensor_readings", ["device_id", "sensor_type", "measured_at"]
    )
    op.create_table(
        "ingest_rejects",
        sa.Column("id", sa.BigInteger, primary_key=True, autoincrement=True),
        sa.Column("received_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("topic", sa.Text, nullable=False),
        sa.Column("payload", sa.Text, nullable=False),
        sa.Column("error", sa.Text, nullable=False),
    )


def downgrade() -> None:
    op.drop_table("ingest_rejects")
    op.drop_index("ix_sensor_readings_latest", table_name="sensor_readings")
    op.drop_table("sensor_readings")
    op.drop_table("telemetry_messages")
    op.drop_table("devices")
