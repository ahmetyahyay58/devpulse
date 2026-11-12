"""FastAPI uygulama girişi.

Şema Alembic ile yönetilir; tabloları oluşturmak/güncellemek için:
    py -m alembic upgrade head
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.api import account, auth, metrics, projects, sync
from app.db import engine

app = FastAPI(title="DevPulse API")
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
