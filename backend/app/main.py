import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .api import router
from .config import get_settings
from .mqtt_worker import MqttIngestWorker

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    app.state.mqtt_worker = None
    if settings.mqtt_enabled:
        app.state.mqtt_worker = MqttIngestWorker(settings)
        app.state.mqtt_worker.start()
    yield
    if app.state.mqtt_worker is not None:
        app.state.mqtt_worker.stop()


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title="AgriTwin API", version="0.1.0", lifespan=lifespan)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[o.strip() for o in settings.cors_allow_origins.split(",")],
        allow_methods=["GET"],
        allow_headers=["*"],
    )
    app.include_router(router)
    return app


app = create_app()
