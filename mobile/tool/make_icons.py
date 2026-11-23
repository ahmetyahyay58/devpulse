"""DevPulse simgeleri (çalıştır: py tool/make_icons.py, mobile/ içinde): mobile/assets/icon/app_icon.png'den Android (eski + uyarlanabilir) ve web."""
from pathlib import Path

from PIL import Image, ImageStat

M = Path(__file__).resolve().parent.parent  # mobile/
src = Image.open(M / "assets/icon/app_icon.png").convert("RGB")

# Yuvarlak karenin iç kısmı: kedi halkası ve nabız çizgisi. "DevPulse" yazısı dışarıda kalır
# (yuvarlak maskede kesiliyor, simge boyutunda da okunmuyor).
inner = src.crop((150, 110, 870, 730))  # yazı y=740'ta başlar
w, h = inner.size
# Zemin: kenarların ortancası.
border = [inner.getpixel((x, y)) for x in range(0, w, 8) for y in (0, h - 1)] + \
         [inner.getpixel((x, y)) for y in range(0, h, 8) for x in (0, w - 1)]
bg = tuple(sorted(c[i] for c in border)[len(border) // 2] for i in range(3))
bg_hex = "#{:02X}{:02X}{:02X}".format(*bg)


def soft_paste(dst, img, box):
    """Kırpılan parçayı kenarları yumuşak geçişle yapıştırır (zeminle arasında çizgi kalmasın)."""
    from PIL import ImageFilter
    w_, h_ = img.size
    f = max(8, min(w_, h_) // 10)
    m = Image.new("L", (w_, h_), 0)
    m.paste(255, (f, f, w_ - f, h_ - f))
    dst.paste(img, box, m.filter(ImageFilter.GaussianBlur(f / 2)))


# Uyarlanabilir ön katman: 108dp tuval, içerik genişliği %58, ortada (görünen daire ~%67).
canvas = Image.new("RGB", (1024, 1024), bg)
cw = int(1024 * 0.58)
ch = cw * h // w
soft_paste(canvas, inner.resize((cw, ch), Image.LANCZOS), ((1024 - cw) // 2, (1024 - ch) // 2))

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

# Uygulama içi logo (giriş ekranı): yazısız kare, içerik daha geniş; köşeleri uygulamada yuvarlanır.
mark = Image.new("RGB", (1024, 1024), bg)
mw = int(1024 * 0.86)
mh = mw * h // w
soft_paste(mark, inner.resize((mw, mh), Image.LANCZOS), ((1024 - mw) // 2, (1024 - mh) // 2))
(M / "assets/brand").mkdir(exist_ok=True)
mark.resize((288, 288), Image.LANCZOS).save(M / "assets/brand/logo_mark.png", optimize=True)
