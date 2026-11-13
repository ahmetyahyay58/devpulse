"""Veri çekme katmanının arayüzü.

Canlı GitHub istemcisi ve demo istemcisi bu arayüzü uygular; senkron kodu
(runner.py) yalnızca bunu bilir, verinin nereden geldiğini bilmez.
"""
from collections.abc import Iterator
from dataclasses import dataclass, field
from datetime import date, datetime
from typing import Protocol


@dataclass
class Profile:
    node_id: str
    login: str
    created_at: datetime


@dataclass
class RepoData:
    node_id: str
    name: str  # sahibin login'i olmadan
    is_owner: bool
    is_fork: bool
    is_private: bool
    primary_language: str | None
    description: str | None
    has_readme: bool | None
    license_spdx: str | None
    topics: list[str]
    created_at: datetime | None
    pushed_at: datetime | None
    readme_bytes: int | None = None  # README'nin bayt boyutu (içerik çekilmez)
    is_archived: bool = False
    languages: dict[str, int] = field(default_factory=dict)  # dil -> bayt
    tools: list[str] = field(default_factory=list)  # kök dizinden tespit edilen araçlar


@dataclass
class CommitData:
    oid: str
    authored_at: datetime  # UTC
    message: str
    additions: int | None
    deletions: int | None
    changed_files: int | None
    is_coauthored: bool


@dataclass
class CalendarDay:
    day: date
    count: int  # o günkü katkı sayısı (commit + PR + issue + inceleme)


@dataclass
class RequestStat:
    """Tek bir API isteğinin ölçümü (sync_jobs.requests'e yazılır)."""
    kind: str  # "profile", "repos", "contributed_repos", "commits", "calendar"
    cost: int  # GraphQL rateLimit puanı; demo için 0
    duration_ms: int


class GitHubSource(Protocol):
    # Her istek buraya eklenir; senkron kodu bunu sync_jobs'a aktarır.
    request_log: list[RequestStat]

    def fetch_profile(self) -> Profile: ...

    def fetch_repos(self, profile: Profile) -> list[RepoData]:
        """Kullanıcının sahip olduğu repolar + commit attığı başkasına ait repolar."""
        ...

    def fetch_commits(self, repo: RepoData, profile: Profile) -> Iterator[CommitData]:
        """Repodaki (varsayılan dal) kullanıcının kendi commit'leri, sayfa sayfa."""
        ...

    def fetch_calendar(self, profile: Profile) -> list[CalendarDay]:
        """Hesabın açıldığı yıldan bugüne katkı takviminin günleri."""
        ...
