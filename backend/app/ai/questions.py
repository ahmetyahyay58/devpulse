"""Hazır sorular ve şablon cevapları (docs/ai_katmani.md, "Sorular").

Serbest metin soru yok: kullanıcı yalnızca buradaki kimliklerden birini seçer. Her sorunun bir
şablon cevabı vardır; LLM yoksa ya da başarısız olursa gösterilen budur (ana yol). Şablonlar
metrik katmanının hazır özet cümlelerini kullanır; bu cümleler telefona gider, LLM'e gitmez.
"""
from collections.abc import Callable
from dataclasses import dataclass

from app.ai.facts import CHECK_TR, Context
from app.metrics.sufficiency import Sufficiency


@dataclass(frozen=True)
class Question:
    id: str
    kind: str  # "sor" (Sor balonu ve AI yorumu çipleri) | "neden" | "ipucu"
    text: str  # kullanıcıya görünen ve LLM'e giden soru
    template: Callable[[Context], str]
    keys: tuple[str, ...] | None = None  # LLM'e giden sayılar; None: hepsi (en az veri ilkesi)


def _strength(c: Context) -> str:
    ov, pr = c.overview, c.projects
    if ov.continuity.sufficiency == Sufficiency.NONE:
        return "Güçlü yanını söylemek için henüz yeterli veri yok; birkaç gün daha commit attıkça netleşir."
    if ov.continuity.longest_streak >= 7:
        return f"En uzun serin {ov.continuity.longest_streak} gün: ara vermeden çalışabildiğini gösteriyor."
    if (pr.summary.average_score or 0) >= 70:
        return f"Projelerinin ortalama sağlık puanı {pr.summary.average_score}: belgelerin büyük ölçüde tamam."
    top = next((t for t in c.commit_types.types if t.count > 0), None)
    if top:
        return f"Commit'lerinin en büyük payı \"{top.label_tr}\" türünde; bu alanda düzenli iş çıkarıyorsun."
    return "Güçlü yanını söylemek için henüz yeterli veri yok."


def _improve(c: Context) -> str:
    missing = c.projects.summary.missing_counts
    if missing and max(missing.values()) > 0:
        key, n = max(missing.items(), key=lambda kv: kv[1])
        return (f"Puanlanan projelerinden {n} tanesinde {CHECK_TR.get(key, key)} eksik; "
                "en hızlı kazanç bunu tamamlamak.")
    if c.overview.continuity.current_streak == 0:
        return "Şu an aktif bir serin yok; kısa da olsa düzenli günler süreklilik metriğini en çok yükseltir."
    return "Belirgin bir eksik görünmüyor; mevcut düzenini korumak yeterli."


def _tip(c: Context) -> str:
    if c.overview.continuity.current_streak == 0 and c.overview.kpi.total_commits > 0:
        return "Bugün küçük bir commit bile serini yeniden başlatır."
    suggestion = next((p.suggestion for p in c.projects.projects if p.suggestion), None)
    return f"Projelerinden birinde: {suggestion}" if suggestion else _improve(c)


def _why(section: str) -> Callable[[Context], str]:
    def answer(c: Context) -> str:
        m = getattr(c.overview, section)
        return f"{m.summary} Hesap toplam {m.basis} üzerinden yapıldı."
    return answer


def _goal_badge(c: Context) -> str:
    locked = [b for b in c.badges if not b.unlocked]
    if not locked:
        return "Bütün rozetleri açtın; şimdilik yeni bir rozet hedefi yok."
    b = max(locked, key=lambda b: (b.current / b.target, -b.target))
    return f"En yakın rozet: {b.name} ({b.current}/{b.target}). Koşul: {b.description}"


def _goal_week(c: Context) -> str:
    cont = c.overview.continuity
    if cont.sufficiency == Sufficiency.NONE:
        return "Hedef koymak için henüz yeterli veri yok; bu hafta 3 farklı günde küçük bir commit atmayı dene."
    if cont.current_streak == 0:
        return "Şu an aktif bir serin yok. Bu hafta için gerçekçi hedef: 3 farklı günde küçük de olsa bir commit."
    if cont.current_streak < cont.longest_streak:
        need = cont.longest_streak - cont.current_streak + 1
        return (f"Güncel serin {cont.current_streak} gün, en uzun serin {cont.longest_streak} gün. "
                f"Rekoru geçmek için {need} gün daha art arda commit gerekir; bu hafta her gün küçük bir adım yeter.")
    return (f"Şu an en uzun serindesin: {cont.current_streak} gün. Bu hafta hedefi seriyi korumak olsun; "
            "her gün küçük bir commit yeter.")


def _goal_project(c: Context) -> str:
    candidates = [p for p in c.projects.projects
                  if p.is_owner and not p.is_fork and p.score is not None and p.suggestion]
    if not candidates:
        return "Puanlanan projelerinde belirgin bir eksik görünmüyor; yeni bir projeye başlamak için iyi bir zaman."
    p = max(candidates, key=lambda p: (p.commit_count, -(p.score or 0)))
    return f"Önce en çok emek verdiğin projeyi tamamla: {p.name} (puan {p.score}). İlk adım: {p.suggestion}"


# Soruya göre giden sayı grupları: alakasız sayıyı göndermemek hem doğruluğu hem gizliliği artırır.
CONTINUITY = ("toplam_commit", "aktif_gun", "guncel_seri_gun", "en_uzun_seri_gun", "sureklilik_guveni")
RHYTHM = ("en_yogun_saat", "gece_payi_yuzde", "hafta_sonu_payi_yuzde", "ritim_guveni")
SESSIONS = ("oturum_sayisi", "oturum_basi_commit", "ortalama_oturum_dk", "oturum_guveni")
TYPES = ("toplam_commit", "commit_turleri_yuzde", "tur_guveni")
PROJECTS = ("puanlanan_proje", "ortalama_saglik", "eksik_proje")
BADGES = ("acik_rozet", "kilitli_rozetler")

QUESTIONS: list[Question] = [
    Question("ozet", "sor", "Çalışma alışkanlığımı kısaca özetler misin?",
             lambda c: f"{c.overview.continuity.summary} {c.overview.rhythm.summary}"),
    Question("guclu", "sor", "Güçlü yanım ne?", _strength),
    Question("gelistir", "sor", "Neyi geliştirebilirim?", _improve),
    Question("projeler", "sor", "Projelerimi nasıl iyileştiririm?", lambda c: c.projects.summary.summary, PROJECTS),
    Question("ritim", "sor", "Genelde ne zaman çalışıyorum?", lambda c: c.overview.rhythm.summary, RHYTHM + SESSIONS),
    Question("neden_sureklilik", "neden", "Süreklilik sonucum neden böyle?", _why("continuity"), CONTINUITY),
    Question("neden_ritim", "neden", "Ritim sonucum neden böyle?", _why("rhythm"), RHYTHM),
    Question("neden_oturum", "neden", "Oturum sonucum neden böyle?", _why("sessions"), SESSIONS),
    Question("neden_turler", "neden", "Commit türlerim neden böyle dağılmış?",
             lambda c: f"{c.commit_types.summary} Hesap toplam {c.commit_types.basis} üzerinden yapıldı.", TYPES),
    Question("neden_proje", "neden", "Proje sağlık puanlarım neden böyle?", lambda c: c.projects.summary.summary,
             PROJECTS),
    Question("ipucu", "ipucu", "Bana tek cümlelik bir öneri verir misin?", _tip, CONTINUITY + PROJECTS),
    # Hedef koçu (Başarımlar sekmesi)
    Question("hedef_rozet", "hedef", "Sıradaki rozete nasıl ulaşırım?", _goal_badge, BADGES),
    Question("hedef_hafta", "hedef", "Bu hafta için gerçekçi hedefim ne olabilir?", _goal_week,
             CONTINUITY + ("yil_degisim_yuzde", "yil_guveni")),
    Question("hedef_proje", "hedef", "Hangi projemi önce tamamlamalıyım?", _goal_project, PROJECTS),
]
BY_ID = {q.id: q for q in QUESTIONS}
