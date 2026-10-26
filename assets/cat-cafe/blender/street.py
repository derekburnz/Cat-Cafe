"""Street props. The night food dealer's cart: mysterious but friendly, deep blue with gold stars,
a moon sign and a lantern. Pivot base center, front -Y (the side the player shops from).
Cart + Bulb objects: the lantern's Bulb goes Neon at night (style guide section 9)."""

import math

from mathutils import Matrix

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
        b.ring((x, y, 2.69), 0.52, 0.06, 0.06, "rarity_legend", segments=12, bevel=False)
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
        b.star((x, y, 5.72 + 0.2 * y), 0.2, 0.09, 0.04, "rarity_legend", rot=tilt)
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
    return [b.finalize("CatCafe_Street_DealerCart_Cart", mat), bulb.finalize("CatCafe_Street_DealerCart_Bulb", mat)]


ASSETS = {
    "CatCafe_Street_DealerCart": (build_dealer_cart, 2000),
}
