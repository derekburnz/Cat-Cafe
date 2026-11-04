"""P v3 (#1032): the hero render with the CATCH A CAT CAFE logo laid out like CatCafe_Thumb_P_CafeNamed.png.

The logo copies the set3 P layout, measured from that file: each line centred on x 1420, cap tops at y 181, 355 and
585 with cap heights 97, 175 and 175, the tagline at y 824. CATCH A is yellow (255, 214, 92), CAT and CAFE white, all
outlined in brown (110, 62, 38) with a soft drop shadow. Fonts: Inter Display ExtraBold for the title, opened up to the
original widths (586, 469, 609 px) but never tracked tighter than the font, so an outline always parts two letters;
Inter Black for the tagline.

    python3 compose_p_v3.py HERO.png OLD_P.png OUT_DIR
writes CatCafe_Thumb_P_CafeNamed_v3.png and CatCafe_Thumb_P_v3_BeforeAfter.png into OUT_DIR.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERO, OLD, OUT = sys.argv[1:4]
INTER = "/usr/share/fonts/opentype/inter/"
TITLE, TAG = INTER + "InterDisplay-ExtraBold.otf", INTER + "Inter-Black.otf"
BROWN, YELLOW, WHITE = (110, 62, 38), (255, 214, 92), (255, 255, 255)
CX = 1420

# text, font, cap height, cap top, target width (None = natural), fill, outline px
LINES = [
    ("CATCH A", TITLE, 97, 181, 586, YELLOW, 10),
    ("CAT", TITLE, 175, 355, 469, WHITE, 15),
    ("CAFE", TITLE, 175, 585, 609, WHITE, 15),
    ("Catch strays. Run your cafe.", TAG, 38, 824, 745, WHITE, 6),
]


def sized(path, cap):
    for s in range(10, 500):
        f = ImageFont.truetype(path, s)
        b = f.getbbox("H")
        if b[3] - b[1] >= cap:
            return f
    raise ValueError(cap)


def layout(text, font, width, gap=0.0):
    """x of each glyph's origin, tracked evenly so the inked width matches `width`."""
    xs = [font.getlength(text[:i]) for i in range(len(text))]
    natural = font.getbbox(text)
    ink = natural[2] - natural[0]
    track = 0.0 if width is None or len(text) < 2 else max(gap, (width - ink) / (len(text) - 1))   # never closer than `gap`: an outline must part letters
    xs = [x + i * track for i, x in enumerate(xs)]
    return xs, ink + track * (len(text) - 1), natural


def draw_logo(size):
    text_layer = Image.new("RGBA", size, (0, 0, 0, 0))
    shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    td, sd = ImageDraw.Draw(text_layer), ImageDraw.Draw(shadow)
    for text, path, cap, top, width, fill, stroke in LINES:
        font = sized(path, cap)
        xs, inked, natural = layout(text, font, width, gap=0.5 * stroke)
        h_top = font.getbbox("H")[1]
        x0 = CX - inked / 2 - natural[0]
        y0 = top - h_top
        for x, ch in zip(xs, text):
            p = (x0 + x, y0)
            sd.text((p[0], p[1] + stroke * 0.6), ch, font=font, fill=(60, 30, 15, 150), stroke_width=stroke,
                    stroke_fill=(60, 30, 15, 150))
        for x, ch in zip(xs, text):            # outlines first, so a letter's outline never covers its neighbour
            td.text((x0 + x, y0), ch, font=font, fill=BROWN, stroke_width=stroke, stroke_fill=BROWN)
        for x, ch in zip(xs, text):
            td.text((x0 + x, y0), ch, font=font, fill=fill)
    shadow = shadow.filter(ImageFilter.GaussianBlur(8))
    return Image.alpha_composite(shadow, text_layer)


hero = Image.open(HERO).convert("RGBA")
assert hero.size == (1920, 1080), hero.size
final = Image.alpha_composite(hero, draw_logo(hero.size)).convert("RGB")
os.makedirs(OUT, exist_ok=True)
final_path = os.path.join(OUT, "CatCafe_Thumb_P_CafeNamed_v3.png")
final.save(final_path, optimize=True)

old = Image.open(OLD).convert("RGB")
tw, th, pad, head = 960, 540, 24, 70
sheet = Image.new("RGB", (2 * tw + 3 * pad, th + 2 * pad + head), (255, 247, 236))
font = ImageFont.truetype(TITLE, 40)
for i, (label, im) in enumerate((("Before (v2)", old), ("After (v3)", final))):
    x = pad + i * (tw + pad)
    sheet.paste(im.resize((tw, th), Image.LANCZOS), (x, head + pad))
    ImageDraw.Draw(sheet).text((x + tw // 2, head // 2 + 8), label, font=font, fill=WHITE, anchor="mm",
                               stroke_width=4, stroke_fill=BROWN)
sheet.save(os.path.join(OUT, "CatCafe_Thumb_P_v3_BeforeAfter.png"), optimize=True)
print("wrote", final_path, os.path.getsize(final_path) // 1024, "KB")
