"""Today's Deal pictures (#4246): 512 square, transparent, art about 85% of the square, bold dark outline, no words.
Golden fish = CatCafe_Prop_FishCoin, crates = CatCafe_Prop_Crate_Classic_Gold (no area theme), rendered with cutf.py
(coin_*.png, crate_*.png beside this file); tokens are drawn (violet 9B6BFF, dark 2E1A47 edge, cream FFF6D0 star)."""
import math, os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageEnhance

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else HERE
K = 2  # work at 1024, save 512
DARK = (46, 26, 71, 255)


def cut(name, h, rot=0, flip=False):
    im = Image.open(os.path.join(HERE, name + ".png")).convert("RGBA"); im = im.crop(im.getbbox())
    im = im.resize((int(im.width * h / im.height), int(h)), Image.LANCZOS)
    if flip:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    return im.rotate(rot, expand=True, resample=Image.BICUBIC) if rot else im


def edge(im, w, color=DARK):
    """A dark rim of w px around the sprite's own shape."""
    pad = w + 4
    big = Image.new("RGBA", (im.width + 2 * pad, im.height + 2 * pad), (0, 0, 0, 0)); big.alpha_composite(im, (pad, pad))
    a = big.split()[3].filter(ImageFilter.MaxFilter(2 * (w // 2) + 1)).filter(ImageFilter.MaxFilter(2 * (w - w // 2) + 1))
    a = a.filter(ImageFilter.GaussianBlur(1.2)).point(lambda v: 255 if v > 110 else int(v * 2.3))
    rim = Image.new("RGBA", big.size, color); rim.putalpha(a); rim.alpha_composite(big)
    return rim


def put(img, sprite, cx, base, w=9):
    s = edge(sprite, w); img.alpha_composite(s, (int(cx - s.width / 2), int(base - s.height)))


def shadow(img, cx, y, rx, ry):
    g = Image.new("RGBA", img.size, (0, 0, 0, 0)); ImageDraw.Draw(g).ellipse([cx - rx, y - ry, cx + rx, y + ry], fill=(30, 16, 50, 90))
    img.alpha_composite(g.filter(ImageFilter.GaussianBlur(10)))


def glint(img, pts):
    d = ImageDraw.Draw(img)
    for x, y, r in pts:
        d.polygon([(x, y - r), (x + r * .25, y - r * .25), (x + r, y), (x + r * .25, y + r * .25), (x, y + r), (x - r * .25, y + r * .25), (x - r, y), (x - r * .25, y - r * .25)],
                  fill=(255, 255, 255, 255), outline=DARK[:3] + (255,))


def finish(img, name):
    """Fit the art to 85% of the square, centred."""
    box = img.getbbox(); art = img.crop(box); side = int(1024 * 0.86)
    k = min(side / art.width, side / art.height); art = art.resize((int(art.width * k), int(art.height * k)), Image.LANCZOS)
    out = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0)); out.alpha_composite(art, ((1024 - art.width) // 2, (1024 - art.height) // 2))
    out = out.resize((512, 512), Image.LANCZOS); p = os.path.join(OUT, name + ".png"); out.save(p); return p


def canvas():
    return Image.new("RGBA", (1400, 1400), (0, 0, 0, 0))


def fish():
    img = canvas(); shadow(img, 700, 1120, 480, 50)
    put(img, cut("coin_0", 430, 8), 700, 620)
    put(img, cut("coin_-30", 450, -10), 470, 880)
    put(img, cut("coin_30", 450, 12), 930, 880)
    put(img, cut("coin_30", 470, 14, True), 330, 1130)
    put(img, cut("coin_-30", 470, -12, True), 1070, 1130)
    put(img, cut("coin_0", 520, -4), 700, 1150)
    glint(img, [(250, 560, 60), (1130, 500, 48), (1010, 300, 34)])
    return finish(img, "CatCafe_Icon_Deal_Fish")


def crates():
    img = canvas(); shadow(img, 700, 1130, 520, 50)
    put(img, cut("crate_30", 500), 430, 1130)
    put(img, cut("crate_-28", 500), 970, 1130)
    put(img, cut("crate_30", 520, 3), 700, 760)
    glint(img, [(210, 560, 60), (1180, 520, 50), (1050, 250, 36)])
    return finish(img, "CatCafe_Icon_Deal_Crates")


def haul():
    img = canvas(); shadow(img, 700, 1130, 520, 50)
    put(img, cut("crate_30", 760), 640, 1040)
    put(img, cut("coin_30", 330, 16), 1090, 880)
    put(img, cut("coin_-30", 360, -14), 330, 1150)
    put(img, cut("coin_0", 400, 6), 720, 1170)
    put(img, cut("coin_30", 380, 12), 1080, 1160)
    glint(img, [(180, 620, 56), (1230, 520, 46), (1000, 220, 36)])
    return finish(img, "CatCafe_Icon_Deal_Haul")


def token(w, tilt=0.42):
    """One Trait Token seen from above at a slant: violet face, dark edge, cream star."""
    h = int(w * tilt); t = int(w * 0.13); im = Image.new("RGBA", (w + 8, h + t + 8), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.ellipse([4, 4 + t, w + 4, h + t + 4], fill=(104, 66, 196, 255))            # rim bottom
    d.rectangle([4, 4 + h // 2, w + 4, 4 + h // 2 + t], fill=(104, 66, 196, 255))  # rim wall
    for i in range(0, w, max(10, w // 16)):                                     # ridges on the wall
        x = 4 + i; yy = 4 + h / 2 + math.sqrt(max(0, 1 - ((i - w / 2) / (w / 2)) ** 2)) * h / 2
        d.line([x, yy, x, yy + t * 0.8], fill=(74, 44, 150, 255), width=3)
    d.ellipse([4, 4, w + 4, h + 4], fill=(155, 107, 255, 255))                   # face
    d.ellipse([4 + w * .09, 4 + h * .11, 4 + w * .91, 4 + h * .89], outline=(196, 164, 255, 255), width=max(3, w // 50))
    cx, cy = 4 + w / 2, 4 + h / 2; R = w * 0.27; pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5; r = R if i % 2 == 0 else R * 0.45
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a) * tilt * 1.15))
    d.polygon(pts, fill=(255, 246, 208, 255))
    return im


def tokens():
    img = canvas(); shadow(img, 700, 1140, 470, 50)
    for cx, n, w in ((440, 3, 520), (960, 4, 520)):                # two stacks
        for i in range(n):
            put(img, token(w), cx + (12 if i % 2 else -10), 1150 - i * 78, 8)
    for i in range(6):                                              # the tall middle stack in front
        put(img, token(560), 700 + (14 if i % 2 else -12), 1180 - i * 84, 8)
    # one token standing up on top, facing the viewer
    w = 430; t = Image.new("RGBA", (w + 8, w + 8), (0, 0, 0, 0)); d = ImageDraw.Draw(t)
    d.ellipse([4, 4, w + 4, w + 4], fill=(155, 107, 255, 255)); d.ellipse([34, 34, w - 26, w - 26], outline=(196, 164, 255, 255), width=10)
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5; r = w * 0.3 if i % 2 == 0 else w * 0.135
        pts.append((4 + w / 2 + r * math.cos(a), 4 + w / 2 + r * math.sin(a)))
    d.polygon(pts, fill=(255, 246, 208, 255))
    put(img, t.rotate(-12, expand=True, resample=Image.BICUBIC), 720, 640, 9)
    glint(img, [(250, 520, 60), (1150, 430, 48), (1010, 230, 34)])
    return finish(img, "CatCafe_Icon_Deal_Tokens")


if __name__ == "__main__":
    ps = [fish(), tokens(), crates(), haul()]
    sheet = Image.new("RGBA", (4 * 532 + 20, 532 + 150), (58, 40, 30, 255))
    for i, p in enumerate(ps):
        im = Image.open(p); sheet.alpha_composite(im, (20 + i * 532, 10))
        small = im.resize((52, 52), Image.LANCZOS); sheet.alpha_composite(small, (20 + i * 532, 560)); sheet.alpha_composite(im.resize((104, 104), Image.LANCZOS), (100 + i * 532, 550))
    sheet.save(os.path.join(OUT, "sheet.png"))
