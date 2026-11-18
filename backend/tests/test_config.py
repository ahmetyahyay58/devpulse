"""Bulut veritabanı adresinin sürücüsü (docs/dagitim.md)."""
from app.config import Settings


def test_neon_style_url_uses_psycopg3():
    s = Settings(database_url="postgresql://u:p@ep-x.eu-central-1.aws.neon.tech/db?sslmode=require")
    assert s.database_url == "postgresql+psycopg://u:p@ep-x.eu-central-1.aws.neon.tech/db?sslmode=require"
    assert Settings(database_url="postgres://u:p@h/db").database_url.startswith("postgresql+psycopg://")
    local = "postgresql+psycopg://devpulse:devpulse@localhost:5432/devpulse"
    assert Settings(database_url=local).database_url == local
