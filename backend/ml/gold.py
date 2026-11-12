"""Elle etiketlenecek Türkçe "altın" küme ve değerlendirmesi.

    py -m ml.gold sample     # test repolarından 100 mesaj -> ml/data/tr_gold_pool.jsonl
    py -m ml.label --tr      # kör etiketleme (önek ve repo gösterilmez)
    py -m ml.label --own     # kendi 33 commit'in
    py -m ml.gold evaluate   # kural / model / hibrit, tanımlarımıza göre

Mesajlar yalnızca TEST repolarından seçilir (model eğitimde görmedi). Değerlendirmede de
yalnızca eğitim kısmıyla eğitilmiş model kullanılır; uygulamadaki son model (tüm veriyle
eğitilmiş) burada kullanılmaz, yoksa test mesajlarını eğitimde görmüş olurdu.
"""
import json
import random
import sys
from collections import Counter

from app.classify.labels import LABEL_TR
from app.classify.rules import classify_rules
from ml.collect import DATA_DIR, write_jsonl
from ml.label import read_jsonl
from ml.train import CLASSES, char_model, load, split

GOLD_POOL = DATA_DIR / "tr_gold_pool.jsonl"
GOLD_LABELS = DATA_DIR / "tr_gold_labels.jsonl"
OWN_POOL = DATA_DIR / "own.jsonl"
OWN_LABELS = DATA_DIR / "own_labels.jsonl"
SEED = 20261112
PER_CLASS = {"feat": 18, "fix": 18, "docs": 17, "refactor": 17, "chore": 18, "test": 12}
STRONG = ("önek", "geri alma", "dosya silme", "test ile", "Markdown")


def sample() -> list[dict]:
    _, test = split(load())  # yalnız test repoları
    rng = random.Random(SEED)
    picked = []
    for label, n in PER_CLASS.items():
        candidates = [r for r in test if r["label"] == label]
        picked += rng.sample(candidates, min(n, len(candidates)))
    rng.shuffle(picked)
    # Etiketleme aracına giden kayıt: yazarın öneki (label) ve gerçek repo adı yok -> kör etiketleme.
    return [{"id": r["id"], "repo": "türkçe örnek", "message": r["text"], "author_label": r["label"]}
            for r in picked]


def predictions(texts: list[str], model) -> dict[str, list[str]]:
    """Karşılaştırılan sistemlerin tahminleri (eşik yok: model hep en olası sınıfı söyler)."""
    rules = [classify_rules(t) for t in texts]
    model_top = list(model.predict(texts))
    return {
        "Yalnız kurallar (karar veremezse Belirsiz)": [r.label if r else "diger" for r in rules],
        "Yalnız model": model_top,
        "Kural önce, sonra model": [r.label if r else m for r, m in zip(rules, model_top)],
        "Kesin kural önce, sonra model": [
            r.label if r and r.reason.startswith(STRONG) else m for r, m in zip(rules, model_top)],
    }


def evaluate_set(name: str, pool: list[dict], labels: list[dict], model) -> list[dict]:
    gold = {row["id"]: row["label"] for row in labels}
    items = [p for p in pool if p["id"] in gold]
    texts = [p["message"] for p in items]
    y = [gold[p["id"]] for p in items]
    rows = []
    for system, pred in predictions(texts, model).items():
        rows.append({
            "küme": f"{name} ({len(items)})",
            "sistem": system,
            "doğruluk": f"{sum(p == g for p, g in zip(pred, y)) / len(y):.2f}" if y else "-",
        })
    return rows


def main() -> None:
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "sample":
        rows = sample()
        write_jsonl(GOLD_POOL, rows)
        print(f"{len(rows)} mesaj -> {GOLD_POOL}")
        print("yazar öneki dağılımı:", dict(Counter(r["author_label"] for r in rows)))
        return
    if cmd != "evaluate":
        raise SystemExit("kullanım: py -m ml.gold sample | evaluate")

    train, _ = split(load())
    model = char_model().fit([r["text"] for r in train], [r["label"] for r in train])
    rows = []
    gold_pool, gold_labels = read_jsonl(GOLD_POOL), read_jsonl(GOLD_LABELS)
    rows += evaluate_set("Türkçe altın küme", gold_pool, gold_labels, model)
    rows += evaluate_set("Kendi commit'lerin", read_jsonl(OWN_POOL), read_jsonl(OWN_LABELS), model)
    cols = list(rows[0])
    print("\n".join(["| " + " | ".join(cols) + " |", "|" + "---|" * len(cols)]
                    + ["| " + " | ".join(r[c] for c in cols) + " |" for r in rows]))

    # Otomatik etiketin gürültüsü: yazarın öneki bizim tanımımızla ne sıklıkla uyuşuyor?
    author = {p["id"]: p["author_label"] for p in gold_pool}
    pairs = [(author[g["id"]], g["label"]) for g in gold_labels if g["id"] in author]
    if pairs:
        agree = sum(a == h for a, h in pairs) / len(pairs)
        print(f"\nYazarın öneki ile senin etiketin uyuşma oranı: %{100 * agree:.0f} ({len(pairs)} mesaj)")
        print("En sık uyuşmazlıklar (yazar -> sen):",
              [(f"{LABEL_TR[a]} -> {LABEL_TR[h]}", n) for (a, h), n in Counter(
                  (a, h) for a, h in pairs if a != h).most_common(5)])


if __name__ == "__main__":
    main()
