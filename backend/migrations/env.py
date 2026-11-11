"""Alembic ortamı: bağlantı adresini ve şemayı uygulamanın kendisinden alır."""
from logging.config import fileConfig

from alembic import context
from sqlalchemy import create_engine, pool

from app import models  # noqa: F401  (tabloların Base.metadata'ya kaydolması için)
from app.config import settings
from app.db import Base

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# autogenerate bu şemayı veritabanıyla karşılaştırır.
target_metadata = Base.metadata

CONFIGURE_OPTS = {
    "target_metadata": target_metadata,
    "compare_type": True,  # sütun tipi değişikliklerini de yakala
}


def run_migrations_offline() -> None:
    """Veritabanına bağlanmadan SQL çıktısı üretir (alembic upgrade --sql)."""
    context.configure(
        url=settings.database_url,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        **CONFIGURE_OPTS,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    engine = create_engine(settings.database_url, poolclass=pool.NullPool)
    with engine.connect() as connection:
        context.configure(connection=connection, **CONFIGURE_OPTS)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
