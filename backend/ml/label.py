"""Komut satırında commit mesajı etiketleme aracı (kılavuz: docs/etiketler.md).

    py -m ml.label          # açık kaynak havuzu: ml/data/pool.jsonl -> ml/data/labels.jsonl
    py -m ml.label --own    # kendi commit'lerin: own.jsonl -> own_labels.jsonl (repoya girmez)

Her etiket hemen dosyaya eklenir; istediğin an çıkıp kaldığın yerden devam edebilirsin.
Tuşlar: 1-7 etiket, n not ekle, u son etiketi geri al, s atla, q çık.
"""
import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

DATA_DIR = Path(__file__).resolve().parent / "data"
LABELS = ["feat", "fix", "docs", "refactor", "test", "chore", "diger"]
KEYS = {str(i + 1): label for i, label in enumerate(LABELS)}
TARGET = 300  # açık kaynak havuzundan hedeflenen etiket sayısı
BODY_LINES = 12


# --- Saf yardımcılar (testlerle sınanır) -------------------------------------------------

def read_jsonl(path: Path) -> list[dict]:
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def labeled_ids(labels: list[dict]) -> set[str]:
    return {row["id"] for row in labels}


def next_item(pool: list[dict], labels: list[dict], skipped: set[str]) -> dict | None:
    """Henüz etiketlenmemiş ve bu oturumda atlanmamış ilk mesaj (havuz sırasıyla)."""
    done = labeled_ids(labels)
    return next((p for p in pool if p["id"] not in done and p["id"] not in skipped), None)


def parse_key(key: str) -> tuple[str, str | None]:
    """Tuşu eyleme çevirir: ("label", "fix") / ("note", None) / ("undo", None) / ..."""
    # ﻿: PowerShell'den aktarılan girdinin başındaki görünmez BOM karakteri.
    key = key.strip().lstrip("﻿").lower()
    if key in KEYS:
        return "label", KEYS[key]
    return {"n": ("note", None), "u": ("undo", None), "s": ("skip", None), "q": ("quit", None)}.get(
        key, ("unknown", None)
    )


def append_label(path: Path, item_id: str, label: str, note: str | None = None) -> None:
    row = {"id": item_id, "label": label, "note": note,
           "at": datetime.now(timezone.utc).isoformat(timespec="seconds")}
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(row, ensure_ascii=False) + "\n")


def undo_last(path: Path) -> dict | None:
    """Son etiketi dosyadan siler ve döner (yoksa None)."""
    rows = read_jsonl(path)
    if not rows:
        return None
    last = rows.pop()
    path.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows), encoding="utf-8")
    return last


def format_message(message: str) -> str:
    """İlk satır öne, gövde en fazla BODY_LINES satır."""
    lines = message.splitlines() or [""]
    body = [ln for ln in lines[1:] if ln.strip()]
    shown = body[:BODY_LINES]
    more = f"\n    ... (+{len(body) - BODY_LINES} satır)" if len(body) > BODY_LINES else ""
    return ">>> " + lines[0] + "".join("\n    " + ln for ln in shown) + more


# --- Etkileşimli döngü ----------------------------------------------------------------------

def run(pool_path: Path, labels_path: Path, target: int | None) -> None:
    pool = read_jsonl(pool_path)
    if not pool:
        raise SystemExit(f"Havuz yok: {pool_path} (önce: py -m ml.collect)")
    skipped: set[str] = set()
    menu = "  ".join(f"{k}={v}" for k, v in KEYS.items()) + "   n=not  u=geri al  s=atla  q=çık"
    pending_note: str | None = None

    while True:
        labels = read_jsonl(labels_path)
        goal = target or len(pool)
        if len(labels) >= goal:
            print(f"\nHedefe ulaşıldı: {len(labels)}/{goal}. Teşekkürler!")
            return
        item = next_item(pool, labels, skipped)
        if item is None:
            print("\nEtiketlenecek mesaj kalmadı (atlananlar bir sonraki çalıştırmada yeniden gelir).")
            return

        print(f"\n[{len(labels) + 1}/{goal}]  {item['repo']}")
        print(format_message(item["message"]))
        print(menu)
        try:
            action, label = parse_key(input("> "))
        except (EOFError, KeyboardInterrupt):  # Ctrl+C ya da girdi bitti: çıkış say
            action, label = "quit", None

        if action == "label":
            append_label(labels_path, item["id"], label, pending_note)
            pending_note = None
        elif action == "note":
            try:
                pending_note = input("not: ").strip() or None
            except (EOFError, KeyboardInterrupt):
                pending_note = None
        elif action == "undo":
            last = undo_last(labels_path)
            print(f"geri alındı: {last['id']} ({last['label']})" if last else "geri alınacak etiket yok")
        elif action == "skip":
            skipped.add(item["id"])
        elif action == "quit":
            print(f"Kaydedildi: {len(labels)} etiket. Kaldığın yerden: py -m ml.label")
            return
        else:
            print("Tanınmayan tuş.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Commit mesajı etiketle (docs/etiketler.md)")
    parser.add_argument("--own", action="store_true", help="kendi commit'lerini etiketle")
    args = parser.parse_args()
    if args.own:
        run(DATA_DIR / "own.jsonl", DATA_DIR / "own_labels.jsonl", target=None)
    else:
        run(DATA_DIR / "pool.jsonl", DATA_DIR / "labels.jsonl", target=TARGET)


if __name__ == "__main__":
    main()
