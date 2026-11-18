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
    # Android için ikinci OAuth App (geri dönüş adresi devpulse://oauth-callback).
    github_android_client_id: str | None = None
    github_android_client_secret: str | None = None
    # Yalnızca herkese açık veri: profil okuma yetkisi yeterli.
    github_oauth_scope: str = "read:user"

    # Oturum belirteci (JWT, HS256). Anahtar uzun ve rastgele olmalı; .env'de tutulur.
    jwt_secret: str | None = None
    jwt_ttl_days: int = 7

    # Demo kullanıcının veri dosyası; boşsa backend/demo/demo_user.json (testler küçük dosya verir).
    demo_file: str | None = None

    # AI katmanı (docs/ai_katmani.md): Google Gemini API. Anahtar yoksa her yerde şablon cevap.
    gemini_api_key: str | None = None
    # Lite: ölçümde hızlı ve erişilebilir (16 Kas: flash-latest 503 "yoğun talep" döndü). Ana model
    # yoğun/kotasız/zaman aşımlıysa bir kez yedeğe düşülür (docs/ai_katmani.md).
    gemini_model: str = "gemini-flash-lite-latest"
    gemini_fallback_model: str | None = "gemini-flash-latest"


settings = Settings()
