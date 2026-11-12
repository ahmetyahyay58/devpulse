"""Commit türleri dağılımı (docs/metrikler.md "Commit türleri"). Sınıflandırma app/classify'da."""
from collections import Counter
from dataclasses import dataclass
from datetime import datetime

from pydantic import BaseModel

from app.classify.classifier import classify_many
from app.classify.labels import APP_LABELS, LABEL_TR
from app.metrics import sufficiency
from app.metrics.sufficiency import Sufficiency

EXAMPLES_PER_TYPE = 5
ACCURACY_NOTE = (
    "Türler yaklaşık bir tahmindir: tutarlı bir test standardına göre %63 doğru (kappa 0,53, "
    "orta düzey). Tek tek commit'lerde yanılabilir; dağılım kabaca fikir verir."
)
HOW = (
    "Her commit mesajının ilk satırı altı türden birine ayrıldı. Önce önek (ör. 'fix:') ve "
    "Türkçe/İngilizce anahtar kelime kuralları denendi; karar verilemezse makine öğrenmesi "
    "modeli (harf parçası TF-IDF + lojistik regresyon, Türkçe commit'lerle eğitildi) karar verdi. "
    "Commit mesajları hiçbir dış hizmete gönderilmedi."
)


@dataclass(frozen=True)
class CommitText:
    message: str
    authored_at: datetime
    repo: str


class TypeExample(BaseModel):
    headline: str
    repo: str
    authored_at: datetime
    source: str  # kural | model | belirsiz
    reason: str


class TypeShare(BaseModel):
    label: str
    label_tr: str
    count: int
    share: float
    examples: list[TypeExample]  # en yeniden eskiye


class CommitTypesOut(BaseModel):
    total: int
    types: list[TypeShare]  # en sıktan aza; hiç olmayan türler de 0 ile listelenir
    by_source: dict[str, int]  # kural / model / belirsiz
    sufficiency: Sufficiency
    basis: str
    summary: str
    note: str = ACCURACY_NOTE
    how: str = HOW


def build_commit_types(commits: list[CommitText]) -> CommitTypesOut:
    ordered = sorted(commits, key=lambda c: c.authored_at, reverse=True)
    results = classify_many([c.message for c in ordered])
    counts = Counter(r.label for r in results)
    n = len(ordered)

    types = []
    for label in APP_LABELS:
        examples = [
            TypeExample(headline=c.message.strip().splitlines()[0][:120] if c.message.strip() else "",
                        repo=c.repo, authored_at=c.authored_at, source=r.source, reason=r.reason)
            for c, r in zip(ordered, results) if r.label == label
        ][:EXAMPLES_PER_TYPE]
        types.append(TypeShare(label=label, label_tr=LABEL_TR[label], count=counts[label],
                               share=counts[label] / n if n else 0.0, examples=examples))
    types.sort(key=lambda t: t.count, reverse=True)

    suff = sufficiency.commit_types(n)
    basis = f"{n} commit"
    if suff == Sufficiency.NONE:
        summary = f"Bu metrik için henüz yeterli veri yok ({basis})."
    else:
        top = types[0]
        summary = (f"Commit'lerin en çok '{top.label_tr}' türünde: {top.count} commit "
                   f"(%{round(100 * top.share)}).")
    return CommitTypesOut(total=n, types=types, by_source=dict(Counter(r.source for r in results)),
                          sufficiency=suff, basis=basis, summary=summary)
