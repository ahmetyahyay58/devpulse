"""Genel Bakış: metrikleri hesaplar, her birine veri yeterliliği, özet cümlesi
(şablon, LLM yok) ve "nasıl hesaplandı" metni ekler. Saf fonksiyon: veritabanı bilgisi yok."""
from datetime import date

from pydantic import BaseModel

from app.metrics import activity, sufficiency
from app.metrics.sufficiency import Sufficiency

HOW_CONTINUITY = (
    "Aktif gün: yerel saatine göre en az bir commit attığın gün. Güncel seri: bugün ya da dün "
    "aktifsen oradan geriye kesintisiz aktif gün sayısı. Oran: son 90 gündeki aktif gün / 90 "
    "(ilk commit'in daha yeniyse o günden bugüne geçen gün)."
)
HOW_RHYTHM = (
    "Commit'lerinin yazar zamanı senin saat dilimine çevrilip saat ve haftanın gününe göre "
    "sayıldı. Gece: 00:00-05:59. Hafta sonu: Cumartesi ve Pazar."
)
HOW_SESSIONS = (
    "Commit'ler zamana göre sıralandı; arada 2 saatten uzun boşluk varsa yeni oturum sayıldı "
    "(kural, makine öğrenmesi değil). Oturum süresi ilk ve son commit arasıdır; gerçek çalışma "
    "süresi bundan uzun olabilir. Ortalama yerine medyan kullanıldı. En sık başlangıç saati, "
    "oturumun ilk commit'inin saatidir."
)
NOT_ENOUGH = "Bu metrik için henüz yeterli veri yok ({basis})."


class Kpi(BaseModel):
    total_commits: int
    active_days: int
    repos: int
    current_streak: int
    commits_last_30_days: int


class Continuity(BaseModel):
    current_streak: int
    longest_streak: int
    active_ratio_90d: float | None
    sufficiency: Sufficiency
    basis: str
    summary: str
    how: str = HOW_CONTINUITY


class RhythmOut(BaseModel):
    by_hour: list[int]
    by_weekday: list[int]
    peak_hour: int | None
    night_share: float | None
    weekend_share: float | None
    sufficiency: Sufficiency
    basis: str
    summary: str
    how: str = HOW_RHYTHM


class SessionsOut(BaseModel):
    count: int
    commits_per_session: float | None
    session_minutes: float | None
    commits_per_active_day: float | None
    lines_per_commit: float | None
    longest_minutes: float | None  # en uzun oturumun süresi
    longest_day: date | None  # en uzun oturumun başladığı gün (yerel)
    common_start_hour: int | None  # oturumların en sık başladığı saat
    sufficiency: Sufficiency
    basis: str
    summary: str
    how: str = HOW_SESSIONS


class Overview(BaseModel):
    timezone: str
    timezone_known: bool
    today: date
    kpi: Kpi
    continuity: Continuity
    rhythm: RhythmOut
    sessions: SessionsOut


def _pct(x: float | None) -> str:
    return "-" if x is None else f"%{round(x * 100)}"


def build_overview(
    points: list[activity.CommitPoint], tz: str | None, today: date, repo_count: int
) -> Overview:
    times = activity.to_local(points, tz)
    days = activity.active_days(times)
    n = len(times)

    # --- Süreklilik
    cur = activity.current_streak(days, today)
    longest = activity.longest_streak(days)
    ratio = activity.active_ratio(days, today)
    since_first = (today - min(days)).days + 1 if days else 0
    c_suff = sufficiency.continuity(len(days), since_first)
    c_basis = f"{len(days)} aktif gün"
    c_summary = (
        NOT_ENOUGH.format(basis=c_basis) if c_suff == Sufficiency.NONE
        # Sayıdan sonra ek yok: Türkçede ek okunuşa göre değişir (%1'i, %12'si, %0'ı).
        else f"Son 90 günde aktif gün oranın {_pct(ratio)}; en uzun serin {longest} gün."
    )

    # --- Ritim
    r = activity.rhythm(times)
    r_suff = sufficiency.rhythm(n, timezone_known=tz is not None)
    r_basis = f"{n} commit" + ("" if tz else ", saat dilimi bilinmiyor (UTC varsayıldı)")
    r_summary = (
        NOT_ENOUGH.format(basis=r_basis) if r_suff == Sufficiency.NONE
        else f"Commit'lerin en çok {r.peak_hour:02d}:00-{r.peak_hour:02d}:59 arasında. "
        f"Gece (00-06) oranı {_pct(r.night_share)}, hafta sonu oranı {_pct(r.weekend_share)}."
    )

    # --- Oturum ve yoğunluk
    sess = activity.sessions(times)
    i = activity.intensity(times, points, sess)
    longest_s = activity.longest_session(sess)
    s_suff = sufficiency.sessions(len(sess))
    s_basis = f"{len(sess)} oturum"
    s_summary = (
        NOT_ENOUGH.format(basis=s_basis) if s_suff == Sufficiency.NONE
        else f"Bir oturumda genellikle {i.commits_per_session:g} commit atıyorsun; "
        f"oturumların medyan süresi {round(i.session_minutes)} dakika."
    )

    last_30 = sum(1 for t in times if (today - t.date()).days < 30)
    return Overview(
        timezone=tz or "UTC",
        timezone_known=tz is not None,
        today=today,
        kpi=Kpi(
            total_commits=n,
            active_days=len(days),
            repos=repo_count,
            current_streak=cur,
            commits_last_30_days=last_30,
        ),
        continuity=Continuity(
            current_streak=cur, longest_streak=longest, active_ratio_90d=ratio,
            sufficiency=c_suff, basis=c_basis, summary=c_summary,
        ),
        rhythm=RhythmOut(
            by_hour=r.by_hour, by_weekday=r.by_weekday, peak_hour=r.peak_hour,
            night_share=r.night_share, weekend_share=r.weekend_share,
            sufficiency=r_suff, basis=r_basis, summary=r_summary,
        ),
        sessions=SessionsOut(
            count=len(sess),
            commits_per_session=i.commits_per_session,
            session_minutes=i.session_minutes,
            commits_per_active_day=i.commits_per_active_day,
            lines_per_commit=i.lines_per_commit,
            longest_minutes=longest_s.minutes if longest_s else None,
            longest_day=longest_s.start.date() if longest_s else None,
            common_start_hour=activity.common_start_hour(sess),
            sufficiency=s_suff, basis=s_basis, summary=s_summary,
        ),
    )
