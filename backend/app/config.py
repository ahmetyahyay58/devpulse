"""Uygulama ayarları. Değerler ortam değişkenlerinden ya da backend/.env dosyasından okunur."""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # SQLAlchemy bağlantı adresi; "+psycopg" sürücüsü psycopg 3'ü kullanır.
    database_url: str = "postgresql+psycopg://devpulse:devpulse@localhost:5432/devpulse"

    # Geçici: OAuth gelene kadar senkron bu token'la çalışır (GITHUB_TOKEN ortam değişkeni).
    github_token: str | None = None


settings = Settings()
