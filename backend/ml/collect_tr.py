"""Türkçe, önekli commit mesajları toplar: önek etiket olur, sonra metinden silinir.

    py -m ml.collect_tr     # -> ml/data/tr_pool.jsonl (herkese açık veri, repoya girer)

Kaynak: GitHub commit araması (herkese açık repolar). Yazar alanları kaydedilmez; mesajlar
ml.collect.clean_message ile temizlenir (imza ve e-posta satırları silinir, @ maskelenir).

Önyargıya karşı: her sınıf AYNI, türden bağımsız Türkçe bağlaçlarla aranır ("için", "ile",
"ve"). "fix düzeltildi" gibi bir arama, model için yapay ve kolay bir ipucu yaratırdı.
Arama kotası sıkıdır: istekler arasında beklenir, toplama ~15-20 dakika sürer.
"""
import json
import re
import time
from pathlib import Path

import httpx

from app.classify.rules import parse_prefix  # önek kuralı tek yerde: uygulamayla aynı
from app.config import settings
from ml.collect import DATA_DIR, clean_message, write_jsonl

SEARCH_WORDS = ["için", "ile", "ve"]  # türden bağımsız bağlaçlar
QUERY_PREFIXES = ["feat", "fix", "docs", "refactor", "test", "chore"]
PAGES = 3  # her (önek, kelime) için en fazla 300 sonuç
PER_REPO = 5  # tek bir repo veriye hâkim olmasın
SLEEP = 13  # commit araması kotası: dakikada ~5 istek

TR_CHARS = re.compile(r"[çğıöşüÇĞİÖŞÜ]")
TR_WORDS = {"ve", "için", "ile", "bir", "bu", "da", "de", "olarak", "eklendi", "yapıldı", "edildi"}


def is_turkish(text: str) -> bool:
    """İlk satırda Türkçe harf ya da yaygın bir Türkçe kelime var mı?"""
    words = set(re.findall(r"\w+", text.lower()))
    return bool(TR_CHARS.search(text)) or bool(words & TR_WORDS)


def to_example(repo: str, oid: str, message: str) -> dict | None:
    """Ham mesajı eğitim örneğine çevirir; uygun değilse None."""
    cleaned = clean_message(message)
    lines = cleaned.splitlines()
    if not lines:
        return None
    parsed = parse_prefix(lines[0])
    if parsed is None or not is_turkish(parsed[1]):
        return None
    label, headline = parsed
    if parse_prefix(headline) or re.match(r"(?i)^[a-z]+(\([^)]*\))?!?:", headline):
        return None  # çift önek ("feat: CI: ..."): ikincisi metinde kalır, cevabı sızdırır
    body = "\n".join(lines[1:]).strip()
    return {
        "id": f"{repo}@{oid[:12]}",
        "repo": repo,
        "label": label,
        "text": (headline + ("\n" + body if body else ""))[:1000],  # önek silinmiş metin
    }


def collect() -> list[dict]:
    http = httpx.Client(timeout=30, headers={
        "Authorization": f"bearer {settings.github_token}",
        "Accept": "application/vnd.github+json", "User-Agent": "devpulse-ml",
    })
    examples: dict[str, dict] = {}
    per_repo: dict[str, int] = {}
    seen_text: set[str] = set()
    requests = 0
    for prefix in QUERY_PREFIXES:
        for word in SEARCH_WORDS:
            for page in range(1, PAGES + 1):
                resp = http.get("https://api.github.com/search/commits",
                                params={"q": f"{prefix} {word}", "per_page": 100, "page": page})
                requests += 1
                if resp.status_code == 403:  # kota: bekle ve bir kez daha dene
                    time.sleep(65)
                    resp = http.get("https://api.github.com/search/commits",
                                    params={"q": f"{prefix} {word}", "per_page": 100, "page": page})
                resp.raise_for_status()
                items = resp.json()["items"]
                for it in items:
                    repo = it["repository"]["full_name"]
                    ex = to_example(repo, it["sha"], it["commit"]["message"])
                    key = ex and ex["text"].lower()
                    if not ex or ex["id"] in examples or key in seen_text or per_repo.get(repo, 0) >= PER_REPO:
                        continue
                    examples[ex["id"]] = ex
                    seen_text.add(key)
                    per_repo[repo] = per_repo.get(repo, 0) + 1
                counts = {lbl: sum(e["label"] == lbl for e in examples.values()) for lbl in QUERY_PREFIXES}
                print(f"[{requests}] '{prefix} {word}' s{page}: toplam {len(examples)} {counts}", flush=True)
                time.sleep(SLEEP)
                if len(items) < 100:
                    break
    return sorted(examples.values(), key=lambda e: e["id"])


if __name__ == "__main__":
    if not settings.github_token:
        raise SystemExit("GITHUB_TOKEN gerekli (backend/.env).")
    rows = collect()
    write_jsonl(DATA_DIR / "tr_pool.jsonl", rows)
    print(f"\n{len(rows)} örnek -> {DATA_DIR / 'tr_pool.jsonl'}")
    print(f"farklı repo: {len({r['repo'] for r in rows})}")
    print("sınıf dağılımı:", {lbl: sum(r['label'] == lbl for r in rows) for lbl in QUERY_PREFIXES})
