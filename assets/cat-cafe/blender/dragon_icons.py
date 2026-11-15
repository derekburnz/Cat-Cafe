"""The Dragon Keep's six card families as pictures (#4062, ticket-booth-and-dragon-keep.md 2.6), for the card
corners and the set bonus chips in place of emoji, which draw differently on every device. Each is a chunky shape
seen from the front (-Y), in the family's colour from DragonKeepLogic.FAMILY_COLOURS' mood: Flame orange, Claw
cream on red, Wing red and apricot, Hoard gold, Heart pink, Crown gold with gems. icons.py renders them as
CatCafe_Icon_DragonFamily_<Name>.
"""
import math

from common import Builder

N = "CatCafe_IconArt_DragonFamily_"
R = math.radians


def flame(mat):
    """One tall teardrop flame: a red outer layer, an orange middle and a pale gold heart, each a round bulb under
    a long cone, stacked toward the camera. One shape, so it still reads as a flame at 28 px."""
    b = Builder()
    for (z, r, tip, sw, y) in ((0.62, 0.62, 1.3, "shirt_red", 0.0), (0.52, 0.44, 0.9, "fur_orange", -0.26),
                               (0.42, 0.26, 0.58, "rarity_legend", -0.44)):
        b.ico((0.0, y, z), r, sw, scale=(1.15, 0.5, 1.0), subdivisions=3)
        b.cyl_base((0.0, y, z + r * 0.5), r * 0.84, tip, sw, segments=20, bevel=False, radius2=0.02,
                   scale=(1.15, 0.5, 1.0))
    return [b.finalize(N + "Flame", mat)]


def claw(mat):
    """Three curved cream claws on a red dragon toe pad."""
    b = Builder()
    b.box((0.0, 0.0, 0.28), (1.5, 0.5, 0.56), "shirt_red")
    for k, x in enumerate((-0.5, 0.0, 0.5)):
        b.box((x, 0.0, 0.7), (0.34, 0.4, 0.4), "nose_brick")                               # the knuckle
        b.box((x, -0.02, 1.0), (0.26, 0.3, 0.5), "fur_cream", rot=(R(-12), "Y"))
        b.pyramid((x + 0.1, -0.02, 1.2), 0.27, 0.6, "fur_cream", rot=(R(-30), "Y"))        # the hooked tip
    return [b.finalize(N + "Claw", mat)]


def wing(mat):
    """One spread dragon wing: three red fingers from the shoulder, apricot membrane between them."""
    b = Builder()
    L = 1.5
    angs = (12, 44, 76)
    for a0, a1 in zip(angs, angs[1:]):                                                     # the membrane panels
        for t in (0.35, 0.62, 0.86):
            am = R((a0 + a1) / 2)
            w = 2 * L * t * math.sin(R(a1 - a0) / 2) * 1.05
            b.box((L * t * math.cos(am), 0.05, L * t * math.sin(am)), (0.42, 0.08, w), "fur_apricot",
                  rot=(-am, "Y"))
    for a in angs:                                                                         # the fingers
        ar = R(a)
        b.box((L / 2 * math.cos(ar), 0.0, L / 2 * math.sin(ar)), (L, 0.2, 0.16), "shirt_red", rot=(-ar, "Y"))
        b.pyramid((L * math.cos(ar), 0.0, L * math.sin(ar)), 0.16, 0.22, "fur_cream", rot=(R(90) - ar, "Y"))
    b.ico((0.0, 0.0, 0.0), 0.2, "shirt_red")                                               # the shoulder
    return [b.finalize(N + "Wing", mat)]


def hoard(mat):
    """A little heap of gold coins with a blue gem and a pink gem on top."""
    b = Builder()
    for (x, z, n) in ((-0.55, 0.0, 2), (0.0, 0.0, 4), (0.55, 0.0, 3)):
        for i in range(n):
            b.cyl((x + 0.04 * (i % 2), 0.0, z + 0.09 + 0.18 * i), 0.36, 0.16, "gold_mid", segments=12)
            b.cyl((x + 0.04 * (i % 2), 0.0, z + 0.09 + 0.18 * i), 0.3, 0.18, "gold_light", segments=12)
    b.ico((0.5, -0.05, 0.75), 0.2, "shirt_blue", scale=(1, 1, 1.25))
    b.ico((-0.52, -0.05, 0.55), 0.17, "rarity_mythic", scale=(1, 1, 1.2))
    b.box((0.0, -0.37, 0.45), (0.1, 0.03, 0.34), "gold_dark", bevel=False)                 # a mark on the front coin stack
    return [b.finalize(N + "Hoard", mat)]


def heart(mat):
    """A plump pink heart with a pale shine: two round lobes over a point."""
    b = Builder()
    for sx in (-1, 1):
        b.ico((sx * 0.38, 0.0, 1.0), 0.48, "rarity_mythic", scale=(1.0, 0.7, 1.0), subdivisions=2)
    b.pyramid((0.0, 0.0, 0.02), 1.3, 0.98, "rarity_mythic", rot=(R(180), "Y"))            # the point, hanging down
    b.box((-0.48, -0.36, 1.14), (0.2, 0.05, 0.12), "milk", bevel=False, rot=(R(35), "Y"))  # the shine
    return [b.finalize(N + "Heart", mat)]


def crown(mat):
    """A gold crown: a band, five points with pearls and three gems on the band."""
    b = Builder()
    b.cyl((0.0, 0.0, 0.25), 0.8, 0.5, "gold_mid", segments=14)
    b.cyl((0.0, 0.0, 0.08), 0.84, 0.16, "gold_light", segments=14)
    for k in range(7):
        a = R(-90 + 360 * k / 7)
        x, y = 0.7 * math.cos(a), 0.7 * math.sin(a)
        b.pyramid((x, y, 0.45), 0.42, 0.62, "gold_mid")
        b.ico((x, y, 1.1), 0.1, "milk")
    for k, sw in enumerate(("rarity_mythic", "shirt_blue", "leaf_green")):
        a = R(-90 + (k - 1) * 40)
        b.ico((0.82 * math.cos(a), 0.82 * math.sin(a), 0.3), 0.13, sw, scale=(1, 1, 1.2))
    return [b.finalize(N + "Crown", mat)]


BUILDERS = {"Flame": flame, "Claw": claw, "Wing": wing, "Hoard": hoard, "Heart": heart, "Crown": crown}
VIEWS = {"Flame": (0.0, 4.0), "Claw": (-8.0, 6.0), "Wing": (0.0, 2.0), "Hoard": (-6.0, 14.0), "Heart": (0.0, 2.0),
         "Crown": (-8.0, 18.0)}
