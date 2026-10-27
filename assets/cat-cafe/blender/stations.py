"""Walk-up stations in the street plaza (areas-and-stations B2). The Codes Cat (F65, data-model 11d; Derek
2026-10-27 19:33): a little red post office kiosk with a "CODES" sign, and behind its desk a flame point cat in a
red postman's cap, sitting on a stool so its head and chest show over the counter. In front of the desk a flat
glowing circle lies on the street, and walking into it opens the code box (design v0.10, Derek 20:10).

  CatCafe_Street_CodesCat            desk, stool, pigeonholes, awning and sign (collides); tag CodesCat; an
                                     Attachment PromptAnchor at the middle of the desk front, 3 studs up
  CatCafe_Street_CodesCat_Cat_<Piece>  the cat, the same hinged pieces as every sitting cat (Head with its eyes and
                                     ears, Tail, LegF1, LegF2), so the effects code can blink it and flick its ears
  CatCafe_Street_CodesCat_Cat_Prop   the cap, inside the Head Model
  CatCafe_Street_CodesCat_Bulb       the lamp over the sign, lit at night
  CatCafe_Street_CodesCat_CodesCircle  the walk-in circle: one flat Neon disc, 8 studs across and 0.6 see-through,
                                     exported as the part CodesCircle; CanCollide off
  CatCafe_Street_CodesCat_Glow       the circle's rim and the ticket in its middle, Neon day and night

Pivot at the base centre, the desk front (-Z) toward the players. Footprint about 6 x 3.5 studs for the kiosk, and
the circle reaches 10 studs out in front of it.
"""

import math

from mathutils import Matrix, Vector

import cats
import props
from alleyway import label
from common import RB, scale_mesh, text_width
from plot import rot_x

DESK_W, DESK_H, DESK_FRONT, DESK_BACK = 4.8, 2.6, -1.2, 0.0
SEAT_Y, CAT_Z, CAT_SCALE = 1.9, 0.9, 1.5         # the stool top, the cat's pivot (Roblox z) and its size
WALL_Z = 1.75                                      # the pigeonhole wall's front face
PROMPT_ROBLOX = (0.0, 3.0, DESK_FRONT - 0.2)       # PromptAnchor, Roblox studs from the pivot
CIRCLE_R = 4.0                                     # the walk-in circle's radius (CodesCircle is 8 across)
CIRCLE_Z = DESK_FRONT - 0.8 - CIRCLE_R             # its centre, its edge 0.8 studs in front of the desk

# A flame point (white with ginger points): not a collectable coat, so nobody takes it for a cat to catch.
CAT = dict(rarity="Common", fur="offwhite", second="fur_ginger", eyes="eye_blue", pattern="points", muzzle=None,
           scale=CAT_SCALE)


def postman_cap(ctx):
    """A red postman's cap with a navy band, a black peak and a gold envelope badge."""
    P = ctx.pen("head")
    P.cyl((0, 0, 0.07), 0.31, 0.16, "shirt_red", segments=12)
    P.cyl((0, 0.02, 0.175), 0.35, 0.06, "shirt_red", segments=14)
    P.cyl((0, 0, 0.02), 0.315, 0.05, "pants_navy", segments=12)
    P.box((0, -0.36, 0.02), (0.44, 0.2, 0.035), "fur_black", rot=props._rx(14))
    P.box((0, -0.312, 0.105), (0.16, 0.03, 0.11), "rarity_legend")
    P.box((0, -0.33, 0.12), (0.12, 0.012, 0.05), "shirt_red", rot=props._ry(45))


def _desk(b):
    hw = DESK_W / 2
    b.span((-hw, 0, DESK_FRONT), (hw, DESK_H, DESK_BACK), "shirt_red")
    b.span((-hw - 0.05, 0, DESK_FRONT - 0.05), (hw + 0.05, 0.35, DESK_BACK + 0.05), "offwhite")             # kick
    b.span((-hw - 0.2, DESK_H - 0.01, DESK_FRONT - 0.2), (hw + 0.2, DESK_H + 0.25, DESK_BACK + 0.1),
           "caramel_wood")                                                                                # top
    b.span((-hw - 0.22, DESK_H - 0.06, DESK_FRONT - 0.22), (hw + 0.22, DESK_H + 0.04, DESK_FRONT - 0.16),
           "rarity_legend")                                                                               # gold edge
    # the front: an envelope with its flap folded down and a gold paw seal
    z = DESK_FRONT
    b.span((-1.1, 0.75, z - 0.06), (1.1, 2.15, z + 0.01), "offwhite")
    for sx in (-1, 1):
        b.box((sx * 0.55, 1.83, z - 0.08), (1.3, 0.1, 0.05), "pants_navy", rot=Matrix.Rotation(math.radians(sx * 31), 3, "Z"))
    b.cyl((0, 1.5, z - 0.1), 0.22, 0.07, "rarity_legend", axis="Z", segments=10)
    for (dx, dy, r) in ((0, -0.04, 0.08), (-0.1, 0.09, 0.035), (0, 0.12, 0.035), (0.1, 0.09, 0.035)):
        b.cyl((dx, 1.5 + dy, z - 0.14), r, 0.03, "shirt_red", axis="Z", segments=8)
    for sx in (-1, 1):                                                                                    # side panels
        b.span((sx * hw - 0.06, 0.35, z + 0.2), (sx * hw + 0.06, DESK_H - 0.2, DESK_BACK - 0.2), "offwhite")
    # on the counter: a bell, a stack of letters and a rubber stamp
    top = DESK_H + 0.24
    b.cyl((1.55, top + 0.04, -0.6), 0.32, 0.08, "dark_wood", segments=10)
    b.ball((1.55, top + 0.12, -0.6), 0.25, "rarity_legend", scale=(1.0, 0.8, 1.0))
    b.cyl((1.55, top + 0.38, -0.6), 0.05, 0.12, "rarity_legend", segments=6)
    for i, sw in enumerate(("offwhite", "pastel_butter", "blush", "mint")):
        b.box((-1.5 + 0.03 * (i % 2), top + 0.06 + 0.08 * i, -0.6), (0.9, 0.08, 0.6), sw, rot=_ry(6 * (i - 1.5)))
    b.span((0.6, top - 0.01, -0.95), (0.9, top + 0.12, -0.65), "fur_black")
    b.cyl((0.75, top + 0.32, -0.8), 0.07, 0.42, "dark_wood", segments=6)
    b.ball((0.75, top + 0.55, -0.8), 0.12, "dark_wood")


def _ry(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Y")


def _back(b, bulb):
    """Stool, pigeonhole wall, awning, sign and lamp."""
    b.span((-0.75, 0, CAT_Z - 0.75), (0.75, SEAT_Y, CAT_Z + 0.75), "dark_wood")                         # stool
    b.span((-0.85, SEAT_Y - 0.01, CAT_Z - 0.8), (0.85, SEAT_Y + 0.12, CAT_Z + 0.8), "blush")             # cushion
    hw, top = 2.7, 6.0
    b.span((-hw, 0, WALL_Z), (hw, top, WALL_Z + 0.3), "cream")
    b.span((-hw - 0.15, top, WALL_Z - 0.15), (hw + 0.15, top + 0.25, WALL_Z + 0.45), "caramel_wood")
    letters = ("offwhite", "pastel_butter", "blush", "mint", "pastel_lilac", "offwhite", "pastel_sky", "blush")
    k = 0
    for sx in (-1, 1):                                                                                   # pigeonholes
        for col in range(2):
            x0 = sx * (1.25 + col * 0.72)
            for row in range(4):
                y0 = 2.9 + row * 0.72
                lo, hi = sorted((x0, x0 + sx * 0.66))
                b.span((lo, y0, WALL_Z - 0.5), (hi, y0 + 0.06, WALL_Z + 0.01), "caramel_wood")           # shelf
                if (row + col) % 2 == 0:
                    b.span((lo + 0.1, y0 + 0.06, WALL_Z - 0.4), (hi - 0.1, y0 + 0.4, WALL_Z - 0.3), letters[k % len(letters)])
                    k += 1
            for x in (x0, x0 + sx * 0.66):
                b.span((x - 0.03, 2.9, WALL_Z - 0.5), (x + 0.03, 5.68, WALL_Z + 0.01), "caramel_wood")    # dividers
    zb = WALL_Z + 0.3                                                                                    # the back
    b.span((-hw + 0.01, 0, zb - 0.01), (hw - 0.01, 0.6, zb + 0.06), "shirt_red")              # inside the wall's ends
    b.span((-1.2, 2.2, zb - 0.01), (1.2, 3.8, zb + 0.06), "offwhite")
    for sx in (-1, 1):
        b.box((sx * 0.6, 3.48, zb + 0.08), (1.4, 0.1, 0.05), "pants_navy", rot=Matrix.Rotation(math.radians(sx * 31), 3, "Z"))
    b.cyl((0, 3.15, zb + 0.1), 0.22, 0.07, "rarity_legend", axis="Z", segments=10)
    # a striped awning from the top of the wall out over the desk
    n, depth, drop = 8, WALL_Z + 0.2 - (DESK_FRONT - 0.1), 0.6
    tilt = math.atan2(drop, depth)
    for i in range(n):
        x = -hw - 0.2 + (2 * hw + 0.4) * (i + 0.5) / n
        sw = ("shirt_red", "offwhite")[i % 2]
        b.box((x, top - 0.05 - drop / 2, (WALL_Z + 0.2 + DESK_FRONT - 0.1) / 2), ((2 * hw + 0.4) / n, 0.12, math.hypot(depth, drop)),
              sw, rot=rot_x(-math.degrees(tilt)))
        b.cyl((x, top - 0.05 - drop - 0.02, DESK_FRONT - 0.12), (2 * hw + 0.4) / n / 2, 0.1, sw, axis="Z", segments=8)
    # the CODES sign standing on the wall top, a ticket at each end, and a lamp
    text, px = "CODES", 0.22
    w = text_width(text, px) + 2.4
    y0, y1, zf = top + 0.25, top + 2.0, WALL_Z - 0.05
    b.span((-w / 2, y0 - 0.01, zf), (w / 2, y1, zf + 0.3), "offwhite")
    for (xa, xb, ya, yb) in ((-w / 2 - 0.15, w / 2 + 0.15, y0 - 0.01, y0 + 0.15), (-w / 2 - 0.15, w / 2 + 0.15, y1 - 0.15, y1 + 0.01),
                             (-w / 2 - 0.15, -w / 2 + 0.01, y0, y1), (w / 2 - 0.01, w / 2 + 0.15, y0, y1)):
        b.span((xa, ya, zf - 0.08), (xb, yb, zf + 0.34), "shirt_red")
    label(b, text, 0, (y0 + y1) / 2 - 2.5 * px, zf + 0.01, px, 0.07, "shirt_red", -1)
    label(b, text, 0, (y0 + y1) / 2 - 2.5 * px, zf + 0.29, px, 0.07, "shirt_red", 1)            # and from behind
    for sx in (-1, 1):                                                                                   # code tickets
        cx = sx * (w / 2 - 0.7)
        b.span((cx - 0.45, (y0 + y1) / 2 - 0.3, zf - 0.05), (cx + 0.45, (y0 + y1) / 2 + 0.3, zf + 0.01), "rarity_legend")
        for dy in (-0.12, 0.12):
            b.span((cx - 0.28, (y0 + y1) / 2 + dy - 0.03, zf - 0.08), (cx + 0.28, (y0 + y1) / 2 + dy + 0.03, zf - 0.04), "dark_wood")
    b.span((-0.05, y1, zf + 0.1), (0.05, y1 + 0.6, zf + 0.2), "fur_black")                              # lamp
    b.span((-0.05, y1 + 0.5, zf - 0.6), (0.05, y1 + 0.6, zf + 0.2), "fur_black")
    b.cyl((0, y1 + 0.35, zf - 0.6), 0.32, 0.18, "fur_black", r2=0.12)
    bulb.ball((0, y1 + 0.2, zf - 0.6), 0.16, "lamp_warm")


def _circle(pad, glow):
    """The walk-in circle: a flat disc on the street (the part CodesCircle), a glowing rim and a glowing code ticket
    in the middle, its stub torn off along a dashed line."""
    pad.cyl((0, 0.05, CIRCLE_Z), CIRCLE_R, 0.1, "pastel_butter", segments=24)
    glow.b.ring(RB.p(0, 0.07, CIRCLE_Z), CIRCLE_R + 0.05, 0.3, 0.14, "pastel_butter", segments=24, bevel=False)
    y0, y1 = 0.09, 0.15
    hw, hd, notch, end = 1.9, 1.1, 0.32, 0.45        # half width, half depth, the side notches, the end strips
    glow.span((-hw + end, y0, CIRCLE_Z - hd), (hw - end, y1, CIRCLE_Z + hd), "shirt_red")
    for sx in (-1, 1):
        xa, xb = sorted((sx * (hw - end), sx * hw))
        for sz in (-1, 1):
            za, zb = sorted((CIRCLE_Z + sz * notch, CIRCLE_Z + sz * hd))
            glow.span((xa, y0, za), (xb, y1, zb), "shirt_red")
    for dz in (-0.72, -0.24, 0.24, 0.72):                                                    # the tear line
        glow.span((0.74, y1 - 0.01, CIRCLE_Z + dz - 0.14), (0.88, y1 + 0.02, CIRCLE_Z + dz + 0.14), "offwhite")


def build_codes_cat(mat):
    name = "CatCafe_Street_CodesCat"
    b, bulb, pad, glow = RB(), RB(), RB(), RB()
    _desk(b)
    _back(b, bulb)
    _circle(pad, glow)
    out = [b.finalize(name, mat), bulb.finalize(name + "_Bulb", mat), pad.finalize(name + "_CodesCircle", mat),
           glow.finalize(name + "_Glow", mat)]
    # the cat on its stool: the sitting body, scaled, with the cap in the Head
    base = name + "_Cat"
    cat = cats.build_cat("CodesCat", mat, spec=CAT, base=base, body="sit")
    d = cats.dims(CAT, "sit")
    ctx = props.Ctx(CAT, "sit", d)
    postman_cap(ctx)
    k = cats.scale_of(CAT, "sit")
    cap = ctx.main.finalize(base + "_Prop", mat, location=tuple(v * k for v in d["pivots"]["Head"]))
    scale_mesh(cap, k)
    cap["rides"] = "Head"
    for ob in cat + [cap]:
        ob.location = ob.location + Vector(RB.p(0, SEAT_Y + 0.11, CAT_Z))
    return out + cat + [cap]


def prompt_attachment():
    """(object suffix, Attachment name, Blender 4x4) for rbx_export: PromptAnchor on the kiosk."""
    return ("CatCafe_Street_CodesCat", "PromptAnchor", Matrix.Translation(Vector(RB.p(*PROMPT_ROBLOX))))


ASSETS = {
    "CatCafe_Street_CodesCat": (build_codes_cat, 6000),
}
