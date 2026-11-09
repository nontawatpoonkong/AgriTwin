from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Read from environment variables or backend/.env (see .env.example)."""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # Required. No default so credentials never live in source code (set it in backend/.env).
    database_url: str

    mqtt_enabled: bool = True
    mqtt_host: str = "localhost"
    mqtt_port: int = 1883
    mqtt_username: str | None = None
    mqtt_password: str | None = None
    mqtt_env: str = "dev"  # topic segment: agritwin/{mqtt_env}/devices/+/telemetry
    mqtt_client_id: str = "agritwin-backend"

    # A device is "offline" when nothing was received for this many seconds.
    device_offline_after_seconds: int = 180

    cors_allow_origins: str = "*"  # comma separated; "*" is for local development only


@lru_cache
def get_settings() -> Settings:
    return Settings()
