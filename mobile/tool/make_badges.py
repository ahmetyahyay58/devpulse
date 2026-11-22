"""DevPulse rozet görselleri: mobile/assets/badges/<anahtar>.svg üretir.

Tasarım: emaye rozet (enamel pin). Kalın metal kenar + düz emaye renkli küçük bir sahne.
Şekil kategoriyi söyler: madalyon = zaman/ritim, altıgen = kod, kalkan = proje, elmas = işbirliği.
Kenar rengi uygulamada seviyeye göre değiştirilir: dosyadaki RIM_LIGHT / RIM_DARK değerleri
(çelik) Flutter'da bronz, gümüş ya da altınla yer değiştirir (lib/achievements/badge_art.dart).
Bütün çizimler bu dosyada elle yazılmıştır (dışarıdan alınmış görsel yok).

Çalıştırma: py tool/make_badges.py
"""
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "badges"
RIM_LIGHT, RIM_DARK = "#8A93A8", "#3A4052"  # çelik; seviyeli rozette uygulama değiştirir

# --- Çerçeveler: (dış şekil, iç şekil) aynı merkezde, 200x200 tuval -------------------

def _hex(r: float) -> str:
    import math
    pts = [(100 + r * math.cos(math.radians(a)), 100 + r * math.sin(math.radians(a))) for a in range(-90, 270, 60)]
    return "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + " Z"


def _shield(s: float) -> str:
    # s: 1.0 dış, küçüldükçe iç
    def p(x, y):
        return f"{100 + (x - 100) * s:.1f},{100 + (y - 100) * s:.1f}"
    return (f"M{p(100, 8)} C{p(130, 22)} {p(160, 24)} {p(184, 22)} L{p(184, 96)} "
            f"C{p(184, 146)} {p(146, 178)} {p(100, 194)} C{p(54, 178)} {p(16, 146)} {p(16, 96)} "
            f"L{p(16, 22)} C{p(40, 24)} {p(70, 22)} {p(100, 8)} Z")


def _diamond(r: float, k: float = 14) -> str:
    return (f"M100,{100 - r} Q{100 + k},{100 - r + k} {100 + r},100 Q{100 + r - k},{100 + k} 100,{100 + r} "
            f"Q{100 - k},{100 + r - k} {100 - r},100 Q{100 - r + k},{100 - k} 100,{100 - r} Z")


SHAPES = {
    "medallion": ('<circle cx="100" cy="100" r="94"/>', '<circle cx="100" cy="100" r="79"/>'),
    "hexagon": (f'<path d="{_hex(96)}"/>', f'<path d="{_hex(80)}"/>'),
    "shield": (f'<path d="{_shield(1.0)}"/>', f'<path d="{_shield(0.84)}"/>'),
    "diamond": (f'<path d="{_diamond(96)}"/>', f'<path d="{_diamond(79, 11)}"/>'),
}


def badge(shape: str, art: str, defs: str = "") -> str:
    outer, inner = SHAPES[shape]
    fill = lambda el, attrs: el.replace("/>", f" {attrs}/>", 1)
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
<defs>
<linearGradient id="rim" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{RIM_LIGHT}"/><stop offset="1" stop-color="{RIM_DARK}"/></linearGradient>
<clipPath id="in">{inner}</clipPath>
{defs}
</defs>
{fill(outer, 'fill="url(#rim)"')}
{fill(outer, 'fill="none" stroke="#000000" stroke-opacity="0.35" stroke-width="2"')}
<g clip-path="url(#in)">
{art}
</g>
{fill(inner, 'fill="none" stroke="#000000" stroke-opacity="0.45" stroke-width="3"')}
{fill(inner, 'fill="none" stroke="#FFFFFF" stroke-opacity="0.18" stroke-width="1.5" transform="translate(0,1.5)"')}
</svg>
"""


def stars(points) -> str:
    return "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#FFF6D6"/>' for x, y, r in points)


# --- Sahneler -----------------------------------------------------------------------

ART = {}

# Gece Kuşu: lacivert gece, hilal ay, yıldızlar, dalda baykuş (amber gözler).
ART["night_owl"] = ("medallion", """
<rect width="200" height="200" fill="url(#sky)"/>
""" + stars([(52, 52, 2), (70, 34, 1.4), (140, 46, 1.6), (156, 72, 1.2), (38, 84, 1.2), (120, 30, 1.1)]) + """
<path d="M150,48 a26,26 0 1 0 14,46 a20,20 0 1 1 -14,-46 Z" fill="#FFE7A3"/>
<path d="M30,160 Q100,138 176,150" stroke="#4A2F23" stroke-width="7" fill="none" stroke-linecap="round"/>
<path d="M150,150 l14,-10" stroke="#4A2F23" stroke-width="4" stroke-linecap="round"/>
<ellipse cx="96" cy="118" rx="34" ry="38" fill="#7A5A44"/>
<path d="M66,92 L72,70 L86,86 Z M126,92 L120,70 L106,86 Z" fill="#7A5A44"/>
<ellipse cx="96" cy="128" rx="20" ry="22" fill="#C9A27E"/>
<path d="M84,124 q4,4 8,0 M96,132 q4,4 8,0 M84,140 q4,4 8,0 M100,120 q4,4 8,0" stroke="#7A5A44" stroke-width="2" fill="none"/>
<circle cx="83" cy="102" r="13" fill="#F4E3C8"/><circle cx="109" cy="102" r="13" fill="#F4E3C8"/>
<circle cx="83" cy="102" r="8" fill="#FFB020"/><circle cx="109" cy="102" r="8" fill="#FFB020"/>
<circle cx="83" cy="102" r="4" fill="#1A1430"/><circle cx="109" cy="102" r="4" fill="#1A1430"/>
<circle cx="85" cy="100" r="1.6" fill="#FFFFFF"/><circle cx="111" cy="100" r="1.6" fill="#FFFFFF"/>
<path d="M92,110 L96,118 L100,110 Z" fill="#F0A030"/>
<path d="M82,152 l-4,8 M90,154 l0,8 M102,154 l0,8 M110,152 l4,8" stroke="#F0A030" stroke-width="3" stroke-linecap="round"/>
""", """<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#141A4A"/><stop offset="1" stop-color="#3B2A6E"/></linearGradient>""")

# Erkenci: şafak, ufuktan doğan güneş, tel üstünde küçük kuş.
ART["early_bird"] = ("medallion", """
<rect width="200" height="200" fill="url(#dawn)"/>
<g fill="#FFD27A" opacity="0.55">
<path d="M100,132 L60,40 L76,38 Z"/><path d="M100,132 L124,36 L140,40 Z"/><path d="M100,132 L28,86 L36,74 Z"/><path d="M100,132 L172,74 L164,86 Z"/>
</g>
<circle cx="100" cy="134" r="36" fill="#FFB347"/>
<circle cx="100" cy="134" r="27" fill="#FFD27A"/>
<rect x="0" y="134" width="200" height="70" fill="#5E3A6E"/>
<path d="M0,150 Q60,138 110,150 T200,146 L200,200 L0,200 Z" fill="#43285A"/>
<path d="M14,100 Q100,112 188,96" stroke="#2A2038" stroke-width="2.5" fill="none"/>
<ellipse cx="120" cy="96" rx="14" ry="11" fill="#2A2038"/>
<circle cx="131" cy="88" r="7" fill="#2A2038"/>
<path d="M137,88 l8,1 l-8,3 Z" fill="#F08A24"/>
<circle cx="132" cy="86" r="1.6" fill="#FFF6D6"/>
<path d="M108,94 l-12,-4 l10,8 Z" fill="#2A2038"/>
<path d="M116,106 l-1,6 M122,106 l1,6" stroke="#2A2038" stroke-width="2"/>
""", """<linearGradient id="dawn" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#6FA8DC"/><stop offset="0.55" stop-color="#F7B7A3"/><stop offset="1" stop-color="#FFC98A"/></linearGradient>""")

# Böcek Avcısı (altıgen, kod): koyu terminal, kod satırları, büyüteç altında böcek.
ART["bug_hunter"] = ("hexagon", """
<rect width="200" height="200" fill="#12261E"/>
<g stroke-linecap="round" stroke-width="5">
<path d="M40,52 h40" stroke="#3FBF7F" opacity="0.5"/><path d="M90,52 h36" stroke="#7FD4FF" opacity="0.4"/>
<path d="M52,66 h54" stroke="#3FBF7F" opacity="0.35"/><path d="M40,80 h24" stroke="#FFC857" opacity="0.4"/>
<path d="M120,150 h40" stroke="#3FBF7F" opacity="0.35"/><path d="M40,164 h60" stroke="#7FD4FF" opacity="0.3"/>
</g>
<g transform="translate(92,108)">
<path d="M-26,-8 l-14,-8 M-26,4 l-16,0 M-24,16 l-14,10 M26,-8 l14,-8 M26,4 l16,0 M24,16 l14,10" stroke="#1B1B1B" stroke-width="5" stroke-linecap="round"/>
<path d="M-8,-28 q-6,-12 -14,-14 M8,-28 q6,-12 14,-14" stroke="#1B1B1B" stroke-width="4" fill="none" stroke-linecap="round"/>
<ellipse cx="0" cy="6" rx="26" ry="32" fill="#E5484D"/>
<path d="M0,-26 V38" stroke="#1B1B1B" stroke-width="3"/>
<circle cx="-11" cy="0" r="5" fill="#1B1B1B"/><circle cx="12" cy="12" r="6" fill="#1B1B1B"/><circle cx="-10" cy="22" r="4" fill="#1B1B1B"/>
<ellipse cx="0" cy="-26" rx="15" ry="11" fill="#1B1B1B"/>
<circle cx="-5" cy="-28" r="2.4" fill="#FFFFFF"/><circle cx="5" cy="-28" r="2.4" fill="#FFFFFF"/>
</g>
<circle cx="124" cy="92" r="30" fill="#BFE9FF" fill-opacity="0.22" stroke="#E8EEF5" stroke-width="7"/>
<path d="M106,78 a22,22 0 0 1 16,-8" stroke="#FFFFFF" stroke-width="4" fill="none" stroke-linecap="round" opacity="0.8"/>
<path d="M146,114 L170,140" stroke="#8C6A3F" stroke-width="12" stroke-linecap="round"/>
""")

# Maraton (madalyon, ritim): pist şeritleri, koşan figür, kronometre.
ART["marathon"] = ("medallion", """
<rect width="200" height="200" fill="#1E5F74"/>
<path d="M-10,150 Q100,96 210,150 L210,210 L-10,210 Z" fill="#C8553D"/>
<path d="M-10,164 Q100,112 210,164" stroke="#F5E6D3" stroke-width="2.5" fill="none" opacity="0.8"/>
<path d="M-10,182 Q100,130 210,182" stroke="#F5E6D3" stroke-width="2.5" fill="none" opacity="0.8"/>
<circle cx="146" cy="58" r="22" fill="#F5E6D3"/><circle cx="146" cy="58" r="17" fill="#1E5F74"/>
<rect x="141" y="30" width="10" height="7" rx="2" fill="#F5E6D3"/>
<path d="M146,58 L146,46 M146,58 L156,62" stroke="#FFC857" stroke-width="3.5" stroke-linecap="round"/>
<path d="M58,104 a26,26 0 0 1 42,-22" stroke="#FFC857" stroke-width="4" fill="none" stroke-dasharray="2 7" stroke-linecap="round"/>
<g stroke="#FFF6E8" stroke-width="9" stroke-linecap="round" stroke-linejoin="round" fill="none">
<path d="M96,92 L88,124"/>
<path d="M88,124 L104,140 L98,160"/>
<path d="M88,124 L72,138 L56,134"/>
<path d="M94,100 L112,110 L124,100"/>
<path d="M94,100 L78,104 L70,118"/>
</g>
<circle cx="100" cy="78" r="10" fill="#FFF6E8"/>
<path d="M30,96 h22 M22,110 h26 M32,124 h16" stroke="#FFF6E8" stroke-width="3.5" stroke-linecap="round" opacity="0.6"/>
""")

# Vitrin (kalkan, proje): cam vitrin, kaide üstünde parlayan yıldız.
ART["showcase"] = ("shield", """
<rect width="200" height="200" fill="#2B2350"/>
<rect x="44" y="40" width="112" height="104" rx="6" fill="#BFD8FF" fill-opacity="0.12" stroke="#BFD8FF" stroke-opacity="0.6" stroke-width="3"/>
<path d="M56,52 l20,0 l-26,34 Z" fill="#FFFFFF" opacity="0.18"/>
<rect x="66" y="132" width="68" height="14" rx="3" fill="#8B6BD6"/>
<rect x="56" y="144" width="88" height="14" rx="3" fill="#6A4FB8"/>
<path d="M100,62 L110,86 L136,88 L116,104 L123,130 L100,116 L77,130 L84,104 L64,88 L90,86 Z" fill="#FFD25A" stroke="#C99A1E" stroke-width="3" stroke-linejoin="round"/>
<path d="M100,72 L106,88" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round" opacity="0.7"/>
<path d="M146,58 l3,-8 l3,8 l8,3 l-8,3 l-3,8 l-3,-8 l-8,-3 Z" fill="#FFF6D6"/>
<path d="M50,118 l2,-5 l2,5 l5,2 l-5,2 l-2,5 l-2,-5 l-5,-2 Z" fill="#FFF6D6" opacity="0.8"/>
""")

# Gizli: koyu madalyon, kabartma soru işareti (gerçek rozet ne olursa olsun aynı).
ART["secret"] = ("medallion", """
<rect width="200" height="200" fill="url(#mist)"/>
""" + stars([(50, 60, 1.4), (150, 56, 1.8), (140, 150, 1.2), (58, 140, 1.4)]) + """
<path d="M76,78 a24,24 0 1 1 34,22 c-8,4 -10,8 -10,18 v6" stroke="#0E0B1C" stroke-width="18" fill="none" stroke-linecap="round" transform="translate(0,3)"/>
<path d="M76,78 a24,24 0 1 1 34,22 c-8,4 -10,8 -10,18 v6" stroke="#B9A7FF" stroke-width="18" fill="none" stroke-linecap="round"/>
<circle cx="100" cy="149" r="10" fill="#0E0B1C" transform="translate(0,3)"/>
<circle cx="100" cy="149" r="10" fill="#B9A7FF"/>
""", """<radialGradient id="mist" cx="0.5" cy="0.4" r="0.7"><stop offset="0" stop-color="#3A2E6E"/><stop offset="1" stop-color="#151128"/></radialGradient>""")


import math


def gear(cx: float, cy: float, r: float, teeth: int, fill: str, hole: str) -> str:
    pts = []
    for i in range(teeth * 2):
        a = math.pi * i / teeth
        rr = r if i % 2 == 0 else r * 0.78
        for da in (-0.32, 0.32):
            aa = a + da * math.pi / teeth
            pts.append(f"{cx + rr * math.cos(aa):.1f},{cy + rr * math.sin(aa):.1f}")
    return (f'<path d="M{" L".join(pts)} Z" fill="{fill}"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r * 0.32:.1f}" fill="{hole}"/>')


def flame(cx: float, base: float, h: float, w: float, fill: str) -> str:
    return (f'<path d="M{cx},{base} C{cx - w},{base} {cx - w * 1.1},{base - h * 0.45} {cx - w * 0.35},{base - h * 0.75} '
            f'C{cx - w * 0.4},{base - h * 0.5} {cx - w * 0.1},{base - h * 0.45} {cx},{base - h} '
            f'C{cx + w * 0.3},{base - h * 0.7} {cx + w * 1.1},{base - h * 0.5} {cx + w},{base - h * 0.2} '
            f'C{cx + w * 0.9},{base} {cx + w * 0.4},{base} {cx},{base} Z" fill="{fill}"/>')


def grad(id_: str, top: str, bottom: str) -> str:
    return (f'<linearGradient id="{id_}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/>'
            f'<stop offset="1" stop-color="{bottom}"/></linearGradient>')


SPARK = lambda x, y, s=1, c="#FFF6D6": (f'<path transform="translate({x},{y}) scale({s})" '
                                         f'd="M0,-8 L2,-2 L8,0 L2,2 L0,8 L-2,2 L-8,0 L-2,-2 Z" fill="{c}"/>')

# --- Süreklilik ve zaman (madalyon) ---

ART["streak7"] = ("medallion", '<rect width="200" height="200" fill="url(#bg)"/>'
    + flame(100, 150, 96, 40, "#FF7A1A") + flame(100, 150, 64, 26, "#FFC23D") + flame(100, 150, 32, 13, "#FFF1B8")
    + "".join(f'<circle cx="{46 + i * 18}" cy="168" r="5" fill="#FFC23D"/>' for i in range(7)),
    grad("bg", "#3A1220", "#6E1F25"))

ART["streak30"] = ("medallion", '<rect width="200" height="200" fill="url(#bg)"/>'
    + "".join(f'<circle cx="{100 + 66 * math.cos(math.radians(-90 + i * 12)):.1f}" '
              f'cy="{100 + 66 * math.sin(math.radians(-90 + i * 12)):.1f}" r="3.4" fill="#9FD8FF"/>' for i in range(30))
    + flame(100, 146, 100, 42, "#3D7BFF") + flame(100, 146, 70, 28, "#8FD0FF") + flame(100, 146, 36, 14, "#FFFFFF"),
    grad("bg", "#120E3A", "#2C1B5E"))

ART["regular"] = ("medallion", '<rect width="200" height="200" fill="#163A3A"/>'
    '<rect x="44" y="50" width="112" height="104" rx="10" fill="#F2F7F2"/>'
    '<rect x="44" y="50" width="112" height="22" rx="10" fill="#2FA36B"/><rect x="44" y="62" width="112" height="10" fill="#2FA36B"/>'
    '<rect x="66" y="40" width="8" height="20" rx="4" fill="#2C3E3E"/><rect x="126" y="40" width="8" height="20" rx="4" fill="#2C3E3E"/>'
    + "".join(f'<rect x="{52 + c * 15}" y="{80 + r * 17}" width="11" height="11" rx="2" '
              f'fill="{["#BFE6CF", "#5CC08B", "#2FA36B", "#1D7A4D"][(c * 3 + r * 5) % 4]}"/>'
              for r in range(4) for c in range(7)))

ART["hours24"] = ("medallion", '<rect width="200" height="200" fill="#1B1F3B"/>'
    + "".join(
        f'<path d="M100,100 L{100 + 74 * math.cos(math.radians(-90 + i * 15 - 7)):.1f},{100 + 74 * math.sin(math.radians(-90 + i * 15 - 7)):.1f} '
        f'A74,74 0 0 1 {100 + 74 * math.cos(math.radians(-90 + i * 15 + 7)):.1f},{100 + 74 * math.sin(math.radians(-90 + i * 15 + 7)):.1f} Z" '
        f'fill="{["#1E2A6E", "#3550B8", "#6FA8DC", "#FFD27A", "#FFB347", "#F07B4A", "#7B4FB8", "#2A2F7A"][i // 3]}"/>'
        for i in range(24))
    + '<circle cx="100" cy="100" r="50" fill="#F4F1FA"/>'
    + "".join(f'<rect x="98.5" y="54" width="3" height="{9 if i % 3 == 0 else 5}" fill="#1B1F3B" '
              f'transform="rotate({i * 30} 100 100)"/>' for i in range(12))
    + '<path d="M100,100 L100,66" stroke="#1B1F3B" stroke-width="5" stroke-linecap="round"/>'
      '<path d="M100,100 L126,112" stroke="#E5484D" stroke-width="4" stroke-linecap="round"/>'
      '<circle cx="100" cy="100" r="5" fill="#1B1F3B"/>')

ART["new_year"] = ("medallion", '<rect width="200" height="200" fill="url(#bg)"/>'
    + "".join(f'<path d="M{cx},{cy} l{r * math.cos(math.radians(a)):.1f},{r * math.sin(math.radians(a)):.1f}" '
              f'stroke="{c}" stroke-width="3.5" stroke-linecap="round"/>'
              for cx, cy, r, c in ((62, 62, 26, "#FF6FA8"), (140, 54, 22, "#FFD25A"), (150, 104, 16, "#7FD4FF"))
              for a in range(0, 360, 30))
    + '<rect x="62" y="96" width="68" height="74" rx="8" fill="#FFFFFF"/>'
      '<rect x="62" y="96" width="68" height="20" rx="8" fill="#E5484D"/><rect x="62" y="108" width="68" height="8" fill="#E5484D"/>'
      '<path d="M88,134 L98,126 L98,160 M88,160 H108" stroke="#2A2038" stroke-width="7" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
    + SPARK(40, 120, 0.8) + SPARK(164, 150, 0.7),
    grad("bg", "#0F1240", "#2E1A5C"))

ART["leet"] = ("medallion", '<rect width="200" height="200" fill="#0D1117"/>'
    '<rect x="34" y="54" width="132" height="92" rx="10" fill="#161B22" stroke="#3FBF7F" stroke-width="3"/>'
    '<rect x="34" y="54" width="132" height="18" rx="9" fill="#21262D"/>'
    '<circle cx="48" cy="63" r="3.5" fill="#E5484D"/><circle cx="60" cy="63" r="3.5" fill="#FFC857"/><circle cx="72" cy="63" r="3.5" fill="#3FBF7F"/>'
    '<path d="M50,90 l14,10 l-14,10" stroke="#3FBF7F" stroke-width="5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
    '<rect x="72" y="104" width="22" height="6" rx="2" fill="#3FBF7F"/>'
    '<circle cx="138" cy="112" r="22" fill="#F5E6D3"/><circle cx="138" cy="112" r="18" fill="#0D1117"/>'
    '<path d="M138,112 L144,101 M138,112 L126,124" stroke="#3FBF7F" stroke-width="3.5" stroke-linecap="round"/>'
    '<circle cx="138" cy="112" r="2.5" fill="#3FBF7F"/>')

ART["comeback"] = ("medallion", '<rect width="200" height="200" fill="url(#bg)"/>'
    '<path d="M-10,150 L50,96 L86,128 L124,84 L210,156 L210,210 L-10,210 Z" fill="#2E5E4E"/>'
    '<path d="M-10,170 Q100,140 210,172 L210,210 L-10,210 Z" fill="#3E7A5E"/>'
    '<path d="M60,74 A44,44 0 1 1 64,128" stroke="#FFFFFF" stroke-width="10" fill="none" stroke-linecap="round"/>'
    '<path d="M50,128 L68,116 L72,138 Z" fill="#FFFFFF"/>'
    + "".join(f'<ellipse cx="{x}" cy="{y}" rx="4" ry="6" fill="#FFE7A3" transform="rotate(-20 {x} {y})"/>'
              for x, y in ((86, 162), (100, 154), (114, 150), (128, 144))),
    grad("bg", "#7FB8E0", "#F7C9A0"))

ART["weekend"] = ("medallion", '<rect width="200" height="200" fill="url(#bg)"/>'
    '<circle cx="146" cy="58" r="20" fill="#FFE27A"/>'
    '<rect x="0" y="120" width="200" height="80" fill="#2E86C1"/><rect x="0" y="148" width="200" height="60" fill="#F2D49B"/>'
    '<path d="M20,128 q14,-6 28,0 t28,0 M110,132 q14,-6 28,0 t28,0" stroke="#BFE3F7" stroke-width="3" fill="none"/>'
    '<path d="M64,170 L90,120 M90,120 L134,128 M84,150 L132,158 L120,184 M132,158 L140,184" stroke="#8C5A2B" stroke-width="6" stroke-linecap="round" fill="none"/>'
    '<path d="M92,122 L132,130 L124,152 L84,146 Z" fill="#E5484D"/>'
    '<path d="M96,128 L128,134" stroke="#FFFFFF" stroke-width="5"/><path d="M90,140 L124,146" stroke="#FFFFFF" stroke-width="5"/>'
    '<path d="M40,150 Q40,96 58,60" stroke="#6B4A2B" stroke-width="7" fill="none" stroke-linecap="round"/>'
    '<path d="M58,60 q-30,-6 -40,12 q20,-8 40,-12 q-8,-28 -32,-30 q22,10 32,30 q16,-24 40,-20 q-26,4 -40,20 q30,0 40,22 q-22,-18 -40,-22" fill="#3FA34D"/>',
    grad("bg", "#8FD3FF", "#FFE9C2"))

ART["twelve_months"] = ("medallion", '<rect width="200" height="200" fill="#1B1F2E"/>'
    + "".join(
        f'<path d="M{100 + 76 * math.cos(math.radians(-90 + i * 30 + 2)):.1f},{100 + 76 * math.sin(math.radians(-90 + i * 30 + 2)):.1f} '
        f'A76,76 0 0 1 {100 + 76 * math.cos(math.radians(-90 + i * 30 + 28)):.1f},{100 + 76 * math.sin(math.radians(-90 + i * 30 + 28)):.1f} '
        f'L{100 + 48 * math.cos(math.radians(-90 + i * 30 + 28)):.1f},{100 + 48 * math.sin(math.radians(-90 + i * 30 + 28)):.1f} '
        f'A48,48 0 0 0 {100 + 48 * math.cos(math.radians(-90 + i * 30 + 2)):.1f},{100 + 48 * math.sin(math.radians(-90 + i * 30 + 2)):.1f} Z" '
        f'fill="{["#7FB8E0", "#7FB8E0", "#7FD49B", "#3FBF7F", "#5CC08B", "#FFD25A", "#FFC23D", "#FFB347", "#F08A24", "#D96A2B", "#C0553A", "#9FC4E8"][i]}"/>'
        for i in range(12))
    + '<circle cx="100" cy="100" r="40" fill="#F4F1FA"/>'
      '<path d="M82,100 L96,114 L120,88" stroke="#2FA36B" stroke-width="9" fill="none" stroke-linecap="round" stroke-linejoin="round"/>')

# --- Kod (altıgen) ---

TYPE_COLORS = ["#3987E5", "#D95926", "#199E70", "#C98500", "#D55181", "#008300"]  # Genel Bakış commit türleri

ART["all_types"] = ("hexagon", '<rect width="200" height="200" fill="#2A2238"/>'
    '<path d="M100,40 C150,40 176,74 170,108 C166,130 146,128 136,124 C122,118 112,130 120,146 C128,162 112,170 96,168 C54,164 30,132 34,100 C38,66 64,40 100,40 Z" fill="#E8D7B8"/>'
    '<ellipse cx="128" cy="140" rx="9" ry="7" fill="#2A2238"/>'
    + "".join(f'<circle cx="{x}" cy="{y}" r="11" fill="{c}"/>'
              for (x, y), c in zip(((66, 78), (96, 62), (128, 70), (148, 96), (60, 112), (84, 140)), TYPE_COLORS))
    + '<path d="M44,170 L104,108" stroke="#6B4A2B" stroke-width="7" stroke-linecap="round"/>'
      '<path d="M104,108 l10,-10 l6,6 l-10,10 Z" fill="#B0B6C2"/><path d="M114,98 q10,-12 18,-8 q-2,10 -12,14 Z" fill="#3987E5"/>')

ART["less_is_more"] = ("hexagon", '<rect width="200" height="200" fill="#1F1A2E"/>'
    + "".join(f'<rect x="40" y="{50 + i * 16}" width="{w}" height="8" rx="4" fill="{c}"/>'
              for i, (w, c) in enumerate(((120, "#E5484D"), (96, "#E5484D"), (112, "#E5484D"), (70, "#3FBF7F"))))
    + '<path d="M36,90 H170" stroke="#FFFFFF" stroke-width="2" stroke-dasharray="6 5" opacity="0.6"/>'
      '<g transform="translate(134,132) rotate(-30)">'
      '<circle cx="-22" cy="20" r="12" fill="none" stroke="#FFC857" stroke-width="6"/>'
      '<circle cx="-22" cy="-20" r="12" fill="none" stroke="#FFC857" stroke-width="6"/>'
      '<path d="M-12,14 L34,-8 L32,-2 L-8,20 Z M-12,-14 L34,8 L32,2 L-8,-20 Z" fill="#DDE3EA"/>'
      '<circle cx="2" cy="0" r="3.5" fill="#1F1A2E"/></g>'
      '<path d="M56,150 h16 M56,164 h10" stroke="#E5484D" stroke-width="5" stroke-linecap="round"/>')

ART["tester"] = ("hexagon", '<rect width="200" height="200" fill="#20163A"/>'
    '<path d="M80,40 H120 M88,40 V88 L56,150 Q50,166 66,166 H134 Q150,166 144,150 L112,88 V40" stroke="#E8EEF5" stroke-width="6" fill="#BFE9FF" fill-opacity="0.1" stroke-linejoin="round"/>'
    '<path d="M70,124 L130,124 L144,150 Q150,166 134,166 H66 Q50,166 56,150 Z" fill="#D55181"/>'
    '<circle cx="86" cy="140" r="6" fill="#FFB3D1"/><circle cx="108" cy="148" r="4" fill="#FFB3D1"/><circle cx="118" cy="134" r="5" fill="#FFB3D1"/>'
    '<circle cx="100" cy="106" r="4" fill="#BFE9FF" opacity="0.7"/><circle cx="106" cy="92" r="3" fill="#BFE9FF" opacity="0.6"/>'
    '<circle cx="146" cy="62" r="20" fill="#2FA36B"/>'
    '<path d="M136,62 L144,70 L158,54" stroke="#FFFFFF" stroke-width="5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>')

ART["small_steps"] = ("hexagon", '<rect width="200" height="200" fill="url(#bg)"/>'
    + "".join(f'<rect x="{30 + i * 28}" y="{148 - i * 24}" width="{170 - i * 28}" height="{60 + i * 24}" fill="{c}"/>'
              for i, c in enumerate(("#4C6A92", "#5B7DAA", "#6E90BE", "#86A7D2", "#A3C0E6")))
    + "".join(f'<ellipse cx="{x}" cy="{y}" rx="5" ry="8" fill="#FFE7A3" transform="rotate(70 {x} {y})"/>'
              for x, y in ((46, 140), (74, 116), (102, 92), (130, 68)))
    + '<path d="M150,48 L158,36 L166,48 Z" fill="#FFD25A"/><rect x="157" y="48" width="2.5" height="18" fill="#FFD25A"/>',
    grad("bg", "#1D2B4A", "#2E4672"))

ART["polyglot"] = ("hexagon", '<rect width="200" height="200" fill="#1E2433"/>'
    '<path d="M36,56 h70 a12,12 0 0 1 12,12 v34 a12,12 0 0 1 -12,12 h-44 l-16,14 v-14 h-10 a12,12 0 0 1 -12,-12 v-34 a12,12 0 0 1 12,-12 Z" fill="#3987E5"/>'
    '<path d="M58,74 l-10,11 l10,11 M84,74 l10,11 l-10,11" stroke="#FFFFFF" stroke-width="5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
    '<path d="M164,84 h-62 a12,12 0 0 0 -12,12 v34 a12,12 0 0 0 12,12 h38 l16,14 v-14 h8 a12,12 0 0 0 12,-12 v-34 a12,12 0 0 0 -12,-12 Z" fill="#C98500"/>'
    '<path d="M116,100 q-8,0 -8,8 v4 q0,4 -4,4 q4,0 4,4 v4 q0,8 8,8 M146,100 q8,0 8,8 v4 q0,4 4,4 q-4,0 -4,4 v4 q0,8 -8,8" stroke="#FFFFFF" stroke-width="4.5" fill="none" stroke-linecap="round"/>'
    '<path d="M70,140 h44 a10,10 0 0 1 10,10 v18 a10,10 0 0 1 -10,10 h-44 a10,10 0 0 1 -10,-10 v-18 a10,10 0 0 1 10,-10 Z" fill="#199E70"/>'
    '<path d="M80,152 h12 M80,160 h24 M80,168 h16" stroke="#FFFFFF" stroke-width="3.5" stroke-linecap="round"/>')

# --- Proje (kalkan) ---

ART["docs"] = ("shield", '<rect width="200" height="200" fill="#24304A"/>'
    '<path d="M100,64 C82,54 54,54 40,60 V148 C56,142 82,142 100,152 Z" fill="#F7F1E3"/>'
    '<path d="M100,64 C118,54 146,54 160,60 V148 C144,142 118,142 100,152 Z" fill="#EDE4CF"/>'
    '<path d="M100,64 V152" stroke="#C9B994" stroke-width="2.5"/>'
    + "".join(f'<path d="M50,{76 + i * 13} q22,-4 42,2" stroke="#8A9BB8" stroke-width="3" fill="none" stroke-linecap="round"/>' for i in range(5))
    + "".join(f'<path d="M108,{78 + i * 13} q22,-6 42,-2" stroke="#8A9BB8" stroke-width="3" fill="none" stroke-linecap="round"/>' for i in range(5))
    + '<path d="M134,56 v42 l8,-7 l8,7 v-42 Z" fill="#E5484D"/>')

ART["license"] = ("shield", '<rect width="200" height="200" fill="#3A2A22"/>'
    '<rect x="52" y="52" width="96" height="104" rx="4" fill="#F4E8CC"/>'
    '<rect x="44" y="44" width="112" height="14" rx="7" fill="#D9C49A"/><rect x="44" y="150" width="112" height="14" rx="7" fill="#D9C49A"/>'
    + "".join(f'<path d="M64,{76 + i * 12} h{[72, 60, 66, 40][i]}" stroke="#9A8664" stroke-width="3.5" stroke-linecap="round"/>' for i in range(4))
    + '<path d="M120,136 l-8,30 l12,-8 l8,10 l4,-30 Z" fill="#B23A3A"/>'
      '<circle cx="128" cy="130" r="17" fill="#C8443F"/><circle cx="128" cy="130" r="11" fill="none" stroke="#8E2A2A" stroke-width="2.5"/>'
      '<path d="M122,130 l4,4 l8,-9" stroke="#F4E8CC" stroke-width="3" fill="none" stroke-linecap="round"/>')

ART["topics"] = ("shield", '<rect width="200" height="200" fill="#1F2E3A"/>'
    '<path d="M44,70 L92,58 L132,98 L96,134 L56,94 Z" fill="#3987E5" transform="rotate(-8 90 96)"/>'
    '<circle cx="72" cy="78" r="6" fill="#1F2E3A"/>'
    '<path d="M72,78 Q56,56 72,44" stroke="#E8EEF5" stroke-width="2.5" fill="none"/>'
    '<path d="M86,104 L134,92 L170,128 L134,164 L98,128 Z" fill="#199E70"/>'
    '<circle cx="114" cy="112" r="6" fill="#1F2E3A"/>'
    '<path d="M124,126 h22 M124,136 h14" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round"/>')

ART["automation"] = ("shield", '<rect width="200" height="200" fill="#202838"/>'
    + gear(82, 92, 34, 10, "#8FA3BF", "#202838") + gear(130, 128, 24, 8, "#FFB347", "#202838")
    + '<path d="M72,80 L96,92 L72,104 Z" fill="#FFFFFF"/>'
      '<path d="M48,150 a52,52 0 0 0 70,14" stroke="#3FBF7F" stroke-width="5" fill="none" stroke-linecap="round"/>'
      '<path d="M112,156 l10,8 l-12,4 Z" fill="#3FBF7F"/>')

ART["container"] = ("shield", '<rect width="200" height="200" fill="url(#bg)"/>'
    '<path d="M-10,150 q20,-8 40,0 t40,0 t40,0 t40,0 t40,0 V210 H-10 Z" fill="#1F5F8B"/>'
    '<path d="M38,128 H162 L148,152 H52 Z" fill="#2B2F3A"/>'
    + "".join(f'<rect x="{x}" y="{y}" width="36" height="20" rx="2" fill="{c}"/>'
              f'<path d="M{x + 6},{y + 4} v12 M{x + 13},{y + 4} v12 M{x + 20},{y + 4} v12 M{x + 27},{y + 4} v12" stroke="#000000" stroke-opacity="0.25" stroke-width="2"/>'
              for x, y, c in ((50, 106, "#E5484D"), (88, 106, "#3987E5"), (126, 106, "#FFC23D"),
                              (68, 84, "#199E70"), (106, 84, "#D55181")))
    + '<path d="M150,128 V70 M150,70 L118,84" stroke="#FFC23D" stroke-width="4" stroke-linecap="round"/>',
    grad("bg", "#9AD1F5", "#E6F4FB"))

ART["long_haul"] = ("shield", '<rect width="200" height="200" fill="#2C3A2A"/>'
    '<circle cx="100" cy="100" r="58" fill="#8C5A2B"/>'
    '<circle cx="100" cy="100" r="52" fill="#E3B77A"/>'
    + "".join(f'<circle cx="{100 + i * 1.2:.1f}" cy="{100 - i * 0.8:.1f}" r="{44 - i * 9}" fill="none" stroke="#B98446" stroke-width="3"/>' for i in range(5))
    + '<circle cx="105" cy="97" r="4" fill="#8C5A2B"/>'
      '<path d="M100,100 L152,74" stroke="#8C5A2B" stroke-width="2" opacity="0.5"/>'
      '<path d="M146,52 q16,-6 22,8 q-14,6 -22,-8 Z" fill="#5CC08B"/>')

ART["fresh_start"] = ("shield", '<rect width="200" height="200" fill="url(#bg)"/>'
    '<circle cx="150" cy="60" r="16" fill="#FFE27A"/>'
    '<path d="M-10,140 Q100,124 210,140 V210 H-10 Z" fill="#6B4A2B"/>'
    '<path d="M100,140 C100,120 98,104 100,88" stroke="#3FA34D" stroke-width="6" fill="none" stroke-linecap="round"/>'
    '<path d="M100,104 C80,104 64,92 62,74 C82,72 98,84 100,104 Z" fill="#5CC08B"/>'
    '<path d="M100,92 C118,90 134,76 134,58 C114,58 100,72 100,92 Z" fill="#7FD49B"/>'
    '<path d="M70,148 q6,4 12,0 M118,152 q6,4 12,0" stroke="#8C6A45" stroke-width="3" fill="none"/>',
    grad("bg", "#BDE7FF", "#E8F7E0"))

# --- İşbirliği (elmas) ---

ART["contributor"] = ("diamond", '<rect width="200" height="200" fill="#1E2A3E"/>'
    '<path d="M38,120 L62,100 L86,120 V150 H38 Z" fill="#3987E5"/><rect x="56" y="128" width="12" height="22" fill="#1E2A3E"/>'
    '<path d="M110,104 L140,78 L170,104 V150 H110 Z" fill="#D95926"/><rect x="132" y="120" width="16" height="30" fill="#1E2A3E"/>'
    '<path d="M70,92 Q100,52 130,72" stroke="#FFD25A" stroke-width="5" fill="none" stroke-dasharray="3 8" stroke-linecap="round"/>'
    '<rect x="90" y="56" width="22" height="18" rx="3" fill="#FFD25A" transform="rotate(-10 101 65)"/>'
    '<path d="M92,64 h18 M101,57 v16" stroke="#C98500" stroke-width="2.5" transform="rotate(-10 101 65)"/>')

ART["first_merge"] = ("diamond", '<rect width="200" height="200" fill="#231B3A"/>'
    '<path d="M70,160 V60" stroke="#8B6BD6" stroke-width="8" stroke-linecap="round"/>'
    '<path d="M130,60 V90 C130,118 70,112 70,140" stroke="#3FBF7F" stroke-width="8" fill="none" stroke-linecap="round"/>'
    '<circle cx="70" cy="60" r="11" fill="#8B6BD6"/><circle cx="130" cy="60" r="11" fill="#3FBF7F"/>'
    '<circle cx="70" cy="140" r="14" fill="#FFFFFF"/><circle cx="70" cy="140" r="8" fill="#8B6BD6"/>'
    + "".join(f'<rect x="{x}" y="{y}" width="7" height="4" rx="1" fill="{c}" transform="rotate({r} {x} {y})"/>'
              for x, y, c, r in ((108, 128, "#FFD25A", 20), (122, 146, "#FF6FA8", -30), (98, 154, "#7FD4FF", 50),
                                 (134, 120, "#3FBF7F", -10), (116, 164, "#FFD25A", 70)))
    + SPARK(146, 140, 0.8))

ART["reviewer"] = ("diamond", '<rect width="200" height="200" fill="#1B2533"/>'
    '<rect x="56" y="48" width="88" height="108" rx="6" fill="#F2F5FA"/>'
    + "".join(f'<path d="M68,{66 + i * 14} h{[52, 40, 60, 34, 48, 56][i]}" stroke="{"#E5484D" if i == 2 else "#9AA6B8"}" stroke-width="4" stroke-linecap="round"/>'
              for i in range(6))
    + '<path d="M134,96 l6,6 l12,-14" stroke="#2FA36B" stroke-width="5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
      '<path d="M44,112 Q100,70 156,112 Q100,154 44,112 Z" fill="#FFFFFF" fill-opacity="0.92" stroke="#1B2533" stroke-width="3"/>'
      '<circle cx="100" cy="112" r="17" fill="#3987E5"/><circle cx="100" cy="112" r="8" fill="#1B2533"/>'
      '<circle cx="105" cy="107" r="3.5" fill="#FFFFFF"/>')


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for key, spec in ART.items():
        shape, art, *defs = spec
        (OUT / f"{key}.svg").write_text(badge(shape, art, defs[0] if defs else ""), encoding="utf-8")
    print(f"{len(ART)} rozet -> {OUT}")


if __name__ == "__main__":
    main()
