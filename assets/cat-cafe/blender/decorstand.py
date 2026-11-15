"""The decor stand beside the Golden Fish Market (#4516, Derek2 2026-11-15: "add a little decor stand beside the fish
market so people know thats where to get decor one player was confused"): a small two-step display table with a
striped skirt, a Cafe Crate on the front step and two real decor pieces on the back one (the Mushroom Lamp and the
Lantern Stump), under a board on two posts that reads DECOR CRATES, with a gold arrow on top pointing at the market.
From behind the board is planked with a painted paw.

  CatCafe_Square_DecorStand                 table, skirt, posts, board, words, arrow, back (collides)
  CatCafe_Square_DecorStand_Crate_Decor     the Classic Cafe Crate (crates.build_crate), 0.62 times its size, and
  CatCafe_Square_DecorStand_Crate_Lid_Decor its lid, shut
  CatCafe_Square_DecorStand_Lamp...         the Mushroom Lamp (crate_decor), half size; its parts keep their own
  CatCafe_Square_DecorStand_Stump...        endings, and the Lantern Stump, 0.55 times its size

The pieces are the game's own models, scaled and baked into the stand's frame, so they always match what a crate
gives. Pivot at the base centre on the square's floor top (y 0.1), front -Z. Footprint about 5.0 x 2.6 studs, 6.6
tall. No scripts. The arrow points to the reader's left (+X), where the market stands when the stand is at SPOT.
"""

from mathutils import Matrix, Vector

import crate_decor
import crates
from alleyway import label
from common import RB, bake_transform
from pitysign import _paw

NAME = "CatCafe_Square_DecorStand"

TW = 4.6                            # the table's width
LOW, HIGH = 1.1, 1.95               # the two steps' tops
Z0, ZM, Z1 = -1.75, -0.3, 0.75      # front edge, the step between them, back edge
BY0, BY1 = 4.45, 5.95               # the board's bottom and top
BW = 4.2
ZF, ZB = Z1 - 0.2, Z1 + 0.04        # the board's front and back
FRAME, PIPE, FACE = "sign_teal", "rarity_legend", "cream"
WOOD, DARK = "caramel_wood", "dark_wood"
STRIPES = ("cream", "sign_teal")
POST_X = TW / 2 - 0.12

# Model-Agent's spot (world x, y, z, rotY): just past the market's end on the Day Cart's side, 1 stud clear of the
# market and 6 or more from everything else on the square (world scan of main 44eddd9), turned to face the spawn at
# (0, -14). The market is then on the reader's left, where the arrow points. The server's Layout owns the spot.
SPOT = (37.8, 0.1, 57.4, 27.9)


def _table(b):
    b.span((-TW / 2, LOW - 0.14, Z0), (TW / 2, LOW, ZM), WOOD)
    b.span((-TW / 2, HIGH - 0.14, ZM), (TW / 2, HIGH, Z1 - 0.22), WOOD)
    b.span((-TW / 2, LOW, ZM - 0.04), (TW / 2, HIGH - 0.14, ZM + 0.06), DARK)             # the riser
    for (x0, x1, z0, z1) in ((-TW / 2 - 0.03, TW / 2 + 0.03, Z0 - 0.04, Z0 + 0.02),):                    # gold edge on the front
        b.span((x0, LOW - 0.16, z0), (x1, LOW + 0.02, z1), PIPE)
    # the skirt: stripes down the front and both sides, a hand off the floor
    n = 8
    for i in range(n):
        xa, xb = -TW / 2 + i * TW / n, -TW / 2 + (i + 1) * TW / n
        b.span((xa, 0.12, Z0 + 0.03), (xb, LOW - 0.16, Z0 + 0.09), STRIPES[i % 2])
    for s in (-1, 1):
        for i in range(4):
            za, zb = Z0 + 0.09 + i * (Z1 - 0.3 - Z0) / 4, Z0 + 0.09 + (i + 1) * (Z1 - 0.3 - Z0) / 4
            x = s * (TW / 2 - 0.03)
            b.span((min(x, x - s * 0.06), 0.12, za), (max(x, x - s * 0.06), LOW - 0.16, zb), STRIPES[(i + 1) % 2])
    for sx in (-1, 1):                                                                     # legs
        for z in (Z0 + 0.2, ZM, Z1 - 0.4):
            b.span((sx * (TW / 2 - 0.2) - 0.09, 0.0, z - 0.09), (sx * (TW / 2 - 0.2) + 0.09, LOW - 0.14, z + 0.09), DARK)


def _board(b):
    for s in (-1, 1):
        x = s * POST_X
        b.span((x - 0.12, 0.0, Z1 - 0.2), (x + 0.12, BY0 + 0.02, Z1 + 0.04), DARK)
        b.span((x - 0.24, 0.0, Z1 - 0.45), (x + 0.24, 0.18, Z1 + 0.3), DARK)
    b.span((-BW / 2, BY0, ZF), (BW / 2, BY1, ZB), FACE)
    hx = BW / 2 + 0.14
    for (x0, x1, y0, y1) in ((-hx, hx, BY0 - 0.14, BY0), (-hx, hx, BY1, BY1 + 0.14),
                             (-hx, -BW / 2, BY0, BY1), (BW / 2, hx, BY0, BY1)):
        b.span((x0, y0, ZF - 0.07), (x1, y1, ZB + 0.07), FRAME)
    for (x0, x1, y0, y1) in ((-BW / 2, BW / 2, BY0, BY0 + 0.05), (-BW / 2, BW / 2, BY1 - 0.05, BY1)):
        b.span((x0, y0, ZF - 0.03), (x1, y1, ZF - 0.005), PIPE)
    label(b, "DECOR", 0.0, BY1 - 0.16 - 5 * 0.125, ZF - 0.02, 0.125, 0.06, "royal_berry", -1)
    label(b, "CRATES", 0.0, BY0 + 0.15, ZF - 0.02, 0.085, 0.05, "dumpster_green", -1)
    # the arrow on top, pointing at the market (+X, the reader's left)
    y = BY1 + 0.14
    for x in (-0.9, 0.5):
        b.span((x - 0.05, y - 0.01, ZF + 0.07), (x + 0.05, y + 0.22, ZF + 0.17), DARK)
    zc = (ZF + ZB) / 2
    b.span((-1.3, y + 0.22, zc - 0.06), (0.8, y + 0.48, zc + 0.06), PIPE)
    b.fan_z(zc, (1.5, y + 0.35), [(0.8, y + 0.68), (0.8, y + 0.02)], 0.12, PIPE)
    # the back: planks and a painted paw
    for i in range(1, 5):
        x = -BW / 2 + i * BW / 5
        b.span((x - 0.035, BY0 + 0.08, ZB - 0.01), (x + 0.035, BY1 - 0.08, ZB + 0.02), DARK)
    _paw(b, 0.0, (BY0 + BY1) / 2 - 0.03, ZB + 0.03, 0.9, PIPE)


def _mount(objs, asset, tag, k, at):
    """Scale a built model's parts by k about its pivot and stand that pivot at `at` (Roblox studs), baked into the
    stand's frame. Each part is renamed <stand>_<tag><its own ending>, the body itself <stand>_<tag>_Decor, and a
    part with no special ending gets _Decor too, so nothing on the table collides."""
    keep = ("_Glow", "_Glass", "_Bulb")
    out = []
    for ob in objs:
        end = ob.name[len(asset):]
        ob.matrix_world = Matrix.Translation(Vector(RB.p(*at))) @ Matrix.Scale(k, 4) @ Matrix.Translation(ob.location)
        bake_transform(ob)
        ob.name = NAME + "_" + tag + (end if end.endswith(keep) else end + "_Decor")
        out.append(ob)
    return out


def build_decor_stand(mat):
    b = RB()
    _table(b)
    _board(b)
    out = [b.finalize(NAME, mat)]
    out += _mount(crates.build_crate("Classic", mat), "CatCafe_Prop_Crate_Classic", "Crate", 0.62,
                  (0.0, LOW, (Z0 + ZM) / 2))
    out += _mount(crate_decor.build_mushroom_lamp(mat), "CatCafe_Decor_MushroomLamp", "Lamp", 0.5,
                  (-1.45, HIGH, (ZM + Z1) / 2 - 0.12))
    out += _mount(crate_decor.build_lantern_stump(mat), "CatCafe_Decor_LanternStump", "Stump", 0.55,
                  (1.45, HIGH, (ZM + Z1) / 2 - 0.12))
    return out


ASSETS = {
    NAME: (build_decor_stand, 6000),
}
