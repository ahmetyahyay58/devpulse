"""Etiketleme için commit mesajı havuzu toplar (bkz. docs/etiketler.md).

    py -m ml.collect           # açık kaynak havuzu -> ml/data/pool.jsonl (repoya girer)
    py -m ml.collect --own 3   # 3 numaralı kullanıcının kendi commit'leri -> ml/data/own.jsonl
                               # (kişisel veri: .gitignore'da, repoya girmez)

Gizlilik: GraphQL sorgusu yazar alanlarını hiç istemez. Mesaj içindeki imza satırları
(Signed-off-by vb.) silinir, e-posta ve @kullanıcı bahisleri maskelenir.
"""
import argparse
import json
import random
import re
from pathlib import Path

from app.config import settings
from app.sync.github_client import LiveGitHubClient

DATA_DIR = Path(__file__).resolve().parent / "data"
SEED = 20261112
PER_REPO = 60  # her projeden örneklenen mesaj
PAGES = 3  # her projeden en son 300 commit arasından örneklenir

# Farklı mesaj alışkanlıkları: serbest biçim, conventional commits, "Fixed #N", "paket: ...".
REPOS = [
    "pallets/flask", "psf/requests", "microsoft/vscode", "flutter/flutter",
    "vuejs/core", "angular/angular", "django/django", "golang/go",
]

HISTORY_QUERY = """
query($owner: String!, $name: String!, $after: String) {
  repository(owner: $owner, name: $name) {
    defaultBranchRef {
      target {
        ... on Commit {
          history(first: 100, after: $after) {
            pageInfo { hasNextPage endCursor }
            nodes { oid message parents { totalCount } }
          }
        }
      }
    }
  }
  rateLimit { cost remaining }
}
"""

# "Signed-off-by:", "Co-authored-by:", "Reviewed-on:", "Change-Id:" gibi imza/iz satırları.
_TRAILER = re.compile(r"^\s*[A-Za-z][\w-]*-(by|on|Id|Result|Submit|Queue)\s*:.*$", re.IGNORECASE | re.MULTILINE)
_EMAIL = re.compile(r"[\w.+-]+@[\w-]+\.[\w.-]+")
_MENTION = re.compile(r"(?<![\w@])@[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})")
MAX_LEN = 1000


def clean_message(message: str) -> str:
    """Kişisel bilgi taşıyabilen kısımları siler/maskeler, boş satır fazlasını toplar.

    E-posta içeren satır tamamen silinir (yalnız maskelemek yetmez: otomatik "roll" commit'lerinde
    e-postanın yanında kişi adı da durur, ör. "Ad Soyad <e-posta>").
    """
    text = _TRAILER.sub("", message)
    text = "\n".join(line for line in text.splitlines() if not _EMAIL.search(line))
    text = _MENTION.sub("@kullanici", text)
    text = re.sub(r"\n{3,}", "\n\n", text).strip()
    return text[:MAX_LEN]


def fetch_repo(client: LiveGitHubClient, full_name: str) -> list[dict]:
    owner, name = full_name.split("/")
    nodes, after = [], None
    for _ in range(PAGES):
        data = client.query("pool", HISTORY_QUERY, {"owner": owner, "name": name, "after": after})
        history = data["repository"]["defaultBranchRef"]["target"]["history"]
        nodes += history["nodes"]
        if not history["pageInfo"]["hasNextPage"]:
            break
        after = history["pageInfo"]["endCursor"]
    # Birleştirme commit'leri tür bilgisi taşımaz: atlanır.
    return [n for n in nodes if n["parents"]["totalCount"] <= 1]


def build_pool(client: LiveGitHubClient) -> list[dict]:
    rng = random.Random(SEED)
    pool = []
    for full_name in REPOS:
        candidates = [n for n in fetch_repo(client, full_name) if clean_message(n["message"])]
        for n in rng.sample(candidates, min(PER_REPO, len(candidates))):
            pool.append({
                "id": f"{full_name}@{n['oid'][:12]}",
                "repo": full_name,
                "message": clean_message(n["message"]),
            })
    rng.shuffle(pool)  # etiketlerken aynı projeden art arda gelmesin
    return pool


def export_own(user_id: int) -> list[dict]:
    """Geliştiricinin kendi commit'leri (alan dışı test kümesi). Kişisel veridir."""
    from sqlalchemy import select

    from app.db import SessionLocal
    from app.models import Commit, Repo

    with SessionLocal() as db:
        rows = db.execute(
            select(Commit.oid, Commit.message).join(Repo).where(Repo.user_id == user_id)
            .order_by(Commit.authored_at)
        ).all()
    return [{"id": f"own@{oid[:12]}", "repo": "own", "message": clean_message(msg)} for oid, msg in rows]


def write_jsonl(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Etiketleme havuzu topla")
    parser.add_argument("--own", type=int, metavar="KULLANICI_ID", help="kendi commit'lerini dışa aktar")
    args = parser.parse_args()

    if args.own is not None:
        rows = export_own(args.own)
        write_jsonl(DATA_DIR / "own.jsonl", rows)
        print(f"{len(rows)} kendi commit'i -> {DATA_DIR / 'own.jsonl'} (repoya girmez)")
        return

    if not settings.github_token:
        raise SystemExit("GITHUB_TOKEN gerekli (backend/.env).")
    client = LiveGitHubClient(settings.github_token)
    pool = build_pool(client)
    write_jsonl(DATA_DIR / "pool.jsonl", pool)
    per_repo = {r: sum(1 for p in pool if p["repo"] == r) for r in REPOS}
    print(f"{len(pool)} mesaj -> {DATA_DIR / 'pool.jsonl'}")
    print(f"istek: {len(client.request_log)}, puan: {sum(s.cost for s in client.request_log)}")
    print("proje başına:", per_repo)


if __name__ == "__main__":
    main()
