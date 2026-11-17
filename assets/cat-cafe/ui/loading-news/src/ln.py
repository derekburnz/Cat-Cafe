"""Loading screen WHAT'S NEW pictures (#5114, Derek 2026-11-17: "better images/models of how recent updates are shown").
One wordless picture per LoadingNews entry, 576x248 (twice the card's 288x124 picture box), saved small for phones.
Made from the real renders: the update posters, the outfit pack cards and the glossy hero cut-outs.
Run: UI=<repo>/assets/cat-cafe CUTS=<home-thumbs-2026-11-17> OUT=<dir> python3 ln.py"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

UI = os.environ["UI"]
CUTS = os.environ["CUTS"]
OUT = os.environ["OUT"]
W, H = 576, 248


def cover(im, box=None):
    """Crop `box` (or all) and fill W x H, cropping the long side from the middle."""
    if box:
        im = im.crop(box)
    k = max(W / im.width, H / im.height)
    im = im.resize((math.ceil(im.width * k), math.ceil(im.height * k)), Image.LANCZOS)
    x, y = (im.width - W) // 2, (im.height - H) // 2
    return im.crop((x, y, x + W, y + H))


def poster(name):
    return Image.open(os.path.join(UI, "ui", "update-posters", f"UpdatePoster_{name}.png")).convert("RGB")


def worlds():
    # the three gate panels, below the area names
    return cover(poster("3NewWorlds"), (88, 112, 936, 442))


def secret():
    # only the dark shapes row (the dark-shape rule in game), with a soft violet glow behind it
    p = poster("10SecretCats")
    row = p.crop((176, 352, 848, 448))
    img = Image.new("RGB", (W, H), (16, 14, 30))
    glow = Image.new("RGB", (W, H), (0, 0, 0))
    ImageDraw.Draw(glow).ellipse((60, 20, W - 60, H - 10), fill=(90, 60, 170))
    img = Image.blend(img, glow.filter(ImageFilter.GaussianBlur(50)), 0.6)
    d = ImageDraw.Draw(img)
    rnd = random.Random(7)
    for _ in range(70):
        x, y, r = rnd.randrange(W), rnd.randrange(H), rnd.choice((1, 1, 1, 2))
        d.ellipse((x - r, y - r, x + r, y + r), fill=(235, 230, 255))
    k = (W - 24) / row.width
    row = row.resize((W - 24, int(row.height * k)), Image.LANCZOS)
    mask = Image.new("L", row.size, 0)
    ImageDraw.Draw(mask).rectangle((18, 10, row.width - 18, row.height - 10), fill=255)
    img.paste(row, (12, (H - row.height) // 2 + 6), mask.filter(ImageFilter.GaussianBlur(9)))
    return img


def outfits():
    # the cat row of each outfit pack card, side by side
    img = Image.new("RGB", (W, H), (40, 30, 30))
    names = ["Winter", "Stylish", "Chef", "Space"]
    w = W // len(names)
    for i, n in enumerate(names):
        c = Image.open(os.path.join(UI, "exports", "store", f"CatCafe_StorePack_{n}_Card.png")).convert("RGB")
        strip = c.crop((180, 180, 840, 512))       # the three cats on their floor, under the shop sign
        k = H / strip.height
        strip = strip.resize((int(strip.width * k), H), Image.LANCZOS)
        x = (strip.width - w) // 2
        img.paste(strip.crop((x, 0, x + w, H)), (i * w, 0))
    d = ImageDraw.Draw(img)
    for i in range(1, len(names)):
        d.line([(i * w, 0), (i * w, H)], fill=(255, 255, 255), width=4)
    return img


def rift():
    # a Mythic cat in front of the rift's pink light rings (the Rift Run's look: violet sky, pink rings, dark void)
    img = Image.new("RGB", (W, H), (30, 16, 60))
    sky = Image.new("RGB", (W, H), (0, 0, 0))
    ImageDraw.Draw(sky).ellipse((W * 0.5 - 260, -120, W * 0.5 + 260, H + 140), fill=(150, 70, 220))
    img = Image.blend(img, sky.filter(ImageFilter.GaussianBlur(60)), 0.7)
    d = ImageDraw.Draw(img)
    rnd = random.Random(3)
    for _ in range(60):
        x, y, r = rnd.randrange(W), rnd.randrange(H), rnd.choice((1, 1, 2))
        d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 225, 250))
    cx, cy = W // 2, H // 2 + 6
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lay)
    for r, col, wid in ((118, (255, 130, 210, 255), 12), (100, (255, 90, 190, 255), 9), (84, (255, 160, 230, 255), 7)):
        ld.ellipse((cx - r, cy - r, cx + r, cy + r), outline=col, width=wid)
    ld.ellipse((cx - 76, cy - 76, cx + 76, cy + 76), fill=(24, 8, 40, 255))
    glow = lay.filter(ImageFilter.GaussianBlur(10))
    img = img.convert("RGBA")
    img.alpha_composite(glow)
    img.alpha_composite(lay)
    cat = Image.open(os.path.join(CUTS, "cut17", "big_Comet.png")).convert("RGBA")
    cat = cat.crop(cat.getbbox())
    cat = ImageEnhance.Color(cat).enhance(1.15)
    k = 200 / cat.height
    cat = cat.resize((int(cat.width * k), 200), Image.LANCZOS)
    rim = Image.new("RGBA", cat.size, (255, 255, 255, 0))
    rim.putalpha(cat.getchannel("A").filter(ImageFilter.MaxFilter(7)))
    pos = (cx - cat.width // 2, H - cat.height - 14)
    img.alpha_composite(rim, (pos[0], pos[1]))
    img.alpha_composite(cat, pos)
    return img.convert("RGB")


def devices():
    return cover(poster("BetterOnEveryDevice"), (250, 200, 780, 440))


def harvest():
    return cover(poster("HarvestHollow"), (0, 185, 1024, 470))


PICS = {"worlds": worlds, "rift": rift, "outfits": outfits, "secret": secret, "devices": devices, "harvest": harvest}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    sheet = Image.new("RGB", (W * 2 + 30, (H + 10) * 3 + 10), (30, 30, 34))
    for i, (key, f) in enumerate(PICS.items()):
        im = f()
        path = os.path.join(OUT, f"CatCafe_LoadingNews_{key}.png")
        im.quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG).save(path, optimize=True)
        sheet.paste(im, (10 + (i % 2) * (W + 10), 10 + (i // 2) * (H + 10)))
        print(key, os.path.getsize(path) // 1024, "KB")
    sheet.save(os.path.join(OUT, "SHEET_loading_news.jpg"), quality=90)
