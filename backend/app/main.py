"""FastAPI uygulama girişi."""
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app import models  # noqa: F401  (tabloların Base'e kaydolması için)
from app.db import Base, engine

log = logging.getLogger("uvicorn.error")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Geçici çözüm: eksik tabloları oluşturur, var olanlara dokunmaz.
    # Şema değişmeye başlayınca Alembic migration'larına geçilecek.
    try:
        Base.metadata.create_all(engine)
    except Exception as exc:
        log.warning("Veritabanına bağlanılamadı, tablolar oluşturulmadı: %s", exc)
    yield


app = FastAPI(title="DevPulse API", lifespan=lifespan)

# Yalnızca Flutter web (tarayıcı) için gerekir; Android uygulaması CORS'tan etkilenmez.
# Geliştirmede yerel adreslere, her porta izin verilir.
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_methods=["GET", "POST", "DELETE"],
    allow_headers=["*"],
)


@app.get("/health")
def health() -> dict:
    """Sunucu ayakta mı ve veritabanına ulaşabiliyor mu?"""
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        database = "ok"
    except Exception:
        database = "unreachable"
    return {"status": "ok", "database": database}
