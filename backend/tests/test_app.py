"""Uygulama, şema ve gizlilik kuralı testleri."""
from alembic import command
from fastapi.testclient import TestClient

from app.db import Base
from app.main import app


def test_health_reports_ok():
    resp = TestClient(app).get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok", "database": "ok"}


def test_models_match_migrations(alembic_config):
    # Model değişip migration yazılmadıysa bu hata verir.
    command.check(alembic_config)


# CLAUDE.md: "E-posta ve yazar adı veritabanında saklanmaz. Başka kişilerin
# kullanıcı adları saklanmaz." Bu kural bir testle korunur.
FORBIDDEN_COLUMNS = {
    "email",
    "author_name",
    "author_email",
    "committer_name",
    "committer_email",
    "owner_login",
    "name_with_owner",
}


def test_no_personal_data_columns():
    found = [
        f"{table.name}.{column.name}"
        for table in Base.metadata.tables.values()
        for column in table.columns
        if column.name in FORBIDDEN_COLUMNS or "email" in column.name
    ]
    assert found == [], f"Gizlilik kuralı ihlali: {found}"


def test_users_table_has_no_display_name():
    # Kullanıcının kendi login'i tutulur ama GitHub'daki gerçek adı tutulmaz.
    assert "name" not in Base.metadata.tables["users"].columns
