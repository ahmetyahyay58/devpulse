"""Sentetik demo kullanıcı üreteci.

    py -m app.sync.demo_generator   # demo/demo_user.json dosyasını yeniden üretir

Deterministiktir (sabit tohum): her çalıştırmada birebir aynı dosya çıkar. Veri, ANCHOR
tarihine göre üretilir; DemoClient okurken tarihleri bugüne kaydırır (demo hep güncel görünür).

Sentetik veri yalnızca kodun çalıştığını gösterir; hiçbir metriğin ya da modelin başarısını
kanıtlamaz. Bilerek eklenen anomali "_injected" alanında kayıtlıdır (anomali testleri için).
"""
import hashlib
import json
import random
from datetime import date, datetime, time, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

SEED = 20261112
ANCHOR = date(2026, 11, 12)  # üretimde "bugün"
DAYS = 180  # yaklaşık 6 aylık geçmiş
TZ = ZoneInfo("Europe/Istanbul")  # sahte kişinin yerel saati

P_ACTIVE_WEEKDAY = 0.72
P_ACTIVE_WEEKEND = 0.30
VACATION = (100, 114)  # bugünden kaç gün önce: bu aralıkta hiç commit yok
BURST = (40, 38)  # bugünden kaç gün önce: enjekte edilen "hackathon" (3 gün)

# Oturum başlangıç saati ağırlıkları: gündüz ağırlıklı, ara sıra akşam, gece çok nadir.
HOUR_WEIGHTS = {9: 6, 10: 9, 11: 9, 12: 4, 13: 5, 14: 8, 15: 8, 16: 7, 17: 5, 18: 3,
                19: 2, 20: 3, 21: 3, 22: 2, 23: 1, 0: 0.3}

# (ad, dil, sahibi mi, fork mu, açıklama, README, lisans, topic'ler, etkin olduğu gün aralığı, ağırlık)
REPOS = [
    ("hava-durumu-api", "Python", True, False, "Şehir bazlı hava durumu servisi", True, "MIT",
     ["fastapi", "weather"], (180, 0), 5),
    ("kisisel-blog", "TypeScript", True, False, "Kişisel blog sitesi", True, None, [], (150, 20), 3),
    ("algoritma-notlari", "Python", True, False, None, True, None, [], (180, 60), 2),
    ("flutter-sayac", "Dart", True, False, None, False, None, [], (45, 30), 1),
    ("dotfiles", "Shell", True, False, "Geliştirme ortamı ayarları", True, None,
     ["dotfiles", "zsh"], (180, 0), 1),
    ("awesome-turkce", "Markdown", True, True, "Türkçe kaynak listesi (fork)", True, "CC0-1.0",
     [], (90, 80), 0.5),
    ("acik-kaynak-kutuphane", "Python", False, False, "Katkı yapılan açık kaynak proje", True,
     "Apache-2.0", ["library"], (70, 10), 0.7),
]

# README boyutu (bayt; None = README yok) ve arşiv durumu. Kısa README "içerik" kontrolünü
# geçmez; flutter-sayac arşivlenmiş bir deneme projesi.
REPO_EXTRAS = {
    "hava-durumu-api": (2400, False), "kisisel-blog": (900, False), "algoritma-notlari": (120, False),
    "flutter-sayac": (None, True), "dotfiles": (650, False), "awesome-turkce": (5100, False),
    "acik-kaynak-kutuphane": (3800, False),
}

# Dil başına bayt (GitHub Linguist gibi) ve kök dizinden tespit edilecek araçlar.
REPO_TECH = {
    "hava-durumu-api": ({"Python": 48200, "Dockerfile": 610, "Shell": 900},
                        ["Docker", "GitHub Actions", "pip", "pytest"]),
    "kisisel-blog": ({"TypeScript": 31500, "CSS": 7200, "HTML": 2100, "JavaScript": 1800},
                     ["ESLint", "Node.js (npm)", "TypeScript", "Vite"]),
    "algoritma-notlari": ({"Python": 12400, "C++": 5300}, []),
    "flutter-sayac": ({"Dart": 9800, "Kotlin": 400, "Swift": 300}, ["Flutter/Dart (pub)"]),
    "dotfiles": ({"Shell": 6400, "Vim Script": 1200}, ["Make"]),
    "awesome-turkce": ({}, []),
    "acik-kaynak-kutuphane": ({"Python": 210000}, ["GitHub Actions", "pyproject (Python)"]),
}

# Commit türü -> (ağırlık, örnek konular, satır aralığı)
KINDS = {
    "feat": (35, ["yeni uç nokta eklendi", "arama özelliği", "kullanıcı ayarları sayfası",
                  "önbellek desteği", "sayfalama eklendi", "karanlık tema"], (20, 220)),
    "fix": (25, ["boş girdide çökme düzeltildi", "tarih biçimi hatası", "yanlış saat dilimi",
                 "bellek sızıntısı giderildi", "eksik doğrulama"], (1, 30)),
    "docs": (10, ["README kurulum adımları", "API örnekleri", "yorum satırları güncellendi"], (2, 60)),
    "refactor": (10, ["servis katmanı ayrıldı", "tekrarlanan kod azaltıldı", "isimler düzeltildi"],
                 (10, 150)),
    "test": (10, ["birim testleri eklendi", "uç durum testi", "sahte istemci ile test"], (10, 120)),
    "chore": (10, ["bağımlılıklar güncellendi", "CI ayarı", "gitignore güncellendi"], (1, 15)),
}


def _utc_iso(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _message(rng: random.Random) -> tuple[str, str]:
    kind = rng.choices(list(KINDS), weights=[k[0] for k in KINDS.values()])[0]
    subject = rng.choice(KINDS[kind][1])
    # Herkes "tür: konu" biçimini kullanmaz: %30 düz cümle.
    return kind, (subject.capitalize() if rng.random() < 0.3 else f"{kind}: {subject}")


def _active_repos(days_before: int) -> list[tuple]:
    return [r for r in REPOS if r[8][0] >= days_before >= r[8][1]]


def generate(seed: int = SEED) -> dict:
    rng = random.Random(seed)  # yalnızca bu örnek; global rastgelelik kullanılmaz
    commits_by_repo: dict[str, list[dict]] = {r[0]: [] for r in REPOS}
    extra_contrib: dict[date, int] = {}  # commit dışı katkılar (PR, issue, inceleme)
    counter = 0

    def add_commit(repo: str, local: datetime, burst: bool = False) -> None:
        nonlocal counter
        counter += 1
        kind, msg = _message(rng)
        lo, hi = KINDS[kind][2]
        coauthored = rng.random() < 0.03
        if coauthored:
            msg += "\n\nCo-authored-by: demo-ortak <demo@example.invalid>"
        lines = rng.randint(lo, hi) * (3 if burst else 1)
        commits_by_repo[repo].append({
            "oid": hashlib.sha1(f"{seed}-{counter}".encode()).hexdigest(),
            "authored_at": _utc_iso(local),
            "message": msg,
            "additions": int(lines * rng.uniform(0.6, 1.0)),
            "deletions": int(lines * rng.uniform(0.0, 0.4)),
            "changed_files": rng.randint(1, 8),
            "is_coauthored": coauthored,
        })

    for days_before in range(DAYS, -1, -1):
        day = ANCHOR - timedelta(days=days_before)
        repos = _active_repos(days_before)
        if not repos or VACATION[0] >= days_before >= VACATION[1]:
            continue

        # Enjekte edilen anomali: 3 gün, günde 18-25 commit, 20:00'den gece yarısını geçene dek, tek repo.
        if BURST[0] >= days_before >= BURST[1]:
            start = datetime.combine(day, time(20, rng.randint(0, 30)), TZ)
            for k in range(rng.randint(18, 25)):
                add_commit("flutter-sayac", start + timedelta(minutes=k * rng.randint(9, 16)), burst=True)
            continue

        weekend = day.weekday() >= 5
        if rng.random() > (P_ACTIVE_WEEKEND if weekend else P_ACTIVE_WEEKDAY):
            if rng.random() < 0.03:
                extra_contrib[day] = extra_contrib.get(day, 0) + 1  # yalnız inceleme yapılan gün
            continue

        for _ in range(rng.choices([1, 2, 3], weights=[60, 30, 10])[0]):
            hour = rng.choices(list(HOUR_WEIGHTS), weights=list(HOUR_WEIGHTS.values()))[0]
            t = datetime.combine(day, time(hour, rng.randint(0, 59)), TZ)
            repo = rng.choices(repos, weights=[r[9] for r in repos])[0][0]
            for _ in range(rng.choices([1, 2, 3, 4, 5], weights=[30, 30, 20, 12, 8])[0]):
                add_commit(repo, t)
                t += timedelta(minutes=rng.randint(5, 45))
        if rng.random() < 0.15:
            extra_contrib[day] = extra_contrib.get(day, 0) + rng.randint(1, 3)  # PR/issue

    # Takvim: yerel güne göre commit sayısı + commit dışı katkılar (GitHub gibi).
    calendar: dict[date, int] = dict(extra_contrib)
    repos_out = []
    for name, lang, owner, fork, desc, readme, lic, topics, _window, _w in REPOS:
        commits = commits_by_repo[name]
        # Aynı gündeki oturum saatleri rastgele seçildi: pushed_at doğru olsun diye sırala.
        commits.sort(key=lambda c: c["authored_at"])
        for c in commits:
            local_day = datetime.fromisoformat(c["authored_at"]).astimezone(TZ).date()
            calendar[local_day] = calendar.get(local_day, 0) + 1
        first = commits[0]["authored_at"] if commits else _utc_iso(datetime.combine(ANCHOR, time(), TZ))
        repos_out.append({
            "node_id": f"DEMO_REPO_{name}", "name": name, "is_owner": owner, "is_fork": fork,
            "is_private": False, "primary_language": lang, "description": desc,
            "has_readme": readme, "license_spdx": lic, "topics": topics,
            "readme_bytes": REPO_EXTRAS[name][0], "is_archived": REPO_EXTRAS[name][1],
            "languages": REPO_TECH[name][0], "tools": REPO_TECH[name][1],
            "created_at": _utc_iso(datetime.fromisoformat(first) - timedelta(days=1)),
            "pushed_at": commits[-1]["authored_at"] if commits else first,
            "commits": commits,
        })

    burst_days = [ANCHOR - timedelta(days=d) for d in range(BURST[0], BURST[1] - 1, -1)]
    return {
        "_not": "Sentetik demo verisi (app/sync/demo_generator.py ile üretildi). Gerçek bir "
                "kişiye ait değildir; ML başarısını kanıtlamaz, yalnızca kodun çalıştığını gösterir.",
        "_seed": seed,
        "anchor_date": ANCHOR.isoformat(),  # DemoClient tarihleri bu günden bugüne kaydırır
        "_injected": [{
            "type": "burst",
            "start": burst_days[0].isoformat(),
            "end": burst_days[-1].isoformat(),
            "repo": "flutter-sayac",
            "note": "3 günlük hackathon: günde 18-25 commit, 20:00'de başlayıp gece yarısını "
                    "geçen tek uzun oturum, satır sayısı 3 kat.",
        }],
        "profile": {"node_id": "DEMO_USER_1", "login": "demo-gelistirici",
                    "created_at": "2024-03-01T09:00:00Z"},
        "repos": repos_out,
        "calendar": [{"day": d.isoformat(), "count": n} for d, n in sorted(calendar.items())],
    }


def to_json(data: dict) -> str:
    return json.dumps(data, ensure_ascii=False, indent=1) + "\n"


if __name__ == "__main__":
    out = Path(__file__).resolve().parent.parent.parent / "demo" / "demo_user.json"
    data = generate()
    out.write_text(to_json(data), encoding="utf-8")
    n = sum(len(r["commits"]) for r in data["repos"])
    print(f"{out} yazıldı: {len(data['repos'])} repo, {n} commit, {len(data['calendar'])} takvim günü")
