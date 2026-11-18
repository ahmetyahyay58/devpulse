# DevPulse API: bulut (Render) için imaj. Yerel geliştirmede gerekmez (uvicorn doğrudan çalışır).
FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Önce bağımlılıklar: kod değişince bu katman önbellekten gelir, derleme hızlanır.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY alembic.ini ./
COPY migrations ./migrations
COPY app ./app
COPY demo ./demo

# Açılışta önce şema güncellenir (Alembic), sonra sunucu başlar. PORT'u Render verir.
CMD ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000} --proxy-headers --forwarded-allow-ips='*'"]
