"""Veritabanı bağlantısı: engine, oturum fabrikası ve modellerin ortak tabanı."""
from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from app.config import settings

# pool_pre_ping: havuzdaki bağlantı kopmuşsa kullanmadan önce fark eder.
# pool_recycle: bulut veritabanı (Neon) boşta kalan bağlantıları kapatır; 5 dakikadan eski
# bağlantı yenilenir. Bağlantı havuzlayıcı (PgBouncer, "-pooler" adresi) hazır ifadeleri
# (prepared statement) taşıyamayabilir; o durumda psycopg'ye kapattırılır.
_connect_args = {"prepare_threshold": None} if "-pooler" in settings.database_url else {}
engine = create_engine(settings.database_url, pool_pre_ping=True, pool_recycle=300, connect_args=_connect_args)
SessionLocal = sessionmaker(bind=engine)


class Base(DeclarativeBase):
    """Tüm tablo modelleri bu sınıftan türer."""
