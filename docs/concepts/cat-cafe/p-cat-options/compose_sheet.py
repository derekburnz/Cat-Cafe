"""Labels the #1032 lineup and tiles the current P with the three options into one comparison sheet."""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

SRC, OUT, OLD_P = sys.argv[1], sys.argv[2], sys.argv[3]
BOLD = "/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf"
INK, CREAM = (74, 44, 30), (255, 247, 236)


def font(px):
    return ImageFont.truetype(BOLD, px)


def label(im, xy, text, px, anchor="mm"):
    d = ImageDraw.Draw(im)
    d.text(xy, text, font=font(px), fill="white", anchor=anchor, stroke_width=max(2, px // 9), stroke_fill=INK)


os.makedirs(OUT, exist_ok=True)
lineup = Image.open(os.path.join(SRC, "P_cat_options_lineup.png")).convert("RGB")
names = ["A  Bellhop Cat", "B  Blossom", "C  Forest Cat", "now: Ginger (P)", "Tabby", "Tuxedo"]
w, h = lineup.size
# the six cats stand 1.4 studs apart about the middle; their screen x was read off the render
xs = [0.135, 0.273, 0.411, 0.56, 0.70, 0.846]
for x, n in zip(xs, names):
    label(lineup, (int(x * w), int(h * 0.8)), n, 34)
label(lineup, (w // 2, int(h * 0.07)), "Same scale: the three P options next to today's P cat and two everyday cats", 30)
lineup.save(os.path.join(OUT, "P_cat_options_lineup.png"))

tiles = [("Now", OLD_P)] + [(t, os.path.join(SRC, f"P_cat_option_{n}.png"))
                            for t, n in (("A  Bellhop Cat", "BellhopCat"), ("B  Blossom", "Blossom"), ("C  Forest Cat", "ForestCat"))]
tw, th, pad = 960, 540, 24
sheet = Image.new("RGB", (2 * tw + 3 * pad, 2 * th + 3 * pad + 70), CREAM)
for i, (t, p) in enumerate(tiles):
    im = Image.open(p).convert("RGB").resize((tw, th), Image.LANCZOS)
    x, y = pad + (i % 2) * (tw + pad), 70 + pad + (i // 2) * (th + pad)
    sheet.paste(im, (x, y))
    label(sheet, (x + 20, y + 20), t, 40, anchor="la")
label(sheet, (sheet.width // 2, 42), "#1032: a better cat for P (logo goes in the clear right half)", 40)
sheet.save(os.path.join(OUT, "P_cat_options_sheet.png"))
print("done")
