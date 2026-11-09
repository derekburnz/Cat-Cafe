"""Pictures for the Cafe Pass rewards and Style tab rows that still showed a symbol (Derek2, 2026-11-09: "these place
holders in pass need fixes"): the uniform colours (a 👕 on the colour's tile) and the chat tags (a 🏷️). Rendered by
icons.py as CatCafe_Icon_Uniform_<Style> and CatCafe_Icon_Tag_<Tag> (transparent, outlined, 512 px), the same kit
as the Store pictures.

Uniforms   the barista's apron laid out flat and drawn big with the barista cap hung on its strap, so the colour fills
           the tile (a cat wearing them read too small at tile size). The cap is the real piece recoloured the way
           CatDress.wearUniform does it in game: the colour with the most surface becomes the style's main colour,
           the next its trim (Looks.UNIFORMS). One per style: the Uniform Styles pass's Striped, Midnight and Mint, and Season 1's
           Pumpkin, Acorn Brown, Forest Green and Cranberry.
Tags       a speech bubble in the tag's colour (ChatTags.TAGS) with a cream badge on it: Maple's is a maple leaf in
           autumn red and orange, Grand Opener's a gold star.

Built in Blender axes (x right, -y toward the camera, z up); nothing here is a game model.
"""

import math

import bpy

import accessories
import palette
import seasondecor
import store_icons
from common import Builder

X = (math.radians(90), "X")

# Looks.UNIFORMS, as palette swatches (every colour is one already: Pumpkin is fur_ginger #D9662E, Acorn Brown
# fur_acorn #A0683A, Forest Green dumpster_green #3F6F5E, Cranberry royal_berry #8E2A4A, Midnight pants_navy #2F3E5C
# with fur_golden #F2C14E, Striped cream with caramel_wood, Mint mint with cream)
UNIFORMS = {
    "Striped": ("cream", "caramel_wood"),
    "Midnight": ("pants_navy", "fur_golden"),
    "Mint": ("mint", "cream"),
    "Pumpkin": ("fur_ginger", "cream"),
    "AcornBrown": ("fur_acorn", "cream"),
    "ForestGreen": ("dumpster_green", "cream"),
    "Cranberry": ("royal_berry", "cream"),
}
# the game's ids, for the README and the upload table
UNIFORM_IDS = {"Striped": "striped", "Midnight": "midnight", "Mint": "mint", "Pumpkin": "uniform_pumpkin",
               "AcornBrown": "uniform_acorn_brown", "ForestGreen": "uniform_forest_green",
               "Cranberry": "uniform_cranberry"}


def _swatch_of(u, v):
    col = min(palette.GRID - 1, max(0, int(u * palette.GRID)))
    row = min(palette.ROWS - 1, max(0, int((1.0 - v) * palette.ROWS)))
    i = row * palette.GRID + col
    return palette.SWATCHES[i][0] if i < len(palette.SWATCHES) else None


def recolour(ob, main, trim):
    """CatDress.uniformSlots on one worn piece: the swatch covering the most surface becomes `main`, the next `trim`,
    the rest stay as built. Works on the piece's own copy of its mesh."""
    ob.data = ob.data.copy()
    me = ob.data
    uv = me.uv_layers.active.data
    areas, faces = {}, {}
    for poly in me.polygons:
        sw = _swatch_of(*uv[poly.loop_start].uv)
        areas[sw] = areas.get(sw, 0.0) + poly.area * max(ob.scale) ** 2
        faces.setdefault(sw, []).append(poly)
    order = sorted(areas, key=lambda k: (-areas[k], k or ""))
    for sw, target in zip(order, (main, trim)):
        cu, cv = palette.uv_center(palette.idx(target))
        for poly in faces[sw]:
            for li in poly.loop_indices:
                uv[li].uv = (cu, cv)


_APRON_HALF = ((0.0, 2.2), (0.42, 2.2), (0.45, 2.0), (0.5, 1.82), (0.58, 1.64), (0.7, 1.5), (0.82, 1.42),
               (0.84, 1.3), (0.88, 0.22), (0.84, 0.08), (0.74, 0.0), (0.0, 0.0))
APRON = _APRON_HALF[:-1] + tuple((-x, z) for x, z in reversed(_APRON_HALF[:-1])) + (_APRON_HALF[0],)


def uniform(style):
    """The uniform itself, drawn big so its colour fills the tile: the barista's apron laid out flat (main colour,
    with a trim pocket and hem and a trim paw on the bib), its neck strap and waist ties, and the barista cap (the
    real piece, recoloured like the game does) hung on the strap."""
    main, trim = UNIFORMS[style]

    def build(mat):
        b = Builder()
        b.fan((0, 0, 0), (0.0, 1.2), APRON, 0.12, main, rot=X)                                # the apron
        b.box((0, -0.08, 0.14), (1.74, 0.06, 0.2), trim, bevel=False)                         # hem band
        b.box((0, -0.1, 0.78), (0.98, 0.08, 0.5), trim)                                       # pocket
        b.box((0, -0.15, 0.98), (0.98, 0.04, 0.06), main, bevel=False)                        # its edge stitch
        store_icons._paw(b, 0.0, -0.09, 1.8, 0.75, trim)                                      # a paw on the bib
        b.ring((0, 0.04, 2.55), 0.42, 0.07, 0.07, main, segments=20, rot=X)                   # neck strap
        for sx in (-1, 1):                                                                    # the waist ties,
            b.box((sx * 0.9, -0.03, 1.37), (0.16, 0.08, 0.14), main)                         # hanging loose
            for k, (dx, ang, ln) in enumerate(((0.07, 24, 0.56), (0.0, 8, 0.46))):
                c = math.radians(ang)
                b.box((sx * (0.95 + dx + ln / 2 * math.sin(c)), -0.02 - 0.02 * k, 1.34 - ln / 2 * math.cos(c)),
                      (0.09, 0.05, ln), main, bevel=False, rot=(math.radians(sx * ang), "Y"))
        cap = accessories.build_barista_cap(mat)
        for ob in cap:
            recolour(ob, main, trim)
        cap = store_icons.place(cap, at=(0.28, -0.25, 2.6), scale=2.8, tilt=-12, roll=-14)
        store_icons._twinkle(b, -1.05, -0.3, 2.45, 0.24)
        return store_icons._fin(b, "Uniform_" + style, mat) + cap
    return build


# --- chat tags ----------------------------------------------------------------------------------------------------

# ChatTags.TAGS colour -> the nearest swatch: tag_maple #D9822B is fur_marmalade #E18C3C, tag_grand_opener #F5A65B
# paw_neighbourhood #F09640
TAGS = {"Maple": ("tag_maple", "fur_marmalade"), "GrandOpener": ("tag_grand_opener", "paw_neighbourhood")}


def _bubble(b, sw, W=2.5, H=1.7, D=0.42, z=1.25, r=0.62):
    """A chunky rounded speech bubble facing the camera (one rounded rectangle, so no seams), its tail at the lower
    left a little thinner so their faces never share a plane."""
    pts = []
    for cx, cz, a0 in ((W / 2 - r, H / 2 - r, 0), (-W / 2 + r, H / 2 - r, 90), (-W / 2 + r, -H / 2 + r, 180),
                       (W / 2 - r, -H / 2 + r, 270)):
        pts += [(cx + r * math.cos(math.radians(a0 + 10 * k)), cz + r * math.sin(math.radians(a0 + 10 * k)))
                for k in range(10)]
    pts.append(pts[0])
    b.fan((0, 0, z), (0.0, 0.0), pts, D, sw, rot=X)
    b.prism((-0.45, 0, z - H / 2 + 0.06), [(-0.35, 0.0), (0.35, 0.0), (-0.6, -0.62)], D - 0.08, sw, rot=X)


def tag(name):
    tag_id, sw = TAGS[name]

    def build(mat):
        b = Builder()
        _bubble(b, sw)
        b.cyl((0, -0.24, 1.25), 0.62, 0.08, "offwhite", segments=28, rot=X)            # the cream badge
        if name == "Maple":
            seasondecor.maple_leaf(b, (0.0, -0.32, 1.27), 1.0, 0.08, "fur_rust_red", rot=X)
            b.box((0.0, -0.37, 0.75), (0.07, 0.04, 0.3), "fur_rust_red", bevel=False)  # the stem
        else:
            store_icons._star(b, 0.0, -0.32, 1.25, 0.5)
        store_icons._twinkle(b, 1.3, -0.4, 2.15, 0.3)
        store_icons._twinkle(b, -1.2, -0.4, 2.05, 0.2)
        return store_icons._fin(b, "Tag_" + name, mat)
    return build


ICONS = {**{f"CatCafe_Icon_Uniform_{s}": uniform(s) for s in UNIFORMS},
         **{f"CatCafe_Icon_Tag_{n}": tag(n) for n in TAGS}}
VIEWS = {**{f"CatCafe_Icon_Uniform_{s}": (-24.0, 8.0) for s in UNIFORMS},
         **{f"CatCafe_Icon_Tag_{n}": (0.0, 0.0) for n in TAGS}}
