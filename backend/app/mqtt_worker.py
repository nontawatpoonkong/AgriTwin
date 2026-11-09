"""MQTT subscriber that runs inside the FastAPI process (one process to start for a solo developer).

Run the API with a single worker (the default for `uvicorn` / `fastapi dev`), otherwise each worker
would subscribe and try to ingest the same messages (harmless thanks to message_id, but wasteful).
"""

from __future__ import annotations

import logging
import threading

import paho.mqtt.client as mqtt

from .config import Settings
from .contract import telemetry_subscription
from .db import get_sessionmaker
from .ingest import ingest_message

log = logging.getLogger(__name__)


class MqttIngestWorker:
    def __init__(self, settings: Settings):
        self.settings = settings
        self.subscription = telemetry_subscription(settings.mqtt_env)
        self.connected = threading.Event()
        self.counts = {"accepted": 0, "duplicate": 0, "rejected": 0, "errors": 0}
        self.client = mqtt.Client(
            mqtt.CallbackAPIVersion.VERSION2, client_id=settings.mqtt_client_id, clean_session=False
        )
        if settings.mqtt_username:
            self.client.username_pw_set(settings.mqtt_username, settings.mqtt_password)
        self.client.reconnect_delay_set(min_delay=1, max_delay=30)
        self.client.on_connect = self._on_connect
        self.client.on_disconnect = self._on_disconnect
        self.client.on_message = self._on_message

    def start(self) -> None:
        log.info("MQTT connecting to %s:%s", self.settings.mqtt_host, self.settings.mqtt_port)
        # connect_async + loop_start: the API still starts if the broker is down and keeps retrying.
        self.client.connect_async(self.settings.mqtt_host, self.settings.mqtt_port, keepalive=30)
        self.client.loop_start()

    def stop(self) -> None:
        self.client.disconnect()
        self.client.loop_stop()

    def _on_connect(self, client, userdata, flags, reason_code, properties):
        if reason_code.is_failure:
            log.error("MQTT connect failed: %s", reason_code)
            return
        client.subscribe(self.subscription, qos=1)
        self.connected.set()
        log.info("MQTT connected, subscribed to %s", self.subscription)

    def _on_disconnect(self, client, userdata, flags, reason_code, properties):
        self.connected.clear()
        log.warning("MQTT disconnected (%s), will retry", reason_code)

    def _on_message(self, client, userdata, msg: mqtt.MQTTMessage):
        try:
            with get_sessionmaker()() as session:
                result = ingest_message(session, msg.topic, msg.payload)
            self.counts[result.outcome] += 1
        except Exception:  # never kill the network thread
            self.counts["errors"] += 1
            log.exception("failed to ingest message on %s", msg.topic)
