"""Veritabanı bağlantısı: engine, oturum fabrikası ve modellerin ortak tabanı."""
from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from app.config import settings

# pool_pre_ping: havuzdaki bağlantı kopmuşsa kullanmadan önce fark eder.
engine = create_engine(settings.database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine)


class Base(DeclarativeBase):
    """Tüm tablo modelleri bu sınıftan türer."""
