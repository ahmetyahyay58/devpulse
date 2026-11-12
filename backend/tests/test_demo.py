"""Sentetik demo üreteci ve tarih kaydırma testleri."""
import json
from collections import Counter
from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select

from app.config import settings
from app.metrics.activity import CommitPoint
from app.metrics.overview import build_overview
from app.metrics.projects import RepoFacts, build_projects
from app.metrics.sufficiency import Sufficiency
from app.models import Commit, Repo
from app.sync import demo_generator as gen
from app.sync.demo_client import DEFAULT_DEMO_FILE, DemoClient

DATA = gen.generate()


def _commits(data=DATA):
    return [c for r in data["repos"] for c in r["commits"]]


def _local_day(iso: str):
    return datetime.fromisoformat(iso).astimezone(gen.TZ).date()


# --- Üreteç ----------------------------------------------------------------------------

def test_generator_is_deterministic():
    assert gen.generate() == DATA
    assert gen.generate(seed=1) != DATA


def test_committed_demo_file_matches_generator():
    # Dosya elle değiştirilirse ya da üreteç değişip dosya yeniden üretilmezse kırılır.
    assert DEFAULT_DEMO_FILE.read_text(encoding="utf-8") == gen.to_json(DATA)


def test_calendar_counts_at_least_commits_per_day():
    per_day = Counter(_local_day(c["authored_at"]) for c in _commits())
    calendar = {d["day"]: d["count"] for d in DATA["calendar"]}
    for day, n in per_day.items():
        assert calendar[day.isoformat()] >= n  # takvim commit dışı katkıları da sayar


def test_vacation_has_no_commits():
    start = gen.ANCHOR - timedelta(days=gen.VACATION[0])
    end = gen.ANCHOR - timedelta(days=gen.VACATION[1])
    assert not [c for c in _commits() if start <= _local_day(c["authored_at"]) <= end]


def test_injected_burst_is_recorded_and_present():
    [burst] = DATA["_injected"]
    per_day = Counter(_local_day(c["authored_at"]) for c in _commits())
    start = datetime.fromisoformat(burst["start"]).date()
    for k in range(3):
        day = start + timedelta(days=k)
        # 20:00'de başlayan oturum gece yarısını geçer: o gün + ertesi gün sabahı.
        assert per_day[day] + per_day[day + timedelta(days=1)] >= 18


def test_generated_demo_has_enough_data_for_every_metric():
    points = [CommitPoint(datetime.fromisoformat(c["authored_at"]),
                          c["additions"] + c["deletions"]) for c in _commits()]
    o = build_overview(points, "Europe/Istanbul", gen.ANCHOR, repo_count=len(DATA["repos"]))
    # Zenginleştirmenin amacı: demo'da hiçbir bölüm "yeterli veri yok" demesin.
    assert {o.continuity.sufficiency, o.rhythm.sufficiency, o.sessions.sufficiency} == {Sufficiency.NORMAL}


def test_generated_demo_shows_every_project_state():
    now = datetime.combine(gen.ANCHOR, datetime.min.time(), timezone.utc)
    facts = [RepoFacts(
        name=r["name"], is_owner=r["is_owner"], is_fork=r["is_fork"], is_private=False,
        primary_language=r["primary_language"], description=r["description"],
        has_readme=r["has_readme"], license_spdx=r["license_spdx"], topics=r["topics"],
        pushed_at=datetime.fromisoformat(r["pushed_at"]), commit_count=len(r["commits"]),
    ) for r in DATA["repos"]]
    out = build_projects(facts, now)
    scores = {p.name: p.score for p in out.projects}
    assert scores["hava-durumu-api"] == 100
    assert scores["flutter-sayac"] == 0
    assert scores["awesome-turkce"] is None and scores["acik-kaynak-kutuphane"] is None  # fork, katkı


# --- Tarih kaydırma ------------------------------------------------------------------------

def _write(tmp_path, data) -> str:
    path = tmp_path / "demo.json"
    path.write_text(json.dumps(data), encoding="utf-8")
    return str(path)


def test_dates_shift_to_today_and_keep_weekday_and_hour(tmp_path):
    client = DemoClient(_write(tmp_path, DATA), today=gen.ANCHOR + timedelta(days=10))
    profile = client.fetch_profile()
    repo = client.fetch_repos(profile)[0]
    original = datetime.fromisoformat(DATA["repos"][0]["commits"][0]["authored_at"])
    shifted = next(client.fetch_commits(repo, profile)).authored_at

    assert shifted - original == timedelta(days=10)
    assert shifted.hour == original.hour  # ritim korunur
    assert client.fetch_calendar(profile)[0].day.isoformat() > DATA["calendar"][0]["day"]
    assert profile.created_at == datetime.fromisoformat(DATA["profile"]["created_at"])
    assert client.replaces_existing is True


def test_anchored_demo_always_replaces_even_with_zero_shift(tmp_path):
    # Hata kaydı: üretim gününde (kaydırma 0) eski demo verisi silinmiyordu.
    assert DemoClient(_write(tmp_path, DATA), today=gen.ANCHOR).replaces_existing is True
    small = {k: v for k, v in DATA.items() if k != "anchor_date"}
    assert DemoClient(_write(tmp_path, small)).replaces_existing is False


def test_leftover_old_demo_data_is_replaced(api, db, tmp_path, monkeypatch):
    # Önce eski küçük demo dosyasıyla senkron (testlerdeki varsayılan), sonra üretilmiş dosyayla.
    token = api.post("/auth/demo").json()["session_token"]
    headers = {"Authorization": f"Bearer {token}"}
    api.post("/sync", json={}, headers=headers)
    assert db.scalar(select(func.count()).select_from(Commit)) == 6

    monkeypatch.setattr(settings, "demo_file", _write(tmp_path, DATA))
    api.post("/sync", json={}, headers=headers)
    assert db.scalar(select(func.count()).select_from(Repo)) == len(DATA["repos"])  # eski 2 repo yok


def test_shifted_demo_resync_replaces_instead_of_duplicating(api, db, tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "demo_file", _write(tmp_path, DATA))
    token = api.post("/auth/demo").json()["session_token"]
    headers = {"Authorization": f"Bearer {token}"}

    for _ in range(2):
        job_id = api.post("/sync", json={}, headers=headers).json()["job_id"]
        assert api.get(f"/sync/jobs/{job_id}", headers=headers).json()["status"] == "done"

    assert db.scalar(select(func.count()).select_from(Repo)) == len(DATA["repos"])
    assert db.scalar(select(func.count()).select_from(Commit)) == len(_commits())
