"""Street props. The night food dealer's cart: mysterious but friendly, deep blue with gold stars,
a moon sign and a lantern. Pivot base center, front -Y (the side the player shops from).
Cart + Bulb + Bulbs objects: the lantern's Bulb and the little lights under the canopy go Neon at night (style
guide section 9). The dealer's own cat (Derek 2026-10-28) sits on a violet cushion at the back of the counter: a
big old blue-black cat with star specks, a silver muzzle and gold eyes in a little violet hood like the dealer's,
the same hinged pieces as every sitting cat (`_Cat_Body`, `_Cat_Head` and the rest), its hood `_Cat_Prop` inside
the Head."""

import math

from mathutils import Matrix, Vector

import cats
import props
from common import Builder, scale_mesh

# The dealer's cat: not a catchable cat, so no roster entry (its coat is its own, like the Collector's).
SHOP_CAT = dict(rarity="Common", fur="fur_ink", second="fur_ink", eyes="eye_amber", pattern="solid",
                muzzle="fur_silver", nose="nose_dark", sparkle=True, tail_thick=0.28)
CUSHION_C, CUSHION_S = (0.0, 0.45, 2.66), (1.3, 1.16, 0.2)      # base centre on the counter top, size
HOOD, TRIM = "aurora_violet", "rarity_legend"                    # the dealer's violet trim and gold edge

# Where the three stock items stand on the counter (dealer slots 1 to 3), Blender axes.
DISPLAY_SLOTS = ((-1.6, -0.75, 2.72), (0.0, -0.75, 2.72), (1.6, -0.75, 2.72))


def build_dealer_cart(mat):
    b = Builder()
    for x in (-1.7, 1.7):                                                                      # wheels, axle along Y
        for y in (-1.3, 1.3):
            b.cyl((x, y, 0.75), 0.75, 0.16, "dark_wood", segments=12, rot=(math.radians(90), "X"))
            b.cyl((x, y * 1.06, 0.75), 0.2, 0.12, "rarity_legend", segments=8, rot=(math.radians(90), "X"))
    b.box_base((0, 0, 0.9), (5.0, 2.4, 1.6), "galaxy_blue")                                    # body
    b.box_base((0, 0, 0.8), (5.2, 2.6, 0.12), "dark_wood")
    b.box((0, -1.21, 1.7), (4.7, 0.04, 1.3), "night_sky", bevel=False)                         # front panel
    for (x, z, r) in ((-1.8, 2.05, 0.2), (-0.9, 1.4, 0.14), (1.0, 2.1, 0.16), (1.9, 1.35, 0.22), (-2.1, 1.2, 0.1),
                      (0.3, 1.15, 0.1)):
        b.star((x, -1.25, z), r, r * 0.45, 0.05, "rarity_legend", rot=(math.radians(90), "X"))
    b.crescent((0.0, -1.26, 1.75), 0.32, 0.2, 0.05, "sparkle")
    b.box_base((0, -0.1, 2.5), (5.4, 2.9, 0.16), "caramel_wood")                               # counter
    b.box((0, -1.55, 2.58), (5.4, 0.08, 0.2), "rarity_legend", bevel=False)                    # gold edge
    for (x, y, z) in DISPLAY_SLOTS:                                                            # three stock pads
        b.cyl_base((x, y, 2.66), 0.5, 0.06, "cream", segments=12, bevel=False)
        b.ring((x, y, 2.7), 0.52, 0.06, 0.06, "rarity_legend", segments=12, bevel=False)    # 0.01 above the pad
    for x in (-2.55, 2.55):                                                                    # canopy posts
        for y in (-1.4, 1.2):
            b.cyl_base((x, y, 2.66), 0.08, 2.7, "dark_wood", segments=6, bevel=False)
    b.box((0, 1.22, 3.9), (5.2, 0.1, 2.4), "night_sky", bevel=False)                           # back curtain
    for (x, z) in ((-1.5, 4.4), (0.8, 3.7), (2.0, 4.6), (-0.4, 4.9)):
        b.star((x, 1.15, z), 0.18, 0.08, 0.04, "sparkle", rot=(math.radians(90), "X"))
    tilt = Matrix.Rotation(math.radians(-12), 4, "X")                                          # canopy slopes to the front
    stripes = 9
    for i in range(stripes):
        x = -2.8 + 5.6 * (i + 0.5) / stripes
        b.box((x, -0.15, 5.55), (5.6 / stripes, 3.5, 0.14), ("galaxy_blue", "aurora_violet")[i % 2], rot=tilt)
        b.cyl((x, -1.88, 5.13), 5.6 / stripes / 2, 0.08, ("galaxy_blue", "aurora_violet")[i % 2], segments=8,
              bevel=False, rot=(math.radians(90), "X"))                                         # scallops
    for (x, y) in ((-1.9, -0.6), (0.4, 0.3), (1.8, -0.9), (-0.6, -1.2)):
        p = Vector((x, -0.15, 5.55)) + tilt.to_3x3() @ Vector((0, (y + 0.15) / math.cos(math.radians(12)), 0.09))
        b.star(tuple(p), 0.2, 0.09, 0.04, "rarity_legend", rot=tilt)                          # lying on the canopy
    b.box((0, -1.92, 5.95), (1.6, 0.1, 0.8), "night_sky")                                      # moon sign
    b.crescent((-0.35, -1.98, 5.95), 0.26, 0.16, 0.05, "sparkle")
    b.star((0.35, -1.98, 5.95), 0.22, 0.1, 0.05, "rarity_legend", rot=(math.radians(90), "X"))
    b.cyl((3.2, 0, 1.9), 0.07, 2.2, "dark_wood", segments=6, rot=(math.radians(90), "X"))     # push handle
    for y in (-1.0, 1.0):
        b.box((2.9, y, 1.9), (0.6, 0.08, 0.08), "dark_wood", bevel=False)
    lx, ly, lz = 2.55, -1.75, 4.6                                                              # lantern at the front corner
    b.box((lx, (ly - 1.4) / 2, 5.25), (0.06, abs(ly + 1.4) + 0.06, 0.06), "fur_black", bevel=False)  # arm
    b.cyl((lx, ly, 5.0), 0.03, 0.4, "fur_black", segments=4, bevel=False)
    b.pyramid((lx, ly, 4.82), 0.5, 0.2, "rarity_legend")                                       # cap
    b.box((lx, ly, 4.1), (0.5, 0.5, 0.08), "fur_black", bevel=False)                            # base
    for dx in (-0.22, 0.22):
        for dy in (-0.22, 0.22):
            b.box((lx + dx, ly + dy, 4.46), (0.05, 0.05, 0.66), "fur_black", bevel=False)
    bulb = Builder()
    bulb.box((lx, ly, 4.46), (0.36, 0.36, 0.6), "lamp_warm", bevel=False)
    bulbs = Builder()
    _dressing(b, bulbs)
    _cushion(b)
    return [b.finalize("CatCafe_Street_DealerCart_Cart", mat), bulb.finalize("CatCafe_Street_DealerCart_Bulb", mat),
            bulbs.finalize("CatCafe_Street_DealerCart_Bulbs", mat)] + _shop_cat(mat)


def _cushion(b):
    """The cat's violet cushion at the back of the counter, between the jars and behind the middle stock pad, with
    gold piping round its middle and a gold tassel at each corner."""
    (cx, cy, cz), (sx, sy, sz) = CUSHION_C, CUSHION_S
    b.box_base((cx, cy, cz), (sx, sy, sz), "aurora_violet")
    b.box((cx, cy, cz + sz / 2), (sx + 0.02, sy + 0.02, 0.04), "rarity_legend", bevel=False)     # piping
    for kx in (1, -1):
        for ky in (1, -1):
            b.box((cx + kx * (sx / 2 + 0.01), cy + ky * (sy / 2 + 0.01), cz + sz / 2 - 0.06), (0.08, 0.08, 0.14),
                  "rarity_legend", bevel=False, rot=_rz(45))


def _hood(ctx):
    """A little hood like the dealer's, on the head frame (origin on the head's top, y to the back; the head is 0.92
    wide, 0.74 deep and 0.76 tall, the ears stand at x 0.1 to 0.4 and come up through the top; the sides stop above the
    cheeks at the front and at the neck behind): a boxy violet shell over the top, sides and back, a gold edge round
    the face, the tip folded back with a gold tassel, and gold stars on the sides and the back."""
    P = ctx.pen("head")
    W, Y0, Y1 = 0.54, -0.38, 0.48                                   # outer half width, front, back
    yc, dep = (Y0 + Y1) / 2, Y1 - Y0
    P.box((0, yc, 0.05), (2 * W, dep, 0.08), HOOD)                                             # top, a hair up
    P.box((0, Y1 - 0.04, -0.36), (2 * W, 0.08, 0.72), HOOD)                                    # back, to the neck
    for sx in (1, -1):
        P.box((sx * (W - 0.035), yc, -0.22), (0.07, dep, 0.44), HOOD)                          # sides, above the cheeks
        P.box((sx * (W - 0.035), (Y1 - 0.06) / 2, -0.58), (0.07, Y1 + 0.06, 0.28), HOOD)       # and behind them
        P.box((sx * (W - 0.035), Y0 - 0.015, -0.17), (0.09, 0.03, 0.54), TRIM)                 # gold edge by the face
        P.star((sx * (W + 0.005), 0.12, -0.22), 0.09, 0.04, 0.02, TRIM, rot=_rz(90 * sx) @ _rx(90))
    P.box((0, Y0 - 0.015, 0.05), (2 * W + 0.02, 0.03, 0.1), TRIM)                              # and over the brow
    P.star((0, Y1 + 0.005, -0.36), 0.12, 0.055, 0.02, TRIM, rot=_rx(90))                       # a star on the back
    P.b.wedge(P.p((0, 0.33, 0.21)), tuple(v * P.s for v in (0.36, 0.36, 0.26)), HOOD, bevel=False,
              rot=P._r(_rz(180)))                                                              # the tip, folded back
    P.sphere((0, Y1 + 0.05, 0.11), 0.07, TRIM, segments=8, rings=5)                           # its tassel


def _shop_cat(mat):
    """The dealer's cat on its cushion, facing the shoppers (-Y)."""
    base = "CatCafe_Street_DealerCart_Cat"
    cat = cats.build_cat("DealerCat", mat, spec=SHOP_CAT, base=base, body="sit")
    d = cats.dims(SHOP_CAT, "sit")
    k = cats.scale_of(SHOP_CAT, "sit")
    ctx = props.Ctx(SHOP_CAT, "sit", d)
    _hood(ctx)
    hood = ctx.main.finalize(base + "_Prop", mat, location=tuple(v * k for v in d["pivots"]["Head"]))
    scale_mesh(hood, k)
    hood["rides"] = "Head"
    seat = Vector((CUSHION_C[0], CUSHION_C[1], CUSHION_C[2] + CUSHION_S[2] - 0.01))           # sunk 0.01 in
    for ob in cat + [hood]:
        ob.location = ob.location + seat
    return cat + [hood]


def _fish(b, x, y, z):
    """A small dried fish hanging by its tail on a string: body, tail fan above, an eye."""
    b.box((x, y, z), (0.12, 0.3, 0.46), "metal", bevel=False)
    b.wedge((x, y, z + 0.33), (0.1, 0.26, 0.2), "fur_silver", bevel=False, rot=_rx(180))
    b.box((x, y - 0.155, z - 0.13), (0.06, 0.01, 0.06), "fur_black", bevel=False)


def _dressing(b, bulbs):
    """Cart dressing: jars of treats along the back of the counter, a string of dried fish down the front left post,
    a string of little warm lights under the canopy's front edge (`bulbs`, glowing at night) and a fish sack by the
    handle."""
    for x, fill in ((-2.05, "fur_strawberry"), (-1.35, "pastel_butter"), (1.35, "mint"), (2.05, "pastel_lilac")):
        b.cyl_base((x, 0.55, 2.66), 0.26, 0.5, fill, segments=10, bevel=False)              # jar of treats
        b.cyl_base((x, 0.55, 3.16), 0.28, 0.1, "dark_wood", segments=10, bevel=False)       # lid
        b.cyl_base((x, 0.55, 3.26), 0.06, 0.06, "rarity_legend", segments=6, bevel=False)   # knob
        b.box((x, 0.28, 2.95), (0.24, 0.02, 0.18), "offwhite", bevel=False)                 # label
        b.star((x, 0.265, 2.95), 0.06, 0.027, 0.01, "rarity_legend", rot=_rx(90))
    fx, fy = -2.34, -1.45                                                                    # beside the front post
    b.cyl((fx, fy, 4.35), 0.015, 1.3, "fur_black", segments=4, bevel=False)                 # string
    b.box((fx - 0.06, fy, 5.0), (0.16, 0.04, 0.04), "fur_black", bevel=False)                # tied to the post
    for z in (4.5, 3.95):
        _fish(b, fx, fy, z)
    for i in (0, 1, 3, 5, 7, 8):                                                             # lights on the edge
        x = -2.8 + 5.6 * (i + 0.5) / 9                                                       # under a scallop
        b.cyl((x, -1.88, 4.785), 0.015, 0.11, "fur_black", segments=4, bevel=False)
        bulbs.box((x, -1.88, 4.66), (0.16, 0.16, 0.16), "lamp_warm", bevel=False)
    sx, sy = 3.45, -1.25                                                                      # the fish sack
    b.box_base((sx, sy, 0), (0.75, 0.65, 0.8), "treat_tan")
    b.box_base((sx, sy, 0.8), (0.5, 0.45, 0.14), "treat_tan")
    b.box_base((sx, sy, 0.94), (0.24, 0.24, 0.18), "treat_tan")                            # the gathered top
    b.box((sx, sy, 0.86), (0.54, 0.49, 0.05), "dark_wood", bevel=False)                     # its tie
    b.box((sx, sy - 0.335, 0.42), (0.36, 0.02, 0.16), "puddle", bevel=False)                # a fish on it
    b.wedge((sx + 0.22, sy - 0.335, 0.42), (0.02, 0.16, 0.16), "puddle", bevel=False, rot=_rz(90))


def _rx(deg):
    return Matrix.Rotation(math.radians(deg), 3, "X")


def _rz(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Z")


ASSETS = {
    "CatCafe_Street_DealerCart": (build_dealer_cart, 6000),        # 4,500 for the cart, 1,500 for its cat
}
