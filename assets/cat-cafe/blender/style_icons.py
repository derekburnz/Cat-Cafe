"""Sample models for the Cafe Crate styles (Set 5 Q10, Derek 2026-10-29: "lots of the decors are missing a
picture"). A wallpaper, floor or paint is only a colour and a material on the cafe's tagged parts (StyleController),
so it has no model of its own, and the Decor screens showed a glyph for all 36. ItemIcon draws the model named by
the piece's `asset` (Catalog: CatCafe_Style_<Name>, the name without spaces or marks), so each style gets a small
sample here, front -Z, pivot at the base centre:

  wallpaper   a piece of wall in the style, with a cream skirting board and cornice and a little framed picture
  floor       a square of floor in the style, a cream skirting strip at the back and a cat bowl on it
  paint       an open tin with a band, the paint inside and a drip down the front, a brush beside it

The style's own colour and material come from the parts named <asset>_Swatch, read from the CRATE_PIECES rows of
games/cat-cafe/src/shared/Catalog.luau at build time (`color = Color3.fromRGB(r, g, b)`, `material =
Enum.Material.X`), so a sample always matches what the cafe shows. A row the parser cannot read stops the build.
Nothing in game places these models; they are pictures only.
"""
import os
import re

import rbx_export
from common import RB

HERE = os.path.dirname(os.path.abspath(__file__))
CATALOG = os.path.join(HERE, "..", "..", "..", "games", "cat-cafe", "src", "shared", "Catalog.luau")
STYLED = ("wallpaper", "floor", "paint")
ROW = re.compile(r'\{\s*id = "([^"]+)",\s*name = "([^"]+)",\s*kind = "([^"]+)",(.*?)\n\t\t\}', re.S)


def _rows():
    """(id, name, kind, (r, g, b) 0..255, material) for every styled crate piece in the catalog."""
    src = open(CATALOG, encoding="utf-8").read()
    start = src.index("local CRATE_PIECES")
    block = src[start:src.index("\n}\n", start)]
    rows = []
    for m in ROW.finditer(block):
        pid, name, kind, rest = m.groups()
        if kind not in STYLED:
            continue
        c = re.search(r"color = Color3\.fromRGB\((\d+),\s*(\d+),\s*(\d+)\)", rest)
        mt = re.search(r"material = Enum\.Material\.(\w+)", rest)
        if not c:
            raise ValueError(f"style_icons: no colour for {pid} in Catalog.luau")
        rows.append((pid, name, kind, tuple(int(v) for v in c.groups()), mt.group(1) if mt else "SmoothPlastic"))
    if len(rows) < 30:
        raise ValueError(f"style_icons: read only {len(rows)} styled rows from Catalog.luau")
    return rows


def asset_name(name):
    return "CatCafe_Style_" + re.sub(r"[^A-Za-z0-9]", "", name)


def _wallpaper(name, mat):
    b, sw = RB(), RB()
    sw.span((-1.2, 0.3, 0.0), (1.2, 3.0, 0.2), "cream")                        # the wall in the style
    b.span((-1.3, 0.0, -0.08), (1.3, 0.36, 0.24), "offwhite")                   # skirting board
    b.span((-1.36, 2.96, -0.12), (1.36, 3.2, 0.24), "offwhite")                 # cornice
    b.span((-0.48, 1.42, -0.07), (0.48, 2.3, 0.02), "gold_mid")                 # a little framed picture
    b.span((-0.38, 1.52, -0.09), (0.38, 2.2, -0.05), "pastel_sky")
    b.span((-0.26, 1.56, -0.115), (0.06, 1.8, -0.075), "leaf_green")            # a hill, a sun
    b.span((0.12, 1.94, -0.115), (0.26, 2.08, -0.075), "pastel_butter")
    return [b.finalize(name, mat), sw.finalize(name + "_Swatch", mat)]


def _floor(name, mat):
    b, sw = RB(), RB()
    sw.span((-1.3, 0.0, -1.3), (1.3, 0.24, 1.3), "cream")                       # the floor in the style
    b.span((-1.36, 0.1, 1.1), (1.36, 0.7, 1.36), "offwhite")                    # skirting at the back
    b.cyl((0.55, 0.32, -0.45), 0.36, 0.2, "blush", r2=0.42, segments=12)       # a cat bowl
    b.cyl((0.55, 0.41, -0.45), 0.3, 0.04, "fur_orange_dark", segments=12)      # kibble in it
    return [b.finalize(name, mat), sw.finalize(name + "_Swatch", mat)]


def _paint(name, mat):
    b, sw = RB(), RB()
    b.cyl((0.0, 0.55, 0.0), 0.62, 1.1, "fur_silver", segments=14)             # the tin
    sw.cyl((0.0, 0.5, 0.0), 0.64, 0.46, "cream", segments=14)                 # its band
    sw.cyl((0.0, 1.11, 0.0), 0.55, 0.06, "cream", segments=14)                # the paint inside, a rim round it
    sw.span((-0.12, 0.72, -0.66), (0.0, 1.12, -0.55), "cream")                 # a drip down the front
    sw.span((-0.1, 0.64, -0.67), (-0.02, 0.74, -0.58), "cream")
    b.span((0.62, 0.01, -1.0), (1.55, 0.12, -0.86), "caramel_wood")           # a brush beside it
    b.span((0.4, 0.0, -1.03), (0.66, 0.16, -0.83), "fur_silver")             # its ferrule, on the ground
    sw.span((0.1, 0.01, -1.02), (0.44, 0.13, -0.84), "cream")                 # its bristles, dipped
    return [b.finalize(name, mat), sw.finalize(name + "_Swatch", mat)]


BUILDERS = {"wallpaper": _wallpaper, "floor": _floor, "paint": _paint}
BUDGET = 400
ASSETS = {}
for _pid, _name, _kind, _rgb, _material in _rows():
    _asset = asset_name(_name)

    def _build(mat, _asset=_asset, _kind=_kind):
        return BUILDERS[_kind](_asset, mat)

    ASSETS[_asset] = (_build, BUDGET)
    rbx_export.LOOKS[_asset + "_Swatch"] = ([round(v / 255, 4) for v in _rgb], _material)
del _pid, _name, _kind, _rgb, _material, _asset
