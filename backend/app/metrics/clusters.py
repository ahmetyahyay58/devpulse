"""Repo kümeleri: gözetimsiz k-means. Tanım: docs/metrikler.md "Repo kümeleri".

Etiketli veri yoktur; doğruluk ölçülmez. Küme adları merkezden şablonla üretilir (LLM yok).
"""
import math
from collections import Counter
from statistics import median

import numpy as np
from pydantic import BaseModel
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score
from sklearn.preprocessing import StandardScaler

from app.metrics.projects import ProjectOut
from app.metrics.sufficiency import Sufficiency

MIN_REPOS = 5
FIXED_K_BELOW = 10  # bundan az repoda k = 2 sabit
ACTIVE_DAYS = 90
DOCUMENTED_SCORE = 70
NO_PUSH_DAYS = 3650  # son push bilinmiyorsa "çok eski" sayılır

HOW = (
    "Kendi, fork olmayan repoların dört özellikle k-means ile gruplandı: commit sayısı (log), son "
    "push'tan bu yana gün (log), son 12 haftada commit atılan hafta oranı ve sağlık puanı. Özellikler "
    "önce ölçeklendi. Az repoda küme sayısı 2 sabittir; 10 ve üstünde siluet puanına göre 2-4 arası "
    "seçilir. Gözetimsiz bir yöntemdir: etiket yoktur, doğruluk ölçülmez. Adlar küme ortalarından "
    "kuralla verilir (son push 90 günden yeniyse Aktif; sağlık puanı 70 ve üstüyse belgeli)."
)


class ClusterOut(BaseModel):
    name: str
    repos: list[str]
    top_language: str | None
    median_commits: float
    median_days_since_push: float | None
    median_score: float | None


class ClustersOut(BaseModel):
    sufficiency: Sufficiency
    repo_count: int
    k: int | None
    silhouette: float | None  # yalnız k seçildiyse (10+ repo); betimleyici
    clusters: list[ClusterOut]
    summary: str
    how: str = HOW


def sufficiency(n: int) -> Sufficiency:
    if n < MIN_REPOS:
        return Sufficiency.NONE
    if n < FIXED_K_BELOW:
        return Sufficiency.LOW
    return Sufficiency.NORMAL


def features(p: ProjectOut) -> list[float]:
    days = p.days_since_push if p.days_since_push is not None else NO_PUSH_DAYS
    active_weeks = sum(1 for w in p.weekly_commits if w > 0) / max(len(p.weekly_commits), 1)
    return [math.log1p(p.commit_count), math.log1p(days), active_weeks, (p.score or 0) / 100]


def _choose_k(x: np.ndarray) -> tuple[int, float | None]:
    n = len(x)
    if n < FIXED_K_BELOW:
        return 2, None
    best: tuple[int, float] | None = None
    for k in range(2, min(4, n // 3) + 1):
        labels = KMeans(n_clusters=k, n_init=10, random_state=0).fit_predict(x)
        s = float(silhouette_score(x, labels))
        if best is None or s > best[1]:
            best = (k, s)
    return best  # type: ignore[return-value]


def _name(group: list[ProjectOut]) -> str:
    days = [p.days_since_push for p in group if p.days_since_push is not None]
    scores = [p.score for p in group if p.score is not None]
    activity = "Aktif" if days and median(days) <= ACTIVE_DAYS else "Durağan"
    if not scores:
        docs = "puanlanmamış"
    else:
        docs = "belgeli" if median(scores) >= DOCUMENTED_SCORE else "belgesi eksik"
    return f"{activity}, {docs}"


def build_clusters(projects: list[ProjectOut]) -> ClustersOut:
    repos = sorted((p for p in projects if p.is_owner and not p.is_fork), key=lambda p: p.name)
    n = len(repos)
    suff = sufficiency(n)
    if suff == Sufficiency.NONE:
        return ClustersOut(sufficiency=suff, repo_count=n, k=None, silhouette=None, clusters=[],
                           summary=f"Kümeleme için en az {MIN_REPOS} kendi repo gerekiyor (şu an {n}).")
    x = StandardScaler().fit_transform(np.array([features(p) for p in repos]))
    k, sil = _choose_k(x)
    labels = KMeans(n_clusters=k, n_init=10, random_state=0).fit_predict(x)
    groups = [[p for p, l in zip(repos, labels) if l == c] for c in range(k)]
    groups = [g for g in groups if g]
    groups.sort(key=lambda g: (-len(g), g[0].name))  # büyük küme önce; eşitlikte ada göre

    names = [_name(g) for g in groups]
    all_commits = median(p.commit_count for p in repos)
    dup = {nm for nm, c in Counter(names).items() if c > 1}
    clusters = []
    for g, nm in zip(groups, names):
        commits = median(p.commit_count for p in g)
        if nm in dup:
            nm += ", çok commit'li" if commits >= all_commits else ", az commit'li"
        days = [p.days_since_push for p in g if p.days_since_push is not None]
        scores = [p.score for p in g if p.score is not None]
        langs = Counter(p.language for p in g if p.language)
        clusters.append(ClusterOut(
            name=nm, repos=[p.name for p in g],
            top_language=min(langs, key=lambda l: (-langs[l], l)) if langs else None,
            median_commits=commits,
            median_days_since_push=median(days) if days else None,
            median_score=median(scores) if scores else None,
        ))
    return ClustersOut(
        sufficiency=suff, repo_count=n, k=k, silhouette=None if sil is None else round(sil, 2),
        clusters=clusters,
        summary=f"{n} kendi repo, benzerliklerine göre {len(clusters)} gruba ayrıldı.",
    )
