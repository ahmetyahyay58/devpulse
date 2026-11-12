"""Ortak test kurulumu.

Testler gerçek veritabanına (devpulse) asla dokunmaz: her test oturumunda ayrı bir
devpulse_test veritabanı açılır, şema Alembic migration'larıyla kurulur, sonunda silinir.
"""
import os
from pathlib import Path

# Bu satırlar app.* import edilmeden ÖNCE çalışmalı: ayarlar import anında okunur.
SERVER = "devpulse:devpulse@localhost:5432"
TEST_DB = "devpulse_test"
os.environ["DATABASE_URL"] = f"postgresql+psycopg://{SERVER}/{TEST_DB}"
os.environ["GITHUB_TOKEN"] = ""  # testler gerçek GitHub'a asla gitmez
os.environ["JWT_SECRET"] = "test-jwt-secret-yalnizca-testlerde-kullanilir-32b"
os.environ["GITHUB_CLIENT_ID"] = "test-client-id"
os.environ["GITHUB_CLIENT_SECRET"] = "test-client-secret"

import psycopg  # noqa: E402
import pytest  # noqa: E402
from alembic import command  # noqa: E402
from alembic.config import Config  # noqa: E402
from sqlalchemy import text  # noqa: E402

from app.db import SessionLocal, engine  # noqa: E402

ALEMBIC_INI = Path(__file__).resolve().parent.parent / "alembic.ini"


def _admin(sql: str) -> None:
    """CREATE/DROP DATABASE işlem (transaction) içinde çalışamaz; autocommit gerekir."""
    with psycopg.connect(f"postgresql://{SERVER}/postgres", autocommit=True) as conn:
        conn.execute(sql)


@pytest.fixture(scope="session", autouse=True)
def test_database():
    try:
        _admin(f"DROP DATABASE IF EXISTS {TEST_DB} WITH (FORCE)")
        _admin(f"CREATE DATABASE {TEST_DB}")
    except psycopg.OperationalError:
        pytest.exit("PostgreSQL'e bağlanılamadı. Önce: docker compose up -d db", returncode=2)

    command.upgrade(Config(str(ALEMBIC_INI)), "head")  # şemayı migration'larla kur
    yield
    engine.dispose()  # açık bağlantıları kapat, yoksa veritabanı silinemez
    _admin(f"DROP DATABASE IF EXISTS {TEST_DB} WITH (FORCE)")


@pytest.fixture(autouse=True)
def clean_tables():
    """Her test boş tablolarla başlar."""
    with engine.begin() as conn:
        conn.execute(text(
            "TRUNCATE users, repos, commits, sync_jobs, contribution_days RESTART IDENTITY CASCADE"
        ))
    yield


@pytest.fixture
def db():
    with SessionLocal() as session:
        yield session


@pytest.fixture
def alembic_config() -> Config:
    return Config(str(ALEMBIC_INI))


@pytest.fixture
def api():
    from fastapi.testclient import TestClient

    from app.main import app

    return TestClient(app)


@pytest.fixture
def demo_auth(api) -> dict:
    """Demo kullanıcı olarak giriş yapılmış istek başlığı."""
    token = api.post("/auth/demo").json()["session_token"]
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def login_as():
    """login_as("U_me", "ben") -> o GitHub kimliğiyle giriş yapmış kullanıcının başlığı."""
    from app.auth import create_session_token
    from app.sync.runner import upsert_user
    from app.sync.source import Profile

    def _login(node_id: str, login: str) -> dict:
        from datetime import datetime, timezone

        with SessionLocal() as db:
            user_id = upsert_user(db, Profile(node_id, login, datetime.now(timezone.utc)), None)
            db.commit()
        return {"Authorization": f"Bearer {create_session_token(user_id)}"}

    return _login
