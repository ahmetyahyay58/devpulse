"""Veritabanı tabloları.

Gizlilik: e-posta ve commit yazar adı hiçbir tabloda saklanmaz.
Başka kişilerin kullanıcı adları da saklanmaz (repo sahibi login'i dahil).
Tüm zamanlar UTC olarak timezone'lu tutulur; yerel saate çevirme users.timezone ile yapılır.
"""
from datetime import date, datetime

from sqlalchemy import (
    ARRAY,
    BigInteger,
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    github_node_id: Mapped[str] = mapped_column(String(64), unique=True)  # GraphQL "id"
    github_login: Mapped[str] = mapped_column(String(39))  # kullanıcının kendi login'i
    # Gece kuşu, aktif gün, seri gibi hesaplar için (ör. "Europe/Istanbul").
    timezone: Mapped[str | None] = mapped_column(String(64))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    last_synced_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    repos: Mapped[list["Repo"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    sync_jobs: Mapped[list["SyncJob"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    contribution_days: Mapped[list["ContributionDay"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )


class ContributionDay(Base):
    """GitHub katkı takviminin bir günü, GitHub'ın verdiği haliyle.

    Takvim yalnız commit'leri değil PR, issue ve incelemeleri de sayar; bu yüzden
    commits tablosundaki günlük sayılarla birebir tutması beklenmez.
    """

    __tablename__ = "contribution_days"

    # Bileşik birincil anahtar: kullanıcı başına her gün tek satır.
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    day: Mapped[date] = mapped_column(Date, primary_key=True)
    count: Mapped[int] = mapped_column(Integer)

    user: Mapped[User] = relationship(back_populates="contribution_days")


class Repo(Base):
    __tablename__ = "repos"
    __table_args__ = (UniqueConstraint("user_id", "github_node_id"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    github_node_id: Mapped[str] = mapped_column(String(64))
    name: Mapped[str] = mapped_column(String(100))  # sahip login'i olmadan, yalnız repo adı
    is_owner: Mapped[bool] = mapped_column(Boolean)  # False: başkasının reposuna katkı
    is_fork: Mapped[bool] = mapped_column(Boolean, default=False)
    is_private: Mapped[bool] = mapped_column(Boolean, default=False)
    primary_language: Mapped[str | None] = mapped_column(String(50))

    # Proje sağlığı / eksiklik takibi alanları
    description: Mapped[str | None] = mapped_column(Text)
    has_readme: Mapped[bool | None] = mapped_column(Boolean)
    license_spdx: Mapped[str | None] = mapped_column(String(50))  # ör. "MIT"; yoksa None
    topics: Mapped[list[str]] = mapped_column(ARRAY(String(50)), default=list)

    created_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    pushed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    user: Mapped[User] = relationship(back_populates="repos")
    commits: Mapped[list["Commit"]] = relationship(back_populates="repo", cascade="all, delete-orphan")


class Commit(Base):
    __tablename__ = "commits"
    # Aynı commit tekrar senkronda iki kez eklenmesin (tekrar çalıştırılabilir senkron).
    __table_args__ = (UniqueConstraint("repo_id", "oid"),)

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    repo_id: Mapped[int] = mapped_column(ForeignKey("repos.id", ondelete="CASCADE"), index=True)
    oid: Mapped[str] = mapped_column(String(40))  # commit SHA
    authored_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)  # UTC
    message: Mapped[str] = mapped_column(Text)  # sınıflandırma için; LLM'e gönderilmez
    additions: Mapped[int | None] = mapped_column(Integer)
    deletions: Mapped[int | None] = mapped_column(Integer)
    changed_files: Mapped[int | None] = mapped_column(Integer)
    # Ortak yazar commit'leri sayılacak mı açık karar; bayrakla saklayıp sonra seçebiliriz.
    is_coauthored: Mapped[bool] = mapped_column(Boolean, default=False)

    repo: Mapped[Repo] = relationship(back_populates="commits")


class SyncJob(Base):
    __tablename__ = "sync_jobs"
    __table_args__ = (
        CheckConstraint(
            "status IN ('pending', 'running', 'done', 'failed')", name="sync_jobs_status_check"
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    status: Mapped[str] = mapped_column(String(10), default="pending")
    # Senkron dakikalar sürebilir; ekran ilerlemeyi bu sayılardan gösterir.
    repos_total: Mapped[int | None] = mapped_column(Integer)
    repos_done: Mapped[int] = mapped_column(Integer, default=0)
    commits_synced: Mapped[int] = mapped_column(Integer, default=0)  # API'den gelen
    commits_inserted: Mapped[int] = mapped_column(Integer, default=0)  # yeni yazılan
    calendar_days: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    # Her API isteğinin ölçümü: [{"kind": "commits", "cost": 1, "duration_ms": 1840}, ...]
    requests: Mapped[list[dict]] = mapped_column(JSONB, default=list)
    request_count: Mapped[int] = mapped_column(Integer, default=0)
    total_cost: Mapped[int] = mapped_column(Integer, default=0)
    total_duration_ms: Mapped[int] = mapped_column(Integer, default=0)
    error: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    finished_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    user: Mapped[User] = relationship(back_populates="sync_jobs")
