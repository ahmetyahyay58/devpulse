"""Komut satırından senkron.

    py -m app.sync                       # GITHUB_TOKEN ile canlı GitHub
    py -m app.sync --demo demo/demo_user.json
"""
import argparse
import sys
from collections import defaultdict

from sqlalchemy import func, select

from app.config import settings
from app.db import SessionLocal
from app.models import Commit, Repo, SyncJob
from app.sync.runner import run_sync


def main() -> int:
    parser = argparse.ArgumentParser(description="DevPulse GitHub senkronu")
    parser.add_argument("--demo", metavar="DOSYA", help="canlı GitHub yerine demo JSON dosyası")
    parser.add_argument("--full", action="store_true", help="push gelmeyen repoları da baştan çek")
    args = parser.parse_args()

    if args.demo:
        from app.sync.demo_client import DemoClient
        source = DemoClient(args.demo)
    else:
        if not settings.github_token:
            print("GITHUB_TOKEN tanımlı değil (ortam değişkeni ya da backend/.env).")
            return 1
        from app.sync.github_client import LiveGitHubClient
        source = LiveGitHubClient(settings.github_token)

    job_id = run_sync(source, full=args.full)  # tablolar Alembic ile oluşturulmuş olmalı

    with SessionLocal() as db:
        job = db.get(SyncJob, job_id)
        repo_count = db.scalar(select(func.count()).select_from(Repo).where(Repo.user_id == job.user_id))
        commit_count = db.scalar(
            select(func.count()).select_from(Commit).join(Repo).where(Repo.user_id == job.user_id)
        )
        by_kind: dict[str, list[int]] = defaultdict(lambda: [0, 0, 0])
        for r in job.requests:
            k = by_kind[r["kind"]]
            k[0] += 1
            k[1] += r["cost"]
            k[2] += r["duration_ms"]

        print(f"sync_job #{job.id}: {job.status}")
        print(f"  repo: {job.repos_done}/{job.repos_total} (push gelmediği için atlanan: {job.repos_skipped})")
        print(f"  commit: API'den {job.commits_synced}, yeni yazılan {job.commits_inserted}")
        print(f"  katkı takvimi: {job.calendar_days} gün")
        print(f"  istek: {job.request_count}, puan: {job.total_cost}, süre: {job.total_duration_ms / 1000:.1f} s")
        for kind, (n, cost, ms) in by_kind.items():
            print(f"    {kind:<18} {n:>3} istek  {cost:>3} puan  ort. {ms / n / 1000:.2f} s")
        print(f"Veritabanında bu kullanıcı için: {repo_count} repo, {commit_count} commit")
    return 0


if __name__ == "__main__":
    sys.exit(main())
