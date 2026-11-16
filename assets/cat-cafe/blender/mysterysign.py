"""The Mystery Market's signboard (#4508, Derek2 2026-11-15: "make a signboard beside the mystery market ... that shows
the new items like backpack/shoes on it so people know where that is"): a standing board beside Juniper's wagon in
the wagon's own colours. A cream face in a berry frame with gold piping on two dark posts, NEW ITEMS across the top,
the Backpack hanging from a gold peg on one half and the pair of Speed Shoes on a little wooden shelf on the other,
each with its name under it (BACKPACK, SHOES), and a gold arrow on top pointing at the wagon. From behind the face is planked with a
painted paw.

  CatCafe_Square_MysterySign                  frame, face, words, posts, shelf, arrow, back (collides)
  CatCafe_Square_MysterySign_Backpack_Decor   the Backpack (mysteryitems' own pack and lid, 1.25 times its size)
  CatCafe_Square_MysterySign_Shoes_Decor      the two Speed Shoes (mysteryitems' own shoe, 0.75 times its size, turned
                                              a little so the paw and the wing on the outer side show)

Pivot at the base centre on the square's floor top (y 0.1), front -Z. Footprint about 5.3 x 2.8 studs with the shelf, 7.5 tall.
Nothing Neon, no scripts. The arrow points to the reader's left (+X), where the wagon stands when the board is at
SPOT. When the shelf gets a new item, add it here and rebuild: the board is a picture of the shelf, not a live list.
"""

import math

from mathutils import Matrix, Vector

import mysteryitems
from alleyway import label
from common import RB, bake_transform
from mysterymarket import _star
from pitysign import _paw

NAME = "CatCafe_Square_MysterySign"

BW = 5.0                            # the face's width
Y0, Y1 = 2.55, 6.45                 # its bottom and top
ZF, ZB = -0.12, 0.12                # its front and back
FR = 0.16                           # the frame round it
FRAME, PIPE, FACE = "royal_berry", "rarity_legend", "cream"
WOOD, DARK = "caramel_wood", "dark_wood"
TEAL = "dumpster_green"             # the wagon's body colour, for the item names
POST_X = 1.75
PACK_X, SHOES_X = 1.25, -1.25       # the reader sees +X on the left: Backpack left, Speed Shoes right
PACK_K, SHOE_K = 1.25, 0.75
SHELF_Y = 3.72                      # the shoe shelf's top
SHOE_YAW = 14                       # degrees: the toes turn toward the board's middle

# Model-Agent's spot (world x, y, z, rotY): just past the wagon's far end (its easel and "?" board), 1 stud clear of
# the wagon and 4 or more from everything else on the square (world scan of main 44eddd9), turned to face the spawn
# at (0, -14). The wagon is then on the reader's left, where the arrow points. The server's Layout owns the spot.
SPOT = (-37.1, 0.1, -58.4, -140.1)


def _board(b):
    b.span((-BW / 2, Y0, ZF), (BW / 2, Y1, ZB), FACE)
    hx = BW / 2 + FR
    for (x0, x1, y0, y1) in ((-hx, hx, Y0 - FR, Y0), (-hx, hx, Y1, Y1 + FR),
                             (-hx, -BW / 2, Y0, Y1), (BW / 2, hx, Y0, Y1)):
        b.span((x0, y0, ZF - 0.08), (x1, y1, ZB + 0.08), FRAME)
    for (x0, x1, y0, y1) in ((-BW / 2, BW / 2, Y0, Y0 + 0.06), (-BW / 2, BW / 2, Y1 - 0.06, Y1),
                             (-BW / 2, -BW / 2 + 0.06, Y0 + 0.06, Y1 - 0.06),
                             (BW / 2 - 0.06, BW / 2, Y0 + 0.06, Y1 - 0.06)):
        b.span((x0, y0, ZF - 0.035), (x1, y1, ZF - 0.005), PIPE)
    # NEW ITEMS, with a gold rule under it and a star either side
    px = 0.1
    ty = Y1 - 0.2 - 5 * px
    label(b, "NEW ITEMS", 0.0, ty, ZF - 0.02, px, 0.06, FRAME, -1)
    b.span((-BW / 2 + 0.3, ty - 0.16, ZF - 0.03), (BW / 2 - 0.3, ty - 0.1, ZF - 0.005), PIPE)
    for s in (-1, 1):
        _star(b, s * (BW / 2 - 0.36), ty + 2.5 * px, ZF - 0.03, 0.3, PIPE)
    # a thin divider between the two items, and their names
    b.span((-0.03, Y0 + 0.5, ZF - 0.03), (0.03, ty - 0.3, ZF - 0.005), PIPE)
    npx = 0.07
    label(b, "BACKPACK", PACK_X, Y0 + 0.2, ZF - 0.02, npx, 0.05, TEAL, -1)
    label(b, "SHOES", SHOES_X, Y0 + 0.2, ZF - 0.02, npx, 0.05, TEAL, -1)
    # the back: planks, a cream panel and a painted paw
    for i in range(1, 6):
        x = -BW / 2 + i * BW / 6
        b.span((x - 0.04, Y0 + 0.1, ZB - 0.01), (x + 0.04, Y1 - 0.1, ZB + 0.02), DARK)
    b.span((-1.0, Y0 + 0.9, ZB + 0.01), (1.0, Y1 - 0.9, ZB + 0.04), WOOD)
    _paw(b, 0.0, (Y0 + Y1) / 2 - 0.05, ZB + 0.05, 1.7, PIPE)


def _fittings(b):
    """The Backpack's gold peg and the Speed Shoes' shelf on two brackets."""
    top = 4.5 + (mysteryitems.Y1 + 0.1) * PACK_K
    b.cyl((PACK_X, top, ZF - 0.2), 0.07, 0.44, PIPE, axis="Z", segments=8)
    b.cyl((PACK_X, top, ZF - 0.43), 0.12, 0.06, PIPE, axis="Z", segments=8)
    x0, x1 = SHOES_X - 1.08, SHOES_X + 1.08
    b.span((x0, SHELF_Y - 0.1, ZF - 1.6), (x1, SHELF_Y, ZF), WOOD)
    b.span((x0 - 0.03, SHELF_Y - 0.13, ZF - 1.63), (x1 + 0.03, SHELF_Y - 0.03, ZF - 1.58), PIPE)
    for x in (x0 + 0.25, x1 - 0.25):
        b.wedge((x, SHELF_Y - 0.28, ZF - 0.45), (0.1, 0.36, 0.9), DARK)


def _arrow(b):
    """A gold arrow standing on the frame's top, pointing at the wagon (+X, the reader's left)."""
    y = Y1 + FR
    for x in (-1.0, 0.6):
        b.span((x - 0.06, y - 0.01, -0.06), (x + 0.06, y + 0.3, 0.06), DARK)
    b.span((-1.5, y + 0.3, -0.07), (0.9, y + 0.62, 0.07), PIPE)
    b.fan_z(0.0, (1.75, y + 0.46), [(0.9, y + 0.86), (0.9, y + 0.06)], 0.14, PIPE)


def _posts(b):
    for s in (-1, 1):
        x = s * POST_X
        b.span((x - 0.18, 0.0, -0.16), (x + 0.18, Y0 - FR + 0.01, 0.16), DARK)
        b.span((x - 0.32, 0.0, -0.55), (x + 0.32, 0.2, 0.55), DARK)
        b.span((x - 0.2, 0.7, -0.18), (x + 0.2, 0.9, 0.18), PIPE)
    b.span((-POST_X, 1.3, -0.07), (POST_X, 1.48, 0.07), DARK)


def _mount(ob, k, at, yaw=0.0):
    """Scale an item part by k about the item's pivot, turn it about the vertical and stand that pivot at `at`
    (Roblox studs), then bake it so the part sits in the board's own frame."""
    spin = Matrix.Rotation(math.radians(yaw), 4, "Z")
    ob.matrix_world = (Matrix.Translation(Vector(RB.p(*at))) @ spin @ Matrix.Scale(k, 4)
                       @ Matrix.Translation(ob.location))
    bake_transform(ob)
    return ob


def build_mystery_sign(mat):
    b, pack = RB(), RB()
    _board(b)
    _fittings(b)
    _arrow(b)
    _posts(b)
    out = [b.finalize(NAME, mat)]
    # the Backpack, its back against the face; the lid is drawn shut in the pack's own frame
    mysteryitems._pack(pack)
    out.append(_mount(pack.finalize(NAME + "_Backpack_Decor", mat), PACK_K, (PACK_X, 4.5, ZF - 0.02)))
    lid = RB()
    mysteryitems._flap(lid)
    out.append(_mount(lid.finalize(NAME + "_BackpackLid_Decor", mat, location=mysteryitems.HINGE), PACK_K,
                      (PACK_X, 4.5, ZF - 0.02)))
    # the pair of Speed Shoes on the shelf
    for tag, s in (("Left", -1), ("Right", 1)):
        shoe = RB()
        mysteryitems._shoe(shoe, s)
        ob = shoe.finalize(NAME + "_Shoe%s_Decor" % tag, mat, location=(s * mysteryitems.SHOE_X, 0.0, 0.0))
        out.append(_mount(ob, SHOE_K, (SHOES_X, SHELF_Y + 0.005, ZF - 0.9), SHOE_YAW))
    return out


ASSETS = {
    NAME: (build_mystery_sign, 6000),
}
