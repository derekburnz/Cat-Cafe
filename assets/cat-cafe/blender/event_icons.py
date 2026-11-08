"""Event countdown game icons (#2488, parent #2483): the live game icon dimmed, a white outline hourglass with gold
sand and a bold Luckiest Guy label ("3 HOURS", "NOW", "NEW UPDATE!"), 512x512, readable at 150 px.

    python3 -I event_icons.py <live icon png> <fonts dir with LuckiestGuy.ttf> <out dir>

PIL only (not Blender). The font is Google Fonts' Luckiest Guy, not in the repo. The outputs live in
assets/cat-cafe/exports/game-icon/; the Normal icon there is a copy of the live icon to swap back to."""
import math, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance

SRC, FONTS, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
K = 4                      # supersample
N = 512 * K
WHITE, INK, SAND = (255, 255, 255, 255), (28, 22, 40, 255), (255, 201, 77, 255)


def hourglass(d, cx, cy, h, sand, w):
    """An hourglass `h` tall centred on (cx, cy); sand in (top share, bottom share) of each bulb; w line width."""
    bw, bh = h * 0.74, h * 0.085                      # end bars
    gw = h * 0.58                                     # glass width at its widest
    top, bot = cy - h / 2, cy + h / 2
    g0, g1 = top + bh, bot - bh
    neck = h * 0.06

    def side(sgn):
        pts = []
        for i in range(41):
            t = i / 40
            y = g0 + (g1 - g0) * t
            # a soft S: wide at the ends, pinched at the middle
            s = abs(math.cos(math.pi * t))
            x = cx + sgn * (neck / 2 + (gw / 2 - neck / 2) * (s ** 0.75))
            pts.append((x, y))
        return pts

    L, R = side(-1), side(1)
    # sand: top bulb filled from the neck up to `sand[0]` of its height, bottom a mound
    mid = (g0 + g1) / 2
    tsh, bsh = sand
    if tsh > 0:
        ytop = mid - (mid - g0) * tsh * 0.92
        poly = [p for p in R if ytop <= p[1] <= mid] + [p for p in reversed(L) if ytop <= p[1] <= mid]
        d.polygon(poly, fill=SAND)
        d.line([(cx, mid), (cx, g1 - 2)], fill=SAND, width=int(w * 0.35)) if 0 < tsh < 1 else None
    if bsh > 0:
        ybase = g1 - w * 0.3
        peak = g1 - (g1 - mid) * bsh * 0.9
        lw = [p for p in L if p[1] >= peak]
        rw = [p for p in R if p[1] >= peak]
        poly = [(cx, peak)] + [(p[0] + 0, p[1]) for p in rw] + list(reversed(lw))
        # a mound: the glass walls below the peak, topped by a curve to the peak
        d.polygon([(lw[0][0], lw[0][1] + (g1 - lw[0][1]) * 0.35), (cx, peak), (rw[0][0], rw[0][1] + (g1 - rw[0][1]) * 0.35)]
                  + [p for p in rw if p[1] >= lw[0][1] + (g1 - lw[0][1]) * 0.35] + [(cx, ybase)]
                  + list(reversed([p for p in lw if p[1] >= lw[0][1] + (g1 - lw[0][1]) * 0.35])), fill=SAND)
    for pts in (L, R):
        d.line(pts, fill=WHITE, width=int(w), joint="curve")
    r = bh / 2
    for y in (top + bh / 2, bot - bh / 2):
        d.rounded_rectangle([cx - bw / 2, y - bh / 2, cx + bw / 2, y + bh / 2], radius=r, fill=WHITE)


def make(label, layout, sand):
    base = Image.open(SRC).convert("RGB").resize((N, N), Image.LANCZOS)
    base = ImageEnhance.Brightness(base).enhance(0.55)
    base = ImageEnhance.Color(base).enhance(0.85).convert("RGBA")
    art = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(art)
    font = ImageFont.truetype(FONTS + "/LuckiestGuy.ttf", 10)
    # fit the label across 90% of the width, at most a size
    size = 120 * K
    while True:
        font = ImageFont.truetype(FONTS + "/LuckiestGuy.ttf", size)
        bb = d.textbbox((0, 0), label, font=font, stroke_width=int(9 * K))
        if bb[2] - bb[0] <= N * 0.92 or size < 40 * K:
            break
        size -= 2 * K
    th = bb[3] - bb[1]
    if layout == "text_top":
        ty, hc, hh = 22 * K, (22 * K + th + 14 * K + (N - 26 * K)) / 2, (N - 26 * K) - (22 * K + th + 14 * K)
    else:
        hh = N - 26 * K - th - 22 * K - 30 * K
        hc = 22 * K + hh / 2
        ty = N - 26 * K - th
    hourglass(d, N / 2, hc, hh * 0.98, sand, 17 * K)
    tx = (N - (bb[2] - bb[0])) / 2 - bb[0]
    d.text((tx, ty - bb[1]), label, font=font, fill=WHITE, stroke_width=int(9 * K), stroke_fill=INK)
    # a soft dark shadow under everything drawn, so it lifts off busy art
    a = art.split()[3]
    shadow = Image.new("RGBA", (N, N), (10, 6, 20, 0))
    shadow.putalpha(a.filter(ImageFilter.GaussianBlur(10 * K)).point(lambda v: min(255, int(v * 0.85))))
    img = Image.alpha_composite(base, shadow)
    img = Image.alpha_composite(img, art)
    return img.convert("RGB").resize((512, 512), Image.LANCZOS)


VARIANTS = {"3Hours": ("3 HOURS", "text_bottom", (1.0, 0.15)),
            "Now": ("NOW", "text_top", (0.35, 0.75)),
            "NewUpdate": ("NEW UPDATE!", "text_bottom", (0.0, 1.0))}
for key, (label, layout, sand) in VARIANTS.items():
    make(label, layout, sand).save(f"{OUT}/CatCafe_GameIcon_Event_{key}.png")
    print("wrote", key)
