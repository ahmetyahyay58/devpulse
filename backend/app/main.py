"""FastAPI uygulama girişi.

Şema Alembic ile yönetilir; tabloları oluşturmak/güncellemek için:
    py -m alembic upgrade head
"""
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.api import account, auth, metrics, projects, sync
from app.classify import classifier
from app.db import engine

log = logging.getLogger("uvicorn.error")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Commit türü modeli açılışta bir kez yüklenir: yoksa ilk kullanıcı isteği ~5 sn beklerdi.
    try:
        loaded = classifier._model() is not None
        log.info("Commit türü modeli %s", "yüklendi" if loaded else "bulunamadı (yalnız kurallar)")
    except Exception as exc:  # model bozuksa sunucu yine açılır; sınıflandırma kurallarla sürer
        log.warning("Commit türü modeli yüklenemedi: %s", exc)
    yield


app = FastAPI(title="DevPulse API", lifespan=lifespan)
app.include_router(auth.router)
app.include_router(sync.router)
app.include_router(metrics.router)
app.include_router(projects.router)
app.include_router(account.router)

# Yalnızca Flutter web (tarayıcı) için gerekir; Android uygulaması CORS'tan etkilenmez.
# Geliştirmede yerel adreslere, her porta izin verilir.
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_methods=["GET", "POST", "DELETE"],  # DELETE: /me (veri silme)
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
