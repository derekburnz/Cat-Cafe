"""25 phone-first ad drafts (#3441, brief: Growth-Agent/ads-female-25/brief.md): one big subject, four words or fewer,
soft pastel with one strong accent. Cut-outs come from cut.py (cut/), the Mouse Dash art from big.py, the pool, wizard
and cafe room pictures from the earlier update and ad renders.   python3 ads.py [F01 F02 ...]"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
EV = os.environ.get("FA_EV", os.path.join(HERE, "..", "ev"))
sys.path.insert(0, EV)
import compose as C  # noqa
import compose2 as C2  # noqa

OLD = os.environ.get("FA_OLD", "/mnt/project-files/Model-Agent/store-and-ads/ads-2026-11-08")
OUT = os.path.join(HERE, "out")
W, H = 1920, 1080
GOLD, WHITE = C2.GOLD, C2.WHITE
PINK = ((255, 255, 255), (255, 170, 205), (120, 20, 80))
HOT = ((255, 190, 215), (255, 80, 140), (96, 12, 60))
MINT = ((235, 255, 245), (120, 235, 200), (16, 70, 80))
SKY = ((255, 255, 255), (170, 225, 255), (24, 50, 110))
VIO = ((250, 235, 255), (200, 150, 255), C.INK)


def bg(inner, outer, rays=None, centre=(0.5, 0.5), n=14, ray_alpha=70):
    """A soft round gradient, with optional sunburst rays from the centre."""
    small = Image.new("RGB", (192, 108))
    px = small.load()
    cx, cy = centre[0] * 192, centre[1] * 108
    for y in range(108):
        for x in range(192):
            k = min(1.0, math.hypot((x - cx) / 150, (y - cy) / 100) ** 1.15)
            px[x, y] = tuple(int(inner[i] + (outer[i] - inner[i]) * k) for i in range(3))
    img = small.resize((W, H), Image.BICUBIC).convert("RGBA")
    if rays:
        lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(lay)
        X, Y = centre[0] * W, centre[1] * H
        for i in range(n):
            a0 = 2 * math.pi * i / n
            a1 = a0 + math.pi / n
            d.polygon([(X, Y), (X + 3000 * math.cos(a0), Y + 3000 * math.sin(a0)),
                       (X + 3000 * math.cos(a1), Y + 3000 * math.sin(a1))], fill=rays + (ray_alpha,))
        img.alpha_composite(lay.filter(ImageFilter.GaussianBlur(3)))
    return img


def dots(img, rgb, seed, n=26, alpha=60, rmin=14, rmax=60):
    """Soft bokeh dots."""
    r = random.Random(seed)
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    for _ in range(n):
        x, y, s = r.uniform(0, W), r.uniform(0, H), r.uniform(rmin, rmax)
        d.ellipse([x - s, y - s, x + s, y + s], fill=rgb + (int(alpha * r.uniform(0.5, 1)),))
    img.alpha_composite(lay.filter(ImageFilter.GaussianBlur(4)))


def stars(img, seed, n=70, ymax=H):
    r = random.Random(seed)
    d = ImageDraw.Draw(img)
    for _ in range(n):
        x, y, s = r.uniform(0, W), r.uniform(0, ymax), r.uniform(2, 5)
        d.ellipse([x - s, y - s, x + s, y + s], fill=(255, 255, 240, 255))


def cut(name, h=None, w=None, flip=False):
    im = Image.open(os.path.join(HERE, "cut", name + ".png")).convert("RGBA")
    im = im.crop(im.getbbox())
    if h:
        im = im.resize((max(1, int(im.width * h / im.height)), h), Image.LANCZOS)
    elif w:
        im = im.resize((w, max(1, int(im.height * w / im.width))), Image.LANCZOS)
    return im.transpose(Image.FLIP_LEFT_RIGHT) if flip else im


def hero(img, im, cx, bottom, rim=14, rim_rgb=(255, 255, 255), glow=None, shadow=True, tilt=0):
    """A cut-out with a sticker rim, a soft shadow and an optional glow, standing on `bottom`."""
    if tilt:
        im = im.rotate(tilt, resample=Image.BICUBIC, expand=True)
    pad = 120
    lay = Image.new("RGBA", (im.width + pad * 2, im.height + pad * 2), (0, 0, 0, 0))
    lay.alpha_composite(im, (pad, pad))
    a = lay.split()[3]
    x, y = int(cx - lay.width / 2), int(bottom - im.height - pad)
    if glow:
        g = Image.new("RGBA", lay.size, glow + (0,))
        g.putalpha(a.filter(ImageFilter.MaxFilter(41)).filter(ImageFilter.GaussianBlur(38)).point(lambda v: int(v * 0.85)))
        img.alpha_composite(g, (x, y))
    if shadow:
        s = Image.new("RGBA", lay.size, (40, 14, 60, 0))
        s.putalpha(a.filter(ImageFilter.MaxFilter(max(rim, 1) * 2 + 1)).filter(ImageFilter.GaussianBlur(14)).point(lambda v: int(v * 0.55)))
        img.alpha_composite(s, (x + 10, y + 18))
    if rim:
        r = Image.new("RGBA", lay.size, rim_rgb + (0,))
        r.putalpha(a.filter(ImageFilter.MaxFilter(rim * 2 + 1)).filter(ImageFilter.GaussianBlur(1.2)))
        img.alpha_composite(r, (x, y))
    img.alpha_composite(lay, (x, y))


def ground(img, cx, y, rx, ry, rgb, alpha=255):
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(lay).ellipse([cx - rx, y - ry, cx + rx, y + ry], fill=rgb + (alpha,))
    img.alpha_composite(lay.filter(ImageFilter.GaussianBlur(3)))


def pill(img, text, cx, cy, size=84, fill=(255, 255, 255), ink=C.INK, tilt=0, text_rgb=None):
    f = ImageFont.truetype(C.LILITA, size)
    d = ImageDraw.Draw(Image.new("RGBA", (10, 10)))
    w = int(d.textlength(text, font=f)) + size
    h = int(size * 1.5)
    lay = Image.new("RGBA", (w + 40, h + 50), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lay)
    ld.rounded_rectangle([14, 22, w + 30, h + 38], h // 2, fill=(20, 8, 40, 120))
    ld.rounded_rectangle([4, 4, w + 24, h + 24], h // 2 + 8, fill=ink)
    ld.rounded_rectangle([14, 14, w + 14, h + 14], h // 2, fill=fill)
    ld.text((w / 2 + 14, h / 2 + 12), text, font=f, fill=text_rgb or ink, anchor="mm")
    C.put(img, lay, cx, cy, tilt)


def words(img, text, size, cx, cy, style=GOLD, tilt=0, font=None, stroke=None):
    C2.words(img, text, size, cx, cy, style, tilt, font, stroke or max(12, size // 7))


def logo(img, cx=1640, cy=1020, size=52):
    C2.logo(img, cx, cy, size)


def sparkles(img, pts):
    for (x, y, s, rgb) in pts:
        C.sparkle(img, x, y, s, rgb)


def heart(img, cx, cy, s, rgb=(255, 80, 130), ink=(120, 20, 70)):
    lay = Image.new("RGBA", (s * 3, s * 3), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    for (k, col) in ((1.0, ink), (0.8, rgb)):
        r = s * 0.5 * k
        c = s * 1.5
        d.ellipse([c - r * 2, c - r * 1.6, c, c + r * 0.4], fill=col)
        d.ellipse([c, c - r * 1.6, c + r * 2, c + r * 0.4], fill=col)
        d.polygon([(c - r * 1.87, c - r * 0.1), (c + r * 1.87, c - r * 0.1), (c, c + r * 2.0)], fill=col)
    C.put(img, lay, cx, cy)


def shade(img, side, dark=150, rgb=(40, 14, 70), span=0.55):
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    for i in range(W if side in ("left", "right") else H):
        n = W if side in ("left", "right") else H
        u = i / n if side in ("left", "top") else 1 - i / n
        v = int(dark * max(0.0, 1 - u / span) ** 1.3)
        d.line([(i, 0), (i, H)] if side in ("left", "right") else [(0, i), (W, i)], fill=v)
    img.paste(Image.new("RGBA", (W, H), rgb + (255,)), (0, 0), m)


def photo(path, zoom=1.0, cx=0.5, cy=0.5, blur=0):
    im = Image.open(path).convert("RGBA")
    k = max(W / im.width, H / im.height) * zoom
    im = im.resize((int(im.width * k), int(im.height * k)), Image.LANCZOS)
    x = int(min(max(0, im.width * cx - W / 2), im.width - W))
    y = int(min(max(0, im.height * cy - H / 2), im.height - H))
    im = im.crop((x, y, x + W, y + H))
    return im.filter(ImageFilter.GaussianBlur(blur)) if blur else im


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    p = os.path.join(OUT, name + ".png")
    img.convert("RGB").save(p, optimize=True)
    print("wrote", name, os.path.getsize(p) // 1024, "KB")


YEL, WHT, LIL = (255, 240, 150), (255, 255, 255), (200, 160, 255)

# ---- cute and collect ----

def F01():
    img = bg((255, 214, 232), (255, 140, 190), rays=(255, 255, 255), centre=(0.68, 0.5))
    hero(img, cut("face_blossom", 1040), 1310, 1120, glow=(255, 255, 255))
    words(img, "CATCH", 250, 430, 330, PINK, 5)
    words(img, "ME!", 330, 430, 640, GOLD, 5)
    sparkles(img, [(840, 150, 60, WHT), (1790, 250, 70, YEL), (860, 900, 46, YEL)])
    logo(img, 330, 1020)
    save(img, "Ad_F01_CatchMe")


def F02():
    img = bg((255, 226, 240), (250, 150, 200), centre=(0.5, 0.6))
    dots(img, (255, 255, 255), 2, 24, 80)
    names = ("s_comet", "s_duchess", "s_balloon", "f_Aurora", "s_king", "s_marsh", "f_Midnight", "s_maple")
    tints = ((255, 240, 200), (236, 220, 255), (255, 214, 232), (206, 226, 255), (255, 228, 190), (255, 255, 255),
             (216, 206, 255), (255, 218, 190))
    d = ImageDraw.Draw(img)
    for i, n in enumerate(names):
        x0, y0 = 700 + (i % 4) * 300, 90 + (i // 4) * 470
        d.rounded_rectangle([x0 - 8, y0 - 8, x0 + 278, y0 + 438], 48, fill=C.INK)
        d.rounded_rectangle([x0 + 4, y0 + 4, x0 + 266, y0 + 426], 38, fill=tints[i])
        im = cut(n, 390)
        if im.width > 300:
            im = cut(n, w=300)
        hero(img, im, x0 + 135, y0 + 418, rim=0, shadow=False)
    words(img, "80+", 330, 340, 250, GOLD, 4)
    words(img, "CATS TO", 150, 340, 520, WHITE, 4)
    words(img, "COLLECT!", 150, 350, 700, HOT, 4)
    logo(img, 350, 1010, 50)
    save(img, "Ad_F02_EightyCats")

def F03():
    img = bg((205, 245, 255), (120, 200, 250), rays=(255, 255, 255), centre=(0.5, 0.85), ray_alpha=60)
    ground(img, 960, 1010, 1100, 150, (150, 225, 170))
    for (n, x, h) in (("s_duchess", 250, 520), ("s_king", 1670, 540), ("s_balloon", 600, 620), ("s_marsh", 1310, 600),
                      ("s_blossom", 960, 660)):
        hero(img, cut(n, h), x, 1040, rim=10)
    words(img, "COLLECT", 220, 960, 150, GOLD, 0)
    words(img, "THEM ALL!", 180, 960, 345, WHITE, 0)
    logo(img, 1680, 60, 44)
    save(img, "Ad_F03_CollectThemAll")


def F04():
    img = bg((235, 215, 255), (170, 130, 240), rays=(255, 255, 255), centre=(0.3, 0.55))
    hero(img, cut("s_balloon", 640), 400, 720, rim=12)
    hero(img, cut("s_marsh", 560, flip=True), 760, 720, rim=12)
    hero(img, cut("backpack", 620), 570, 1060, rim=14)
    words(img, "CARRY", 250, 1400, 250, WHITE, -4)
    words(img, "2 CATS!", 270, 1420, 540, HOT, -4)
    pill(img, "IN YOUR BACKPACK", 1420, 800, 84, tilt=-4)          # Catalog: Backpack, "Carry 2 cats!"
    logo(img)
    save(img, "Ad_F04_CarryTwoCats")

def F05():
    img = bg((255, 240, 170), (255, 150, 50), rays=(255, 255, 220), centre=(0.7, 0.52), ray_alpha=90)
    hero(img, cut("gold_blossom", 940), 1340, 1050, glow=(255, 255, 200))
    words(img, "FIND A", 190, 450, 190, WHITE, 4)
    words(img, "GOLD", 300, 450, 430, GOLD, 4)
    words(img, "CAT!", 300, 470, 700, GOLD, 4)
    pill(img, "1 IN 20", 470, 920, 96, tilt=4)                      # Config.GoldChanceNet = 0.05
    sparkles(img, [(900, 200, 70, WHT), (1780, 180, 80, WHT), (1800, 760, 60, WHT), (900, 760, 50, WHT)])
    logo(img, 1640, 1030, 46)
    save(img, "Ad_F05_GoldCat")


def F06():
    img = bg((120, 70, 220), (40, 16, 100), rays=(255, 120, 220), centre=(0.3, 0.52), ray_alpha=60)
    hero(img, cut("rain_marsh", 920), 560, 1040, glow=(255, 255, 255))
    words(img, "RAINBOW", 230, 1350, 220, ((255, 240, 120), (255, 110, 180), (70, 14, 60)), -4)
    words(img, "CAT!", 330, 1380, 510, ((150, 255, 230), (110, 150, 255), (30, 20, 90)), -4)
    pill(img, "1 IN 67", 1400, 800, 110, tilt=-4)                   # Config.RainbowChanceNet = 0.015
    sparkles(img, [(150, 180, 70, YEL), (980, 200, 60, WHT), (990, 860, 54, YEL), (140, 820, 50, WHT)])
    logo(img)
    save(img, "Ad_F06_RainbowCat")


def F07():
    img = bg((70, 190, 200), (20, 60, 110), rays=(180, 255, 240), centre=(0.32, 0.52), ray_alpha=45)
    im = cut("s_wisp", 900)
    sil = Image.new("RGBA", im.size, (30, 14, 70, 255))
    sil.putalpha(im.split()[3])
    hero(img, sil, 600, 1040, rim=14, glow=(255, 255, 255))
    words(img, "?", 520, 600, 560, GOLD, 0)
    words(img, "WHO", 290, 1380, 250, WHITE, -4)
    words(img, "IS IT?", 290, 1400, 560, GOLD, -4)
    pill(img, "SECRET CATS TO FIND", 1400, 830, 76, tilt=-4)
    logo(img)
    save(img, "Ad_F07_WhoIsIt")

# ---- your own cafe ----

def F08():
    img = photo(os.path.join(OLD, "Ad_05_DecorateCafe_raw.png"), 1.7, 0.42, 0.72)
    img = ImageEnhance.Color(img).enhance(1.15)
    shade(img, "top", 215, (70, 24, 90), 0.5)
    words(img, "YOUR", 210, 430, 150, WHITE, 0)
    words(img, "CAT CAFE!", 210, 1270, 150, GOLD, 0)
    logo(img, 1650, 1030, 46)
    save(img, "Ad_F08_YourCatCafe")


def F09():
    img = bg((215, 245, 255), (120, 195, 250), rays=(255, 255, 255), centre=(0.62, 0.6), ray_alpha=55)
    ground(img, 1150, 1000, 1000, 160, (150, 225, 170))
    hero(img, cut("cafe_blush", w=1250), 1200, 1050, rim=12)
    words(img, "BUILD", 240, 420, 180, GOLD, 4)
    words(img, "YOUR", 200, 380, 400, WHITE, 4)
    words(img, "CAFE!", 240, 420, 620, HOT, 4)
    hero(img, cut("s_blossom", 330), 330, 1050, rim=10)
    logo(img, 1640, 60, 44)
    save(img, "Ad_F09_BuildYourCafe")


def F10():
    img = photo(os.path.join(OLD, "Ad_01_CatsAtWork_raw.png"), 1.0)
    img = ImageEnhance.Color(img).enhance(1.15)
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).ellipse([760, -420, 2300, 560], fill=235)
    img.paste(Image.new("RGBA", (W, H), (70, 24, 90, 255)), (0, 0), m.filter(ImageFilter.GaussianBlur(70)))
    words(img, "OPEN YOUR", 180, 1400, 130, WHITE, -3)
    words(img, "CAFE!", 260, 1440, 350, GOLD, -3)
    logo(img, 1640, 1030, 46)
    save(img, "Ad_F10_OpenYourCafe")

def F11():
    img = bg((255, 232, 215), (255, 170, 150), rays=(255, 255, 255), centre=(0.5, 0.75), ray_alpha=60)
    ground(img, 960, 1020, 1000, 110, (255, 205, 190))
    hero(img, cut("d_tree", 760), 420, 1060, rim=12)
    hero(img, cut("d_arch", 700), 1500, 1060, rim=12)
    hero(img, cut("d_lamp", 560), 960, 1065, rim=12)
    hero(img, cut("s_duchess", 380), 1500, 1070, rim=10)
    words(img, "DECORATE!", 260, 960, 170, GOLD, 0)
    logo(img, 1680, 60, 44)
    save(img, "Ad_F11_Decorate")

def F12():
    img = bg((255, 236, 214), (236, 150, 130), centre=(0.68, 0.5))
    dots(img, (255, 255, 255), 12, 30, 70)
    hero(img, cut("cushion_cat", 900), 1330, 1040, glow=(255, 250, 230))
    hero(img, cut("coffee", w=360), 860, 1040, rim=10)
    words(img, "COSY", 280, 430, 250, WHITE, 4)
    words(img, "CAT", 280, 420, 520, GOLD, 4)
    words(img, "CAFE", 280, 450, 790, GOLD, 4)
    heart(img, 1720, 200, 90)
    logo(img, 360, 1030, 44)
    save(img, "Ad_F12_CosyCatCafe")


def F13():
    img = bg((70, 60, 160), (16, 14, 60), centre=(0.62, 0.55))
    stars(img, 13, 90, 620)
    d = ImageDraw.Draw(img)
    d.ellipse([1560, 70, 1800, 310], fill=(255, 246, 200, 255))
    d.ellipse([1500, 40, 1720, 260], fill=(38, 32, 110, 255))
    ground(img, 1150, 1020, 1100, 150, (40, 50, 110))
    cafe = cut("cafe_lilac", w=1250)
    night = ImageEnhance.Brightness(cafe).enhance(0.62)
    r, g, b, a = night.split()
    night = Image.merge("RGBA", (r.point(lambda v: int(v * 0.8)), g.point(lambda v: int(v * 0.85)), b, a))
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([700, 640, 1700, 1040], fill=(255, 200, 110, 150))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(110)))
    hero(img, night, 1200, 1050, rim=0, glow=(255, 210, 130))
    # warm windows: the cafe's own bright pixels, lit
    lit = Image.new("RGBA", cafe.size, (255, 214, 120, 0))
    m = cafe.convert("L").point(lambda v: 255 if v > 225 else 0)
    from PIL import ImageChops
    lit.putalpha(ImageChops.multiply(m, cafe.split()[3]).point(lambda v: int(v * 0.85)))
    img.alpha_composite(lit, (int(1200 - cafe.width / 2), int(1050 - cafe.height)))
    words(img, "COSY", 260, 420, 250, GOLD, 4)
    words(img, "NIGHTS", 220, 440, 500, WHITE, 4)
    hero(img, cut("s_midnight", 380), 330, 1050, rim=10, glow=(200, 170, 255))
    logo(img, 1640, 1030, 44)
    save(img, "Ad_F13_CosyNights")

# ---- Mystic Pool and traits (Thursday update) ----

def F14():
    img = bg((170, 110, 240), (50, 24, 120), rays=(255, 180, 250), centre=(0.3, 0.5), ray_alpha=50)
    hero(img, cut("sage", 1000), 540, 1060, glow=(255, 220, 255))
    words(img, "MEET THE", 170, 1330, 190, WHITE, -4)
    words(img, "WIZARD", 260, 1350, 420, GOLD, -4)
    words(img, "CAT!", 300, 1380, 690, GOLD, -4)
    sparkles(img, [(160, 170, 70, YEL), (1000, 250, 56, WHT), (1010, 880, 60, YEL)])
    logo(img)
    save(img, "Ad_F14_WizardCat")

def F15():
    img, bx = C2.pool("raw.png", "left", dark=190)
    words(img, "NEW!", 190, 330, 150, WHITE, 4)
    words(img, "MYSTIC", 240, 470, 380, GOLD, 4)
    words(img, "POOL", 300, 480, 650, GOLD, 4)
    logo(img, 1600, 1020, 50)
    save(img, "Ad_F15_MysticPool")

def F16():
    img = bg((200, 160, 255), (90, 50, 190), rays=(255, 255, 255), centre=(0.3, 0.52), ray_alpha=45)
    hero(img, cut("st_duchess", 900), 500, 1040, glow=(255, 255, 255))
    words(img, "GIVE CATS", 160, 1360, 150, WHITE, -4)
    words(img, "POWERS!", 220, 1370, 370, GOLD, -4)
    card = Image.new("RGBA", (900, 300), (0, 0, 0, 0))
    C2.badge(card, 450, 150, "CAT TRAIT", "Lucky Bowl", tilt=0)
    card = card.crop(card.getbbox())
    card = card.resize((int(card.width * 1.75), int(card.height * 1.75)), Image.LANCZOS)
    C.put(img, card, 1370, 750, -4)
    sparkles(img, [(150, 200, 70, YEL), (990, 180, 60, WHT), (1000, 860, 50, YEL), (130, 800, 46, WHT)])
    logo(img)
    save(img, "Ad_F16_GiveCatsPowers")


def F17():
    img = bg((120, 80, 210), (36, 18, 96), centre=(0.5, 0.6))
    stars(img, 17, 60)
    words(img, "WHAT WILL", 150, 520, 150, WHITE, 0)
    words(img, "YOU GET?", 150, 1380, 150, GOLD, 0)
    f1, f2 = ImageFont.truetype(C.LILITA, 62), ImageFont.truetype(C.LUCKY, 110)
    cards = (("COMMON", "55%", (176, 182, 196)), ("UNCOMMON", "28%", (110, 214, 130)), ("RARE", "12%", (90, 170, 255)),
             ("LEGENDARY", "4%", (255, 196, 60)), ("MYTHIC", "1%", (214, 110, 255)))
    d = ImageDraw.Draw(img)
    f3 = ImageFont.truetype(C.LUCKY, 170)
    for i, (n, p, rgb) in enumerate(cards):
        x0 = 70 + i * 362
        y0, y1 = 400 - i * 24, 960
        d.rounded_rectangle([x0 - 6, y0 - 6, x0 + 336, y1 + 14], 44, fill=C.INK)
        d.rounded_rectangle([x0 + 6, y0 + 6, x0 + 324, y1 - 6], 34, fill=rgb)
        d.ellipse([x0 + 65, y0 + 50, x0 + 265, y0 + 250], fill=(255, 255, 255, 255), outline=C.INK, width=10)
        d.ellipse([x0 + 98, y0 + 83, x0 + 232, y0 + 217], fill=tuple(min(255, v + 40) for v in rgb))
        d.text((x0 + 165, y1 - 150), p, font=f3, fill=(255, 255, 255), anchor="mm", stroke_width=14, stroke_fill=C.INK)
    sparkles(img, [(1700, 330, 54, YEL), (1560, 400, 36, WHT)])
    pill(img, "CAT TRAIT ROLLS", 420, 1025, 50)
    logo(img, 1640, 1030, 44)
    save(img, "Ad_F17_WhatWillYouGet")


def F18():
    img = bg((255, 225, 150), (255, 120, 170), rays=(255, 255, 255), centre=(0.7, 0.52), ray_alpha=70)
    hero(img, cut("st_king", 900), 1340, 1040, glow=(255, 255, 255))
    words(img, "5 FREE", 280, 470, 260, GOLD, 4)
    words(img, "ROLLS!", 280, 500, 540, WHITE, 4)
    pill(img, "NEW CAT TRAITS", 500, 800, 88, tilt=4)
    sparkles(img, [(900, 180, 70, WHT), (1790, 200, 80, WHT), (1800, 800, 56, WHT), (880, 820, 50, WHT)])
    logo(img, 380, 1030, 46)
    save(img, "Ad_F18_FiveFreeRolls")

# ---- Mouse Dash (Thursday update) ----

def cellar(dark=0.8):
    img = C2.cellar().filter(ImageFilter.GaussianBlur(5))
    return ImageEnhance.Brightness(img).enhance(dark)


def F19():
    img = cellar()
    C2.hole(img, 700, 780, 900, "Mouse", 0.2)
    C2.at(img, C2.art("PawBop", 640, 24), 1080, 250)
    words(img, "BOP!", 420, 1440, 700, GOLD, -6)
    sparkles(img, [(330, 300, 70, YEL), (1150, 720, 50, WHT)])
    logo(img, 1560, 1020, 50)
    save(img, "Ad_F19_Bop")


def F20():
    img = cellar(0.6)
    C2.hole(img, 640, 800, 980, "Kitten", 0.2)
    words(img, "SHHH!", 300, 1420, 420, VIO, -5)
    pill(img, "DON'T WAKE THE KITTEN", 1400, 700, 76, tilt=-5)
    for (x, y, s) in ((960, 330, 110), (1060, 210, 150), (1190, 90, 190)):
        words(img, "Z", s, x, y, WHITE, 10)
    logo(img, 1560, 1020, 50)
    save(img, "Ad_F20_DontWakeTheKitten")


def F21():
    img = cellar(0.7)
    g = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(g).ellipse([180, 60, 1120, 900], fill=(255, 220, 90, 150))
    img.alpha_composite(g.filter(ImageFilter.GaussianBlur(120)))
    C2.hole(img, 650, 800, 980, "GoldMouse", 0.2)
    words(img, "CATCH THE", 170, 1400, 230, WHITE, -4)
    words(img, "GOLD", 300, 1400, 470, GOLD, -4)
    words(img, "ONE!", 300, 1420, 740, GOLD, -4)
    sparkles(img, [(250, 240, 80, WHT), (1050, 300, 64, WHT), (300, 620, 50, WHT)])
    logo(img, 1560, 1020, 46)
    save(img, "Ad_F21_GoldMouse")


def F22():
    img = cellar()
    C2.hole(img, 1330, 800, 900, "Mouse", 0.2)
    C2.at(img, C2.art("Paw", 460, -20), 1560, 300)
    words(img, "NEW", 250, 470, 200, WHITE, 4)
    words(img, "MINI", 280, 470, 450, GOLD, 4)
    words(img, "GAME!", 280, 500, 720, GOLD, 4)
    C2.hearts(img, 300, 960, 150)
    logo(img, 1580, 60, 44)
    save(img, "Ad_F22_NewMiniGame")

# ---- feel-good and social ----

def F23():
    img = bg((255, 225, 240), (255, 150, 170), rays=(255, 255, 255), centre=(0.5, 0.7), ray_alpha=60)
    hero(img, cut("s_comet", 640, flip=True), 360, 1050)
    hero(img, cut("s_balloon", 700), 1560, 1050)
    heart(img, 960, 760, 150)
    words(img, "PLAY WITH", 200, 960, 160, WHITE, 0)
    words(img, "FRIENDS!", 250, 960, 400, GOLD, 0)
    logo(img, 960, 1020, 46)
    save(img, "Ad_F23_PlayWithFriends")


def F24():
    img = bg((120, 150, 220), (40, 50, 120), rays=(255, 255, 255), centre=(0.3, 0.45), ray_alpha=30)
    ground(img, 560, 1010, 620, 110, (60, 70, 130))
    hero(img, cut("bin_cat", 960), 560, 1050, glow=(255, 240, 200))
    words(img, "RESCUE", 250, 1370, 250, GOLD, -4)
    words(img, "ME!", 340, 1390, 560, WHITE, -4)
    pill(img, "SAVE STUCK CATS", 1390, 830, 84, tilt=-4)
    logo(img)
    save(img, "Ad_F24_RescueMe")


def F25():
    img = bg((215, 250, 250), (110, 205, 220), centre=(0.68, 0.5))
    dots(img, (255, 255, 255), 25, 34, 130, 20, 80)
    hero(img, cut("bath_cat", 940), 1330, 1050, glow=(255, 255, 255))
    words(img, "CAT", 300, 430, 260, WHITE, 4)
    words(img, "SPA", 320, 440, 540, HOT, 4)
    words(img, "DAY!", 300, 460, 820, GOLD, 4)
    logo(img, 1640, 60, 44)
    save(img, "Ad_F25_CatSpaDay")


ALL = [F01, F02, F03, F04, F05, F06, F07, F08, F09, F10, F11, F12, F13, F14, F15, F16, F17, F18, F19, F20, F21, F22, F23,
       F24, F25]


def sheet():
    """All 25 on one picture: 5 x 5 at 640 px wide each, with a 300 px phone-size row check beside it as a second file."""
    import glob
    fs = sorted(glob.glob(os.path.join(OUT, "Ad_F*.png")))
    for (cw, name) in ((640, "all-25-ads"), (300, "all-25-ads-phone-size")):
        ch = cw * 9 // 16
        g = max(8, cw // 40)
        top = cw // 5
        s = Image.new("RGB", (5 * cw + 6 * g, top + 5 * (ch + g + cw // 12) + g), (36, 22, 60))
        d = ImageDraw.Draw(s)
        d.text((s.width // 2, top // 2), "25 phone ad drafts (#3441)", font=ImageFont.truetype(C.LILITA, cw // 8),
               fill=(255, 255, 255), anchor="mm")
        f = ImageFont.truetype(C.LILITA, cw // 16)
        for i, p in enumerate(fs):
            x = g + (i % 5) * (cw + g)
            y = top + (i // 5) * (ch + g + cw // 12)
            s.paste(Image.open(p).resize((cw, ch), Image.LANCZOS), (x, y))
            d.text((x + 4, y + ch + 2), os.path.basename(p)[3:-4].replace("_", " ", 1), font=f, fill=(255, 230, 250))
        s.save(os.path.join(OUT, name + ".png"), optimize=True)
        print("wrote", name, s.size)


if __name__ == "__main__":
    want = sys.argv[1:]
    for fn in ALL:
        if not want or fn.__name__ in want:
            fn()
    if not want or "sheet" in want:
        sheet()
