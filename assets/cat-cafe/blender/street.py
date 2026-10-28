"""Street props. The night food dealer's cart: mysterious but friendly, deep blue with gold stars,
a moon sign and a lantern. Pivot base center, front -Y (the side the player shops from).
Cart + Bulb + Bulbs objects: the lantern's Bulb and the little lights under the canopy go Neon at night (style
guide section 9)."""

import math

from mathutils import Matrix, Vector

from common import Builder

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
    return [b.finalize("CatCafe_Street_DealerCart_Cart", mat), bulb.finalize("CatCafe_Street_DealerCart_Bulb", mat),
            bulbs.finalize("CatCafe_Street_DealerCart_Bulbs", mat)]


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
    "CatCafe_Street_DealerCart": (build_dealer_cart, 4500),
}
