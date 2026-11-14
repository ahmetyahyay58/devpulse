"""90 gün kuralı: son etkinliği (giriş ya da biten senkron) 90 günden eski hesapları siler.

Aydınlatma metni "Saklama süresi ve silme" bölümü bunu vaat eder. Sunucu açılışta bir kez,
sonra günde bir çalıştırır (app/main.py). Silme tek SQL komutudur; repolar, commit'ler,
takvim ve senkron kayıtları ON DELETE CASCADE ile gider (DELETE /me ile aynı yol).
"""
import asyncio
import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import delete, exists, select

from app.db import SessionLocal
from app.models import SyncJob, User
from app.sync.runner import STALE_AFTER

RETENTION = timedelta(days=90)
CHECK_EVERY = timedelta(days=1)

log = logging.getLogger("uvicorn.error")


def delete_after(last_active_at: datetime) -> datetime:
    """Bu tarihten sonra (etkinlik olmazsa) veriler silinir."""
    return last_active_at + RETENTION


def purge_inactive(now: datetime | None = None) -> int:
    """Süresi dolan hesapları siler; silinen hesap sayısını döner. Senkronu sürene dokunmaz."""
    now = now or datetime.now(timezone.utc)
    running = exists().where(
        SyncJob.user_id == User.id,
        SyncJob.status.in_(["pending", "running"]),
        SyncJob.created_at > now - STALE_AFTER,
    )
    with SessionLocal() as db:
        ids = db.scalars(
            delete(User).where(User.last_active_at < now - RETENTION, ~running).returning(User.id)
        ).all()
        db.commit()
    return len(ids)


async def run_daily() -> None:
    """Sunucu açık kaldıkça günde bir denetler. Hata olursa yazar ve ertesi gün yeniden dener."""
    while True:
        try:
            n = await asyncio.to_thread(purge_inactive)
            if n:
                # Kimin silindiği yazılmaz (kullanıcı adı log'a girmez), yalnız sayı.
                log.info("90 gün kuralı: %d etkin olmayan hesap silindi", n)
        except Exception:
            log.exception("90 gün kuralı denetimi başarısız")
        await asyncio.sleep(CHECK_EVERY.total_seconds())
