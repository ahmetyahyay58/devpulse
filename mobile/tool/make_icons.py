"""DevPulse simgeleri (çalıştır: py tool/make_icons.py, mobile/ içinde): mobile/assets/icon/app_icon.png'den Android (eski + uyarlanabilir) ve web."""
from pathlib import Path

from PIL import Image, ImageStat

M = Path(__file__).resolve().parent.parent  # mobile/
src = Image.open(M / "assets/icon/app_icon.png").convert("RGB")

# Yuvarlak karenin iç kısmı (kalp ve nabız çizgisi burada); kenarları maske dışında kalır.
inner = src.crop((150, 150, 874, 874))
border = [inner.getpixel((x, y)) for x in range(0, 724, 8) for y in (0, 723)] + \
         [inner.getpixel((x, y)) for y in range(0, 724, 8) for x in (0, 723)]
bg = tuple(sum(c[i] for c in border) // len(border) for i in range(3))
bg_hex = "#{:02X}{:02X}{:02X}".format(*bg)

# Uyarlanabilir ön katman: 108dp tuval, iç kısım %62 boyutta ortada (görünen alan ~%67).
canvas = Image.new("RGB", (1024, 1024), bg)
size = int(1024 * 0.62)
canvas.paste(inner.resize((size, size), Image.LANCZOS), ((1024 - size) // 2,) * 2)

res = M / "android/app/src/main/res"
dens = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
for d, k in dens.items():
    folder = res / f"mipmap-{d}"
    folder.mkdir(exist_ok=True)
    legacy = src.resize((int(48 * k),) * 2, Image.LANCZOS)  # Android 7 ve öncesi: tam görsel
    legacy.save(folder / "ic_launcher.png")
    canvas.resize((int(108 * k),) * 2, Image.LANCZOS).save(folder / "ic_launcher_foreground.png")

anydpi = res / "mipmap-anydpi-v26"
anydpi.mkdir(exist_ok=True)
(anydpi / "ic_launcher.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@color/ic_launcher_background"/>\n'
    '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
    '</adaptive-icon>\n', encoding="utf-8")
values = res / "values"
values.mkdir(exist_ok=True)
(values / "ic_launcher_background.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
    f'    <color name="ic_launcher_background">{bg_hex}</color>\n</resources>\n', encoding="utf-8")

# Web: favicon ve PWA simgeleri (maskable: uyarlanabilir tuval).
web = M / "web"
src.resize((32, 32), Image.LANCZOS).save(web / "favicon.png")
for n in (192, 512):
    src.resize((n, n), Image.LANCZOS).save(web / "icons" / f"Icon-{n}.png")
    canvas.resize((n, n), Image.LANCZOS).save(web / "icons" / f"Icon-maskable-{n}.png")

# Önizleme: daire maskeli hali (yalnız kontrol için, scratchpad'e).
from PIL import ImageDraw
prev = canvas.resize((432, 432), Image.LANCZOS)
mask = Image.new("L", (432, 432), 0)
ImageDraw.Draw(mask).ellipse((72, 72, 360, 360), fill=255)  # 72dp görünen alan
out = Image.new("RGB", (432, 432), (255, 255, 255))
out.paste(prev, (0, 0), mask)
(M / "build").mkdir(exist_ok=True)
out.crop((60, 60, 372, 372)).save(M / "build" / "icon_preview.png")
print("ok", bg_hex)
