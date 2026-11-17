"""LLM'e giden toplu sayılar (docs/ai_katmani.md, "Giden sayılar").

Tek yer burasıdır: hem LLM isteği hem uygulamadaki "LLM'e giden veri" ekranı bu fonksiyonun
çıktısını kullanır. Girdi olarak metrik katmanının hazır çıktıları alınır; buradan yalnız
sayılar ve genel kategori adları (dil, commit türü) çıkar. Repo adı, commit mesajı, örnek
commit'ler, kullanıcı adı ve özet cümleleri bilerek alınmaz.
"""
from dataclasses import dataclass

from app.metrics.achievements import BadgeOut, YearCompareOut
from app.metrics.anomaly import AnomaliesOut
from app.metrics.commit_types import CommitTypesOut
from app.metrics.overview import Overview
from app.metrics.projects import ProjectsOut
from app.metrics.technology import TechnologyOut

# Proje sağlığı denetimlerinin Türkçe adları (anahtarlar app/metrics/projects.py CHECKS ile aynı).
CHECK_TR = {
    "readme": "README", "readme_content": "README içeriği", "description": "açıklama",
    "license": "lisans", "topics": "topic",
}


@dataclass(frozen=True)
class Context:
    """Bir kullanıcının o anki metrikleri; hem sayılar hem şablon cevaplar buradan okunur."""

    overview: Overview
    commit_types: CommitTypesOut
    anomalies: AnomaliesOut
    projects: ProjectsOut
    technology: TechnologyOut
    year: YearCompareOut
    badges: tuple[BadgeOut, ...] = ()


def _pct(share: float | None) -> int | None:
    return None if share is None else round(share * 100)


def build_facts(ctx: Context) -> dict:
    ov, ct, pr, tech, year = ctx.overview, ctx.commit_types, ctx.projects, ctx.technology, ctx.year
    change = year.stats[0].change_pct if year.stats else None  # ilk satır: commit sayısı
    return {
        "toplam_commit": ov.kpi.total_commits,
        "aktif_gun": ov.kpi.active_days,
        "repo_sayisi": ov.kpi.repos,
        "guncel_seri_gun": ov.continuity.current_streak,
        "en_uzun_seri_gun": ov.continuity.longest_streak,
        "sureklilik_guveni": ov.continuity.sufficiency.value,
        "en_yogun_saat": ov.rhythm.peak_hour,
        "gece_payi_yuzde": _pct(ov.rhythm.night_share),
        "hafta_sonu_payi_yuzde": _pct(ov.rhythm.weekend_share),
        "ritim_guveni": ov.rhythm.sufficiency.value,
        "oturum_sayisi": ov.sessions.count,
        "oturum_basi_commit": ov.sessions.commits_per_session,
        "ortalama_oturum_dk": None if ov.sessions.session_minutes is None else round(ov.sessions.session_minutes),
        "oturum_guveni": ov.sessions.sufficiency.value,
        "commit_turleri_yuzde": {t.label_tr: _pct(t.share) for t in ct.types if t.count > 0},
        "tur_guveni": ct.sufficiency.value,
        "olagan_disi_gun": len(ctx.anomalies.flagged),
        "puanlanan_proje": pr.summary.scored_count,
        "ortalama_saglik": pr.summary.average_score,
        "eksik_proje": {CHECK_TR.get(k, k): n for k, n in pr.summary.missing_counts.items() if n > 0},
        "dil_sayisi": tech.language_count,
        "baskin_dil": tech.dominant,
        "baskin_dil_yuzde": _pct(tech.dominant_share),
        "cesitlilik": None if tech.diversity is None else round(tech.diversity, 2),
        "teknoloji_guveni": tech.sufficiency.value,
        "yil_degisim_yuzde": change,
        "yil_guveni": year.sufficiency.value,
        "acik_rozet": sum(1 for b in ctx.badges if b.unlocked),
        # Rozet adları uygulamanın genel adlarıdır ("Bir haftalık seri"), kişiyi tanımlamaz.
        "kilitli_rozetler": {b.name: f"{b.current}/{b.target}" for b in ctx.badges if not b.unlocked},
    }
