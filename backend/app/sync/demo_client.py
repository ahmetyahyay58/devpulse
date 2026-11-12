"""Demo istemcisi: sentetik veriyi JSON dosyasından okur. GitHubSource arayüzünü uygular.

Dosya biçimi: {"profile": {...}, "repos": [{..., "commits": [...]}], "calendar": [{"day", "count"}],
"anchor_date": "YYYY-MM-DD" (isteğe bağlı)}. Alan adları source.py'deki veri sınıflarıyla aynıdır.

anchor_date varsa tüm tarihler (anchor -> bugün) farkı kadar ileri kaydırılır; demo hep güncel
görünür. Fark tam gün olduğu için haftanın günü ve saat (ritim) korunur.
"""
import json
import time
from collections.abc import Iterator
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

from app.config import settings
from app.sync.source import CalendarDay, CommitData, Profile, RepoData, RequestStat

DEFAULT_DEMO_FILE = Path(__file__).resolve().parent.parent.parent / "demo" / "demo_user.json"


def demo_path() -> Path:
    """DEMO_FILE ayarı varsa o (testler küçük dosya kullanır), yoksa üretilmiş demo dosyası."""
    return Path(settings.demo_file) if settings.demo_file else DEFAULT_DEMO_FILE


class DemoClient:
    def __init__(self, path: str | Path, today: date | None = None):
        self.request_log: list[RequestStat] = []
        self._data = json.loads(Path(path).read_text(encoding="utf-8"))
        anchor = self._data.get("anchor_date")
        today = today or datetime.now(timezone.utc).date()
        self._anchored = anchor is not None
        self._shift = timedelta(days=(today - date.fromisoformat(anchor)).days) if anchor else timedelta()

    @property
    def replaces_existing(self) -> bool:
        """Tarihi kaydırılan (anchor_date'li) demo verisi her senkronda baştan yazılır: commit
        kimlikleri aynı kalır, ON CONFLICT DO NOTHING eski tarihleri olduğu gibi bırakırdı.
        Kaydırma bugün 0 gün olsa bile geçerlidir (önceki senkronlardan kalan veri silinmeli)."""
        return self._anchored

    def _dt(self, value: str | None) -> datetime | None:
        return datetime.fromisoformat(value) + self._shift if value else None

    def _log(self, kind: str, start: float) -> None:
        # Gerçek istek yok: puan 0, süre dosyadan okuma süresi.
        self.request_log.append(RequestStat(kind, 0, round((time.perf_counter() - start) * 1000)))

    def fetch_profile(self) -> Profile:
        start = time.perf_counter()
        p = self._data["profile"]
        self._log("profile", start)
        # Hesap açılış tarihi kaydırılmaz (yıl yıl sorgu mantığı gerçek GitHub'daki gibi kalsın).
        return Profile(
            node_id=p["node_id"], login=p["login"], created_at=datetime.fromisoformat(p["created_at"])
        )

    def fetch_repos(self, profile: Profile) -> list[RepoData]:
        start = time.perf_counter()
        repos = [
            RepoData(
                **{k: v for k, v in r.items() if k != "commits"}
                | {"created_at": self._dt(r.get("created_at")), "pushed_at": self._dt(r.get("pushed_at"))}
            )
            for r in self._data["repos"]
        ]
        self._log("repos", start)
        return repos

    def fetch_calendar(self, profile: Profile) -> list[CalendarDay]:
        start = time.perf_counter()
        days = [
            CalendarDay(day=date.fromisoformat(d["day"]) + self._shift, count=d["count"])
            for d in self._data.get("calendar", [])
        ]
        self._log("calendar", start)
        return days

    def fetch_commits(self, repo: RepoData, profile: Profile) -> Iterator[CommitData]:
        start = time.perf_counter()
        raw = next(r for r in self._data["repos"] if r["node_id"] == repo.node_id)["commits"]
        self._log("commits", start)
        for c in raw:
            yield CommitData(**c | {"authored_at": self._dt(c["authored_at"])})
