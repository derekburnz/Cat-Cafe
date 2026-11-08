"""Floor style textures (#2256): tileable pictures a floor style lays over the cafe's Floor parts, for a style whose
look a Roblox material alone can't give.

  CatCafe_Tex_LeafLitter   512 x 512, seamless: a dark loam base under three layers of autumn leaves (back darker,
                           front brighter), each leaf a pointed oval with a midrib and side veins, drawn wrapped so
                           the tile repeats with no seam. For the Leaf Litter floor (`woods_leaf_litter`), whose
                           brown Ground material alone read as bare dirt (Derek2 11-07: "floor glitches out and goes
                           missing").

Plain Python with Pillow, no Blender (Blender's Python has no PIL): `python floortex.py` writes every texture into
assets/cat-cafe/exports/, and build_all.py lists them in the manifest's `textures`. The seed is fixed, so the picture
is the same on every run.
"""

import math
import os
import random
import sys

LEAF_LITTER = "CatCafe_Tex_LeafLitter"
SIZE = 512
STUDS_PER_TILE = 6          # one tile every 6 studs: a leaf reads at about 0.6 to 0.9 studs, about a cat's paw
LOAM = (92, 62, 38)
LOAM_SPECKS = ((78, 52, 32), (104, 72, 44), (70, 48, 30))
LEAVES = ((214, 120, 48), (226, 150, 62), (196, 84, 44), (232, 182, 78), (170, 96, 46), (186, 62, 40),
          (150, 110, 52), (238, 196, 102))
SHADOW = (70, 46, 28)
LAYERS = ((140, 0.7), (120, 0.86), (90, 1.0))       # leaves per layer and its brightness, back to front


def _shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def leaf_litter(size=SIZE, ss=2, seed=2256):
    """The leaf litter tile as a PIL RGB image, drawn at `ss` times the size and scaled down."""
    from PIL import Image, ImageDraw   # here, so build_all.py can import this module under bpy for the manifest
    W = size * ss
    rng = random.Random(seed)
    img = Image.new("RGB", (W, W), LOAM)
    d = ImageDraw.Draw(img)
    for _ in range(9000):
        x, y = rng.randrange(W), rng.randrange(W)
        c = rng.choice(LOAM_SPECKS)
        r = rng.randint(1, 3) * ss
        d.ellipse([x - r, y - r, x + r, y + r], fill=c)

    def leaf(cx, cy, L, wid, ang, col, k):
        outline = []
        for i in range(25):
            t = i / 24
            outline.append(((t - 0.5) * L, math.sin(math.pi * t) ** 0.8 * wid / 2))
        outline += [(x, -y) for x, y in reversed(outline[1:-1])]
        ca, sa = math.cos(ang), math.sin(ang)
        for ox in (-W, 0, W):                           # every copy that touches the tile, so it wraps
            for oy in (-W, 0, W):
                P = [(cx + ox + x * ca - y * sa, cy + oy + x * sa + y * ca) for x, y in outline]
                if max(p[0] for p in P) < 0 or min(p[0] for p in P) > W or max(p[1] for p in P) < 0 or \
                        min(p[1] for p in P) > W:
                    continue
                d.polygon([(px + 3 * ss, py + 4 * ss) for px, py in P], fill=_shade(SHADOW, 0.85))   # soft shadow
                d.polygon(P, fill=_shade(col, k), outline=_shade(col, k * 0.7))
                vein = _shade(col, k * 0.72)

                def at(x, y):
                    return (cx + ox + x * ca - y * sa, cy + oy + x * sa + y * ca)
                d.line([at(-L / 2 - L * 0.12, 0), at(L / 2 * 0.92, 0)], fill=vein, width=max(1, int(1.6 * ss)))
                for j in range(1, 5):                                                  # side veins
                    x0 = -L / 2 + L * j / 5
                    for s in (-1, 1):
                        d.line([at(x0, 0), at(x0 + L * 0.12, s * wid * 0.32)], fill=vein, width=max(1, ss))

    for count, k in LAYERS:
        for _ in range(count):
            L = rng.uniform(46, 78) * ss
            leaf(rng.uniform(0, W), rng.uniform(0, W), L, L * rng.uniform(0.42, 0.6), rng.uniform(0, math.tau),
                 rng.choice(LEAVES), k * rng.uniform(0.9, 1.08))
    return img.resize((size, size), Image.LANCZOS)


def write_leaf_litter_png(path):
    leaf_litter().save(path, optimize=True)
    return path


def manifest_entry(png, root):
    return {"file": os.path.relpath(png, root), "size_px": SIZE, "format": "PNG RGB, seamless tile",
            "use": "a Texture on the Top face of every Floor-tagged part while the Leaf Litter floor style "
                   "(woods_leaf_litter) shows; removed with the style",
            "suggested_texture": {"Face": "Top", "StudsPerTileU": STUDS_PER_TILE, "StudsPerTileV": STUDS_PER_TILE,
                                  "Color3": "white (the picture's own colours)", "Transparency": 0,
                                  "part": "Color (160, 100, 50) and Material Ground stay under it, so the floor "
                                          "keeps its catalog look where the texture hasn't loaded"}}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                                                              "exports", LEAF_LITTER + ".png")
    print(write_leaf_litter_png(os.path.normpath(out)))
