"""Demo istemcisi: sentetik veriyi JSON dosyasından okur. GitHubSource arayüzünü uygular.

Dosya biçimi: {"profile": {...}, "repos": [{..., "commits": [...]}], "calendar": [{"day", "count"}]}
Demo takvimi seyrektir: yalnızca katkı olan günler yazılır.
Alan adları source.py'deki veri sınıflarıyla aynıdır.
"""
import json
import time
from collections.abc import Iterator
from datetime import date, datetime
from pathlib import Path

from app.sync.source import CalendarDay, CommitData, Profile, RepoData, RequestStat


DEMO_FILE = Path(__file__).resolve().parent.parent.parent / "demo" / "demo_user.json"


def _dt(value: str | None) -> datetime | None:
    return datetime.fromisoformat(value) if value else None


class DemoClient:
    def __init__(self, path: str | Path):
        self.request_log: list[RequestStat] = []
        self._data = json.loads(Path(path).read_text(encoding="utf-8"))

    def _log(self, kind: str, start: float) -> None:
        # Gerçek istek yok: puan 0, süre dosyadan okuma süresi.
        self.request_log.append(RequestStat(kind, 0, round((time.perf_counter() - start) * 1000)))

    def fetch_profile(self) -> Profile:
        start = time.perf_counter()
        p = self._data["profile"]
        self._log("profile", start)
        return Profile(node_id=p["node_id"], login=p["login"], created_at=_dt(p["created_at"]))

    def fetch_repos(self, profile: Profile) -> list[RepoData]:
        start = time.perf_counter()
        repos = [
            RepoData(
                **{k: v for k, v in r.items() if k != "commits"}
                | {"created_at": _dt(r.get("created_at")), "pushed_at": _dt(r.get("pushed_at"))}
            )
            for r in self._data["repos"]
        ]
        self._log("repos", start)
        return repos

    def fetch_calendar(self, profile: Profile) -> list[CalendarDay]:
        start = time.perf_counter()
        days = [
            CalendarDay(day=date.fromisoformat(d["day"]), count=d["count"])
            for d in self._data.get("calendar", [])
        ]
        self._log("calendar", start)
        return days

    def fetch_commits(self, repo: RepoData, profile: Profile) -> Iterator[CommitData]:
        start = time.perf_counter()
        raw = next(r for r in self._data["repos"] if r["node_id"] == repo.node_id)["commits"]
        self._log("commits", start)
        for c in raw:
            yield CommitData(**c | {"authored_at": _dt(c["authored_at"])})
