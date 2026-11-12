"""Uygulama ayarları. Değerler ortam değişkenlerinden ya da backend/.env dosyasından okunur."""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # SQLAlchemy bağlantı adresi; "+psycopg" sürücüsü psycopg 3'ü kullanır.
    database_url: str = "postgresql+psycopg://devpulse:devpulse@localhost:5432/devpulse"

    # Yalnızca komut satırı senkronu (py -m app.sync) için kişisel token.
    # API bu değeri kullanmaz; API'de token her istekte telefondan gelir.
    github_token: str | None = None

    # GitHub OAuth App (github.com/settings/developers). Secret yalnızca burada durur,
    # mobil uygulamaya asla girmez.
    github_client_id: str | None = None
    github_client_secret: str | None = None
    # Yalnızca herkese açık veri: profil okuma yetkisi yeterli.
    github_oauth_scope: str = "read:user"

    # Oturum belirteci (JWT, HS256). Anahtar uzun ve rastgele olmalı; .env'de tutulur.
    jwt_secret: str | None = None
    jwt_ttl_days: int = 7


settings = Settings()
