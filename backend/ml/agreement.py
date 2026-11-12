"""Etiketleyiciler arası uyuşma: geliştirici, yapay zekâ (Claude, kör) ve yazarın öneki.

    py -m ml.agreement

Yapay zekâ etiketleri (tr_gold_llm_labels.jsonl) yalnızca bu ölçüm içindir: eğitimde ve tasarım
kararlarında kullanılmaz. Test kümesinin etiketleri insandır (tr_gold_labels.jsonl).
"""
from collections import Counter

from sklearn.metrics import cohen_kappa_score

from app.classify.labels import LABEL_TR, to_app_label
from ml.collect import DATA_DIR
from ml.gold import GOLD_LABELS, GOLD_POOL
from ml.label import read_jsonl

LLM_LABELS = DATA_DIR / "tr_gold_llm_labels.jsonl"


def compare(a: dict, b: dict, merge: bool) -> tuple[int, float, float]:
    ids = sorted(set(a) & set(b))
    f = to_app_label if merge else (lambda x: x)
    xa, xb = [f(a[i]) for i in ids], [f(b[i]) for i in ids]
    return len(ids), sum(p == q for p, q in zip(xa, xb)) / len(ids), cohen_kappa_score(xa, xb)


def main() -> None:
    human = {r["id"]: r["label"] for r in read_jsonl(GOLD_LABELS)}
    llm = {r["id"]: r["label"] for r in read_jsonl(LLM_LABELS)}
    author = {p["id"]: p["author_label"] for p in read_jsonl(GOLD_POOL)}

    print("| çift | mesaj | 7 sınıf uyuşma / kappa | 6 sınıf uyuşma / kappa |\n|---|---|---|---|")
    for name, a, b in (("Yapay zekâ – geliştirici", llm, human),
                       ("Yazar öneki – geliştirici", author, human),
                       ("Yapay zekâ – yazar öneki", llm, author)):
        n, acc7, k7 = compare(a, b, merge=False)
        _, acc6, k6 = compare(a, b, merge=True)
        print(f"| {name} | {n} | %{100 * acc7:.0f} / {k7:.2f} | %{100 * acc6:.0f} / {k6:.2f} |")

    ids = sorted(set(llm) & set(human))
    diffs = Counter((human[i], llm[i]) for i in ids if human[i] != llm[i])
    print("\nEn sık uyuşmazlıklar (geliştirici -> yapay zekâ):",
          [(f"{LABEL_TR[a]} -> {LABEL_TR[b]}", n) for (a, b), n in diffs.most_common(6)])


if __name__ == "__main__":
    main()
