"""The Bellhop Cat's stand in the street plaza (F96, starter-cat.md section 2): a round red-carpeted dais with a gold
rim and velvet ropes on four brass stanchions, and on it a red and gold hotel luggage cart (a birdcage trolley:
carpeted deck on four casters, gold uprights and two arched top rails) with a leather suitcase, a hatbox and a
travel case. The Bellhop Cat sits on the suitcase, and a marquee sign on top of the cart reads FREE CAT! TAKE ME
HOME (FREE CAT! on the back).

  CatCafe_Street_BellhopStand            dais, stanchions, ropes, cart, luggage and the sign (collides); tag
                                         BellhopStand; Attachments PromptAnchor (front of the dais, 3 studs up) and
                                         CatSeat (the cat's pivot on the suitcase, facing -Z)
  CatCafe_Street_BellhopStand_Cat_<Piece> the Bellhop Cat (cats.ROSTER BellhopCat at 1.5 times), the same hinged
                                         pieces as every sitting cat (Head with its eyes and ears, Tail, LegF1, LegF2)
  CatCafe_Street_BellhopStand_Cat_Prop   its cap, inside the Head Model, pivoted at the back of the cap's base
  CatCafe_Street_BellhopStand_Cat_Prop2  its collar and chin strap, inside the Head Model
  CatCafe_Street_BellhopStand_Cat_Bell   its bell, inside the Prop2 Model, pivoted where it hangs (swing it about X)
  CatCafe_Street_BellhopStand_Bulbs      the sign's marquee bulbs, lit at night

Pivot at the base centre, the cart's long side and the sign (-Z) toward the players. The dais is 9.2 across; the sign's
top is 7.8 up.
"""

import math

from mathutils import Matrix, Vector

import cats
from alleyway import label
from common import RB, text_width

NAME = "CatCafe_Street_BellhopStand"
DAIS_R, STONE_H, CARPET_H = 4.6, 0.35, 0.1
FLOOR = STONE_H + CARPET_H                       # the carpet top, where the cart's wheels stand
WHEEL_R = 0.42
DECK_W, DECK_D, DECK_TOP = 5.0, 2.4, 1.45        # the cart's deck: long along X
POLE_X, POLE_Z, POLE_TOP = 2.42, 1.12, 5.2       # the four gold uprights
ARCH_TOP = 6.2                                   # the arched top rails' apex
CASE = (2.4, 1.06, 1.8)                          # the big suitcase the cat sits on (x, y, z)
SEAT_Y = DECK_TOP + 0.06 + CASE[1]               # its top: the cat's pivot
CAT_SCALE = 1.5
SIGN_Y0, SIGN_Y1, SIGN_W = 6.35, 7.65, 4.4       # the marquee board
PROMPT_ROBLOX = (0.0, 3.0, -DAIS_R + 0.6)
STANCHIONS = [(sx * 2.85, sz * 2.85) for sz in (-1, 1) for sx in (-1, 1)]
CAT = dict(cats.ROSTER["BellhopCat"], scale=CAT_SCALE)
RED, GOLD, BRASS = "shirt_red", "rarity_legend", "brass"


def _rod(b, p0, p1, r, sw, segments=8):
    """A round rod between two Roblox points."""
    a, c = Vector(RB.p(*p0)), Vector(RB.p(*p1))
    d = c - a
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix()
    b.b.cyl(tuple((a + c) / 2), r, d.length, sw, segments=segments, bevel=False, rot=rot)


def _dais(b):
    b.cyl((0, STONE_H / 2, 0), DAIS_R, STONE_H, "offwhite", segments=24)
    b.cyl((0, STONE_H + CARPET_H / 2, 0), DAIS_R - 0.3, CARPET_H, RED, segments=24)
    b.b.ring(RB.p(0, STONE_H + 0.065, 0), DAIS_R - 0.18, 0.14, 0.12, GOLD, segments=24, bevel=False)
    for (x, z) in STANCHIONS:                                              # brass posts, gold tops
        b.cyl((x, FLOOR + 0.05, z), 0.32, 0.1, GOLD, segments=12)
        b.cyl((x, FLOOR + 0.85, z), 0.08, 1.5, GOLD, segments=8)
        b.ball((x, FLOOR + 1.66, z), 0.15, GOLD)
    for sx in (-1, 1):                                                     # a velvet rope down each side
        x, z0, z1, top = sx * 2.85, -2.85, 2.85, FLOOR + 1.5
        pts = [(x, top - 0.55 * math.sin(math.pi * k / 6), z0 + (z1 - z0) * k / 6) for k in range(7)]
        pts[0] = (x, top, z0 + 0.1)
        pts[-1] = (x, top, z1 - 0.1)
        for p, q in zip(pts, pts[1:]):
            _rod(b, p, q, 0.07, RED, segments=6)


def _wheel(b, x, z):
    y = FLOOR + WHEEL_R
    b.cyl((x, y, z), WHEEL_R, 0.22, "fur_black", axis="Z", segments=12)
    b.cyl((x, y, z), 0.17, 0.24, GOLD, axis="Z", segments=8)
    b.span((x - 0.18, DECK_TOP - 0.32, z - 0.18), (x + 0.18, DECK_TOP - 0.2, z + 0.18), BRASS)    # the swivel
    for sz in (-1, 1):                                                                           # the fork
        b.span((x - 0.08, y - 0.05, z + sz * 0.13), (x + 0.08, DECK_TOP - 0.31, z + sz * 0.17), BRASS)


def _cart(b):
    for x in (-1.9, 1.9):
        for z in (-0.82, 0.82):
            _wheel(b, x, z)
    b.span((-DECK_W / 2, DECK_TOP - 0.2, -DECK_D / 2), (DECK_W / 2, DECK_TOP, DECK_D / 2), "dark_wood")
    b.span((-2.38, DECK_TOP - 0.01, -1.08), (2.38, DECK_TOP + 0.06, 1.08), RED)                       # carpet
    for sz in (-1, 1):                                                                              # gold rim
        b.span((-2.5, DECK_TOP - 0.02, sz * 1.1 - 0.05), (2.5, DECK_TOP + 0.1, sz * 1.1 + 0.05), GOLD)
    for sx in (-1, 1):
        b.span((sx * 2.4 - 0.05, DECK_TOP - 0.02, -1.05), (sx * 2.4 + 0.05, DECK_TOP + 0.1, 1.05), GOLD)
    poles = [(sx * POLE_X, sz * POLE_Z) for sx in (-1, 1) for sz in (-1, 1)]
    for (x, z) in poles:                                                                            # uprights
        b.cyl((x, (DECK_TOP + POLE_TOP) / 2, z), 0.08, POLE_TOP - DECK_TOP + 0.04, GOLD, segments=8)
        b.cyl((x, DECK_TOP + 0.04, z), 0.14, 0.08, GOLD, segments=8)
    for sx in (-1, 1):                                                                              # end rails
        for y in (2.35, POLE_TOP - 0.06):
            _rod(b, (sx * POLE_X, y, -POLE_Z - 0.02), (sx * POLE_X, y, POLE_Z + 0.02), 0.06, GOLD)
    n = 6
    for sz in (-1, 1):                                                                              # arched rails
        z = sz * POLE_Z
        pts = [(POLE_X * t, POLE_TOP + (ARCH_TOP - POLE_TOP) * (1 - t * t), z)
               for t in (-1 + 2 * k / n for k in range(n + 1))]
        for p, q in zip(pts, pts[1:]):
            _rod(b, p, q, 0.07, GOLD)
        for p in pts[1:-1]:                                                                         # round joints
            b.b.sphere(RB.p(*p), 0.075, GOLD, segments=8, rings=4)
    for x in (-1.4, 1.4):                                                                           # cross rails
        y = POLE_TOP + (ARCH_TOP - POLE_TOP) * (1 - (x / POLE_X) ** 2)
        _rod(b, (x, y, -POLE_Z - 0.02), (x, y, POLE_Z + 0.02), 0.06, GOLD)
        b.cyl((x, (y + SIGN_Y0) / 2, 0), 0.06, SIGN_Y0 - y + 0.06, GOLD, segments=8)               # sign posts
    for (x, z) in poles:
        b.ball((x, POLE_TOP + 0.12, z), 0.16, GOLD)


def _luggage(b):
    w, h, d = CASE
    y0 = DECK_TOP + 0.06
    b.span((-w / 2, y0, -d / 2), (w / 2, y0 + h, d / 2), "kibble")                                 # suitcase
    for x in (-0.65, 0.65):                                                                         # straps
        b.span((x - 0.1, y0 + 0.01, -d / 2 - 0.03), (x + 0.1, y0 + h + 0.03, d / 2 + 0.03), "choco")
    for sx in (-1, 1):                                                                              # corners
        for sz in (-1, 1):
            b.span((sx * (w / 2 + 0.02) - 0.13, y0 + h - 0.14, sz * (d / 2 + 0.02) - 0.13),
                   (sx * (w / 2 + 0.02) + 0.13, y0 + h + 0.02, sz * (d / 2 + 0.02) + 0.13), GOLD)
    f = -d / 2                                                                                      # the front face
    b.span((-0.35, y0 + h * 0.62, f - 0.1), (0.35, y0 + h * 0.62 + 0.1, f - 0.06), "choco")        # handle
    for x in (-0.3, 0.3):
        b.span((x - 0.06, y0 + h * 0.52, f - 0.09), (x + 0.06, y0 + h * 0.72, f + 0.01), GOLD)
    b.cyl((-0.98, y0 + 0.42, f - 0.02), 0.2, 0.04, "sign_teal", axis="Z", segments=12)            # stickers
    for (dx, dy, r) in ((0, -0.04, 0.07), (-0.08, 0.08, 0.035), (0.0, 0.11, 0.035), (0.08, 0.08, 0.035)):
        b.cyl((-0.98 + dx, y0 + 0.42 + dy, f - 0.045), r, 0.02, "offwhite", axis="Z", segments=8)
    b.span((0.82, y0 + 0.25, f - 0.035), (1.12, y0 + 0.62, f + 0.01), "pastel_butter")
    b.span((0.81, y0 + 0.4, f - 0.045), (1.13, y0 + 0.47, f - 0.02), RED)
    b.span((-0.18, y0 + 0.2, f - 0.035), (0.18, y0 + 0.34, f + 0.01), "offwhite")                   # name tag
    # a striped hatbox at one end, a teal travel case standing at the other
    hx, hz = 1.84, -0.3
    b.cyl((hx, y0 + 0.36, hz), 0.52, 0.72, "pastel_butter", segments=14)
    for y in (y0 + 0.2, y0 + 0.44):
        b.b.ring(RB.p(hx, y, hz), 0.535, 0.04, 0.08, RED, segments=14, bevel=False)
    b.cyl((hx, y0 + 0.78, hz), 0.56, 0.14, RED, segments=14)
    b.span((hx - 0.05, y0 + 0.85, hz - 0.3), (hx + 0.05, y0 + 0.95, hz + 0.3), GOLD)               # its cord
    tx, tz = -1.84, 0.15
    b.span((tx - 0.24, y0, tz - 0.62), (tx + 0.24, y0 + 1.3, tz + 0.62), "sign_teal")
    b.span((tx - 0.26, y0 + 0.55, tz - 0.64), (tx + 0.26, y0 + 0.7, tz + 0.64), "offwhite")
    b.span((tx - 0.08, y0 + 1.3, tz - 0.25), (tx + 0.08, y0 + 1.42, tz + 0.25), "choco")            # handle
    b.span((tx - 0.27, y0 + 0.9, tz - 0.08), (tx - 0.25, y0 + 1.02, tz + 0.08), GOLD)              # clasp


def _sign(b, bulbs):
    y0, y1, hw = SIGN_Y0, SIGN_Y1, SIGN_W / 2
    b.span((-hw, y0, -0.08), (hw, y1, 0.08), RED)
    for y in (y0, y1):                                                                              # gold frame
        b.span((-hw - 0.12, y - 0.06, -0.11), (hw + 0.12, y + 0.06, 0.11), GOLD)
    for sx in (-1, 1):
        b.span((sx * hw - 0.06, y0 + 0.06, -0.11), (sx * hw + 0.06, y1 - 0.06, 0.11), GOLD)
    label(b, "FREE CAT!", 0, 6.99, -0.08, 0.115, 0.04, GOLD, -1)
    label(b, "TAKE ME HOME", 0, 6.48, -0.08, 0.075, 0.04, "offwhite", -1)
    label(b, "FREE CAT!", 0, 6.71, 0.08, 0.115, 0.04, GOLD, 1)
    for k in range(9):                                                                              # marquee
        x = -hw + 0.3 + (SIGN_W - 0.6) * k / 8
        for y in (y0, y1):
            bulbs.b.sphere(RB.p(x, y, -0.15), 0.07, "lamp_warm", segments=6, rings=4)
    for sx in (-1, 1):
        for y in (y0 + 0.43, y1 - 0.43):
            bulbs.b.sphere(RB.p(sx * hw, y, -0.15), 0.07, "lamp_warm", segments=6, rings=4)


def build_bellhop_stand(mat):
    b, bulbs = RB(), RB()
    _dais(b)
    _cart(b)
    _luggage(b)
    _sign(b, bulbs)
    out = [b.finalize(NAME, mat), bulbs.finalize(NAME + "_Bulbs", mat)]
    cat = cats.build_cat("BellhopCat", mat, spec=CAT, base=NAME + "_Cat", body="sit")
    for ob in cat:
        ob.location = ob.location + Vector(RB.p(0, SEAT_Y, 0))
    return out + cat


def attachments():
    """(object suffix, Attachment name, Blender 4x4) for rbx_export: PromptAnchor and CatSeat on the stand."""
    return [(NAME, "PromptAnchor", Matrix.Translation(Vector(RB.p(*PROMPT_ROBLOX)))),
            (NAME, "CatSeat", Matrix.Translation(Vector(RB.p(0, SEAT_Y, 0))))]


# the cat's props ride inside its Head Model and its bell inside the collar's (as on the roster cat)
NEST = {"_Prop": "_Head", "_Prop2": "_Head", "_Bell": "_Prop2"}
FOLLOWS = {"_Prop": {"Follows": "Head"}, "_Prop2": {"Follows": "Head"}, "_Bell": {"Follows": "Head"}}

assert text_width("TAKE ME HOME", 0.075) < SIGN_W - 0.5 and text_width("FREE CAT!", 0.115) < SIGN_W - 0.5

ASSETS = {
    NAME: (build_bellhop_stand, 9000),
}
