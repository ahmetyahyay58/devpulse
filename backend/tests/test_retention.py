"""90 gün kuralı: etkin olmayan hesaplar silinir (aydınlatma metni "Saklama süresi")."""
from datetime import datetime, timedelta, timezone

from sqlalchemy import select, update

from app import retention
from app.db import SessionLocal
from app.models import ContributionDay, Repo, SyncJob, User

NOW = datetime(2026, 11, 14, 12, tzinfo=timezone.utc)


def _make_user(node: str, last_active: datetime, *, running_sync: bool = False) -> int:
    with SessionLocal() as db:
        user = User(github_node_id=node, github_login=node.lower(), last_active_at=last_active)
        db.add(user)
        db.flush()
        db.add(Repo(user_id=user.id, github_node_id=f"R_{node}", name="r", is_owner=True))
        db.add(ContributionDay(user_id=user.id, day=NOW.date(), count=1))
        if running_sync:
            db.add(SyncJob(user_id=user.id, status="running", created_at=NOW - timedelta(minutes=5)))
        db.commit()
        return user.id


def _exists(user_id: int) -> bool:
    with SessionLocal() as db:
        return db.get(User, user_id) is not None


def test_inactive_for_more_than_90_days_is_deleted_with_all_data():
    old = _make_user("U_old", NOW - timedelta(days=91))
    edge = _make_user("U_edge", NOW - timedelta(days=90))  # tam 90 gün: henüz silinmez
    fresh = _make_user("U_fresh", NOW - timedelta(days=3))

    assert retention.purge_inactive(NOW) == 1
    assert not _exists(old) and _exists(edge) and _exists(fresh)
    with SessionLocal() as db:  # CASCADE: repo ve takvim de gitti
        assert db.scalars(select(Repo).where(Repo.user_id == old)).first() is None
        assert db.scalars(select(ContributionDay).where(ContributionDay.user_id == old)).first() is None


def test_user_with_running_sync_is_not_deleted():
    busy = _make_user("U_busy", NOW - timedelta(days=200), running_sync=True)
    assert retention.purge_inactive(NOW) == 0 and _exists(busy)


def test_login_resets_activity(api, demo_auth):
    me = api.get("/me", headers=demo_auth).json()
    active = datetime.fromisoformat(me["last_active_at"])
    assert datetime.now(timezone.utc) - active < timedelta(minutes=1)
    assert datetime.fromisoformat(me["delete_after"]) - active == timedelta(days=90)
    assert me["retention_days"] == 90


def test_sync_resets_activity(api, demo_auth):
    with SessionLocal() as db:  # eski bir etkinlik gibi göster
        db.execute(update(User).values(last_active_at=NOW - timedelta(days=80)))
        db.commit()
    api.post("/sync", json={}, headers=demo_auth)
    me = api.get("/me", headers=demo_auth).json()
    assert datetime.now(timezone.utc) - datetime.fromisoformat(me["last_active_at"]) < timedelta(minutes=1)
    assert me["counts"]["repos"] == 2 and me["counts"]["commits"] > 0


def test_me_requires_session(api):
    assert api.get("/me").status_code == 401


def test_privacy_text_states_the_rule(api):
    text = api.get("/privacy").text
    assert "90 gün" in text and "otomatik" in text
