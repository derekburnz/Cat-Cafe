"""Picture-only models for the F97 pictures (notes-10-28-to-10-30.md sections 3 and 4; Derek 2026-10-28: "timing
milestone pictures need to be more clear especially food pictures should be reworked" and "treats and perks should
be remade for pictures also and Golden fish / golden cat coins should be merged together as one currency and
picture"). Nothing here is placed in the game; icons.py renders each one to a PNG.

  golden_fish        the one Golden Fish picture: a plump shiny gold fish, a happy eye, a white glint
  kibble, tuna, sardines, salmon, caviar, moon_milk, star_treat   the seven foods, Kibble to Star Treat
  golden_espresso, big_bowl, extra_decor_spot                     the Golden Fish Market perks
  coins, spin_wheel  prize pictures: a stack of three gold coins, the Spin Wheel's own wheel

Built with RB in Roblox axes: x across (+x shows on the picture's left from the front), y up, the front toward -Z.
"""

import math

from mathutils import Matrix

import spinwheel
from common import GLYPHS, RB
from plot import rot_z

TWINKLE = "offwhite"


def rot_x(deg):
    return Matrix.Rotation(math.radians(deg), 3, "X")


def rot_y(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Y")


def _twinkle(b, x, y, z, s, sw=TWINKLE):
    """A four-pointed twinkle `s` across, facing the front."""
    pts = []
    for k in range(9):
        a = math.radians(90 + 45 * k)
        r = s / 2 if k % 2 == 0 else s * 0.12
        pts.append((x + r * math.cos(a), y + r * math.sin(a)))
    b.fan_z(z, (x, y), pts, 0.05, sw)


def _sb(b, c, r, sw, scale=(1, 1, 1), segments=24, rings=12):
    """A smooth ball (a UV sphere, finer than RB.ball's icosphere), scale in Roblox (x, y, z)."""
    b.b.sphere(RB.p(*c), r, sw, segments=segments, rings=rings, scale=(scale[0], scale[2], scale[1]))


def _crescent(b, x, y, z, R, W, depth, sw, horns=-1, n=12):
    """A smooth crescent moon facing the front, `R` across its outer edge, `W` thick at the middle, its horns
    toward horns * x (-1: the picture's right)."""
    mid = 0.0 if horns < 0 else math.pi                     # the thick middle, away from the horns
    a0, a1 = mid - math.radians(140), mid + math.radians(140)
    outer, inner = [], []
    for i in range(n + 1):
        t = i / n
        a = a0 + (a1 - a0) * t
        w = W * math.sin(math.pi * t) + 0.02
        ux, uy = math.cos(a), math.sin(a)
        outer.append((x + R * ux, y + R * uy))
        inner.append((x + (R - w) * ux, y + (R - w) * uy))
    for i in range(n):
        b.fan_z(z, outer[i], [inner[i], inner[i + 1], outer[i + 1]], depth, sw)


def _star_up(b, x, y, z, outer, inner, depth, sw, rot=None):
    """A five-pointed star standing up, facing the front, one point up."""
    r = Matrix.Rotation(math.radians(90), 3, "X")
    b.b.star(RB.p(x, y, z), outer, inner, depth, sw, rot=r if rot is None else rot @ r)


def _glyphs(b, s, origin, px, depth, sw, right, up, glyphs):
    """Block letters like RB.text, from a local glyph table (digits and signs live here, not in common.GLYPHS,
    so no world sign changes)."""
    old = dict(GLYPHS)
    GLYPHS.update(glyphs)
    try:
        return b.text(s, origin, px, depth, sw, right=right, up=up)
    finally:
        GLYPHS.clear()
        GLYPHS.update(old)


DIGITS = {
    "0": ("111", "101", "101", "101", "111"), "2": ("111", "001", "111", "100", "111"),
    "-": ("000", "000", "111", "000", "000"), ":": ("0", "1", "0", "1", "0"),
}


# --- the currency ------------------------------------------------------------------------------------------------

def golden_fish(mat):
    """A plump gold fish side on, its head toward -x (the picture's right): a light belly, darker fins and a forked
    tail, a happy closed eye, a pink cheek and a smile, a white glint along its back and a twinkle by its nose. The
    golds are metal in the palette, so it shines."""
    b = RB()
    _sb(b, (0, 0, 0), 1.0, "gold_mid", scale=(1.3, 0.92, 0.5))                         # body, z -0.5 to 0.5
    _sb(b, (-0.2, -0.3, -0.12), 0.8, "gold_light", scale=(1.15, 0.62, 0.48))            # belly, proud of the side
    b.fan_z(0.0, (1.05, 0.0), [(1.9, 0.78), (1.58, 0.0), (1.9, -0.78)], 0.22, "gold_dark")   # forked tail
    b.fan_z(0.0, (0.15, 0.6), [(-0.35, 0.82), (0.32, 1.28), (0.75, 0.7)], 0.14, "gold_dark")  # back fin
    b.fan_z(0.0, (0.5, -0.6), [(0.86, -0.52), (0.78, -1.02), (0.3, -0.76)], 0.12, "gold_dark")  # belly fin
    b.fan_z(-0.47, (0.08, -0.2), [(0.42, -0.1), (0.52, -0.3), (0.36, -0.44)], 0.05, "gold_dark")  # side fin
    for dx, deg in ((0.1, -38), (-0.1, 38)):                                            # a happy closed eye, ^
        b.box((-0.7 + dx, 0.2, -0.43), (0.32, 0.1, 0.08), "fur_black", rot=rot_z(deg))
    _sb(b, (-0.66, -0.12, -0.42), 0.15, "nose_pink", scale=(1.2, 0.75, 0.4))           # cheek
    for dx, deg in ((0.06, 32), (-0.06, -32)):                                          # smile
        b.box((-1.02 + dx, -0.14, -0.31), (0.17, 0.06, 0.06), "fur_black", rot=rot_z(deg))
    b.box((0.2, 0.52, -0.41), (0.46, 0.1, 0.06), "offwhite", rot=rot_z(-12))           # the glint
    b.box((0.6, 0.41, -0.38), (0.11, 0.1, 0.06), "offwhite")
    _twinkle(b, -1.25, 0.95, -0.1, 0.6)
    return [b.finalize("CatCafe_IconArt_GoldenFish", mat)]


# --- the seven foods, in rarity order -----------------------------------------------------------------------------

def _kibble_bits(b, pts, r=0.13):
    for i, p in enumerate(pts):
        b.ball(p, r, "kibble" if i % 3 else "fur_brown", scale=(1.0, 0.8, 1.0))


def kibble(mat):
    """A paper bag with a cat face on its label, kibble heaped in its open top and spilling out in front."""
    b = RB()
    b.span((-0.6, 0.0, -0.36), (0.6, 1.45, 0.36), "treat_tan")                          # the bag
    b.span((-0.64, 1.38, -0.4), (0.64, 1.52, 0.4), "cardboard")                         # its rolled top
    for x in (-0.6, 0.6):                                                               # side folds
        b.span((x - 0.02, 0.1, -0.12), (x + 0.02, 1.36, 0.12), "cardboard")
    b.cyl((0, 1.5, 0), 0.5, 0.06, "kibble", segments=12)                                # the heap's bed
    _kibble_bits(b, [(x, 1.6 + 0.04 * (k % 2), z) for k, (x, z) in enumerate(
        ((-0.38, -0.2), (-0.12, -0.24), (0.14, -0.22), (0.38, -0.18), (-0.3, 0.12), (0.0, 0.05), (0.3, 0.12),
         (-0.16, -0.02), (0.18, -0.04)))] + [(-0.06, 1.8, -0.1), (0.16, 1.76, 0.0), (-0.24, 1.74, -0.02)])
    _kibble_bits(b, [(-0.48, 1.42, -0.5), (-0.62, 1.05, -0.56), (-0.7, 0.13, -0.62), (-0.95, 0.12, -0.42),
                     (-0.86, 0.12, -0.78), (-1.1, 0.12, -0.7), (-0.6, 0.12, -0.88)])
    b.cyl((0, 0.72, -0.37), 0.44, 0.04, "bowl_red", axis="Z", segments=20)             # the label
    b.cyl((0, 0.68, -0.4), 0.3, 0.04, "offwhite", axis="Z", segments=16)               # a cat face on it
    for s in (-1, 1):
        b.fan_z(-0.4, (s * 0.08, 0.94), [(s * 0.3, 0.9), (s * 0.26, 1.16)], 0.04, "offwhite")   # ears
        b.box((s * 0.11, 0.72, -0.43), (0.07, 0.1, 0.03), "fur_black")                 # eyes
    b.box((0, 0.63, -0.43), (0.07, 0.07, 0.03), "nose_pink", rot=rot_z(45))
    return [b.finalize("CatCafe_IconArt_Kibble", mat)]


def tuna(mat):
    """A tin with a blue label and a white fish on it, its lid peeled back and standing up behind, tuna inside."""
    b = RB()
    b.cyl((0, 0.4, 0), 0.75, 0.8, "metal", segments=24)                                 # the can, y 0 to 0.8
    b.cyl((0, 0.4, 0), 0.77, 0.5, "fish_blue", segments=24)                             # its label
    for y in (0.04, 0.76):
        b.cyl((0, y, 0), 0.79, 0.08, "metal", segments=24)                              # rims
    b.ball((0, 0.8, 0), 0.68, "fur_peach", scale=(1.0, 0.18, 1.0))                     # tuna, heaped
    for (x, z) in ((-0.25, -0.2), (0.2, 0.1), (0.05, -0.35), (-0.1, 0.25), (0.35, -0.15)):
        b.ball((x, 0.88, z), 0.09, "fur_apricot", scale=(1.2, 0.6, 1.0))                # flakes
    t = 100                                                                             # the lid, hinged at the back
    hinge_y, hinge_z = 0.82, 0.72
    c = (0, hinge_y + 0.72 * math.sin(math.radians(t)), hinge_z - 0.72 * math.cos(math.radians(t)))
    b.b.cyl(RB.p(*c), 0.72, 0.04, "metal", segments=24, bevel=False, rot=RB._rot(rot_x(t)))
    b.b.cyl(RB.p(c[0], c[1], c[2] - 0.02), 0.5, 0.04, "concrete", segments=20, bevel=False, rot=RB._rot(rot_x(t)))
    b.ball((0.06, 0.42, -0.78), 0.3, "offwhite", scale=(1.0, 0.5, 0.14))               # the fish on the label
    b.fan_z(-0.78, (0.3, 0.42), [(0.46, 0.56), (0.46, 0.28)], 0.04, "offwhite")
    b.box((-0.12, 0.46, -0.82), (0.05, 0.05, 0.03), "fish_blue")
    return [b.finalize("CatCafe_IconArt_Tuna", mat)]


def _sardine(b, x, y, z, length, body="metal", back="fish_blue", belly="fish_belly", head=-1):
    """A sardine lying flat along x, its head toward `head` x, seen from above."""
    b.ball((x, y, z), length / 2, body, scale=(1.0, 0.2, 0.26))
    b.ball((x, y + 0.03, z + 0.02), length / 2 * 0.92, back, scale=(1.0, 0.18, 0.14))
    b.ball((x - 0.04 * head, y - 0.02, z - 0.06), length / 2 * 0.8, belly, scale=(1.0, 0.16, 0.14))
    tx = x - head * length * 0.48
    b.b.fan(RB.p(0, y, 0), (-tx, z), [(-(tx - head * 0.2), z - 0.16), (-(tx - head * 0.2), z + 0.16)], 0.05, back)
    b.ball((x + head * length * 0.36, y + 0.06, z - 0.05), 0.035, "fur_black")


def sardines(mat):
    """Moonlit Sardines: an open night-blue tin with a gold rim and three silvery sardines in it, the lid rolled
    back and standing behind with a crescent moon and two stars on it."""
    b = RB()
    W, D, H = 0.95, 0.6, 0.34
    b.span((-W, 0.0, -D), (W, 0.12, D), "galaxy_blue")                                  # the tin's floor
    for (lo, hi) in (((-W, 0, -D), (W, H, -D + 0.08)), ((-W, 0, D - 0.08), (W, H, D)),
                     ((-W, 0, -D), (-W + 0.08, H, D)), ((W - 0.08, 0, -D), (W, H, D))):
        b.span(lo, hi, "galaxy_blue")                                                   # its walls
    for (lo, hi) in (((-W - 0.03, H - 0.06, -D - 0.03), (W + 0.03, H + 0.02, -D + 0.05)),
                     ((-W - 0.03, H - 0.06, D - 0.05), (W + 0.03, H + 0.02, D + 0.03)),
                     ((-W - 0.03, H - 0.06, -D - 0.03), (-W + 0.05, H + 0.02, D + 0.03)),
                     ((W - 0.05, H - 0.06, -D - 0.03), (W + 0.03, H + 0.02, D + 0.03))):
        b.span(lo, hi, "rarity_legend")                                                 # the gold rim
    b.span((-W + 0.08, 0.12, -D + 0.08), (W - 0.08, 0.16, D - 0.08), "lamp_warm")       # oil
    for k, z in enumerate((-0.3, 0.0, 0.3)):
        _sardine(b, 0.04 * (k - 1), 0.26 + 0.02 * k, z, 1.6, head=1 if k % 2 else -1)
    t = 96                                                                              # the lid, rolled back
    c = (0, 0.36 + 0.62 * math.sin(math.radians(t)), D + 0.04 - 0.62 * math.cos(math.radians(t)))
    b.box(c, (2 * W + 0.04, 0.05, 1.24), "galaxy_blue", rot=rot_x(t))
    b.box((c[0], 0.38, D + 0.04), (2 * W + 0.04, 0.12, 0.12), "rarity_legend")         # the roll at the hinge
    zf = c[2] - 0.05                                                                    # its face toward us
    _crescent(b, 0.25, c[1] + 0.02, zf, 0.38, 0.17, 0.05, "sparkle")
    _star_up(b, -0.45, c[1] + 0.25, zf, 0.16, 0.07, 0.05, "sparkle")
    _star_up(b, -0.62, c[1] - 0.22, zf, 0.1, 0.045, 0.05, "sparkle")
    return [b.finalize("CatCafe_IconArt_Sardines", mat)]


def salmon(mat):
    """A pink salmon fillet with pale stripes of fat, on a big green leaf."""
    b = RB()
    _sb(b, (0, 0.04, 0), 1.3, "leaf_green", scale=(1.0, 0.05, 0.62))                   # the leaf
    b.box((0, 0.1, 0), (2.3, 0.03, 0.06), "leaf_dark")                                  # its midrib
    for s in (-1, 1):
        for x in (-0.6, 0.0, 0.6):
            b.box((x + 0.1, 0.09, s * 0.25), (0.04, 0.02, 0.5), "leaf_dark", rot=rot_y(s * 50))
    _sb(b, (0.05, 0.3, -0.05), 0.95, "fur_strawberry", scale=(1.0, 0.24, 0.48))         # the fillet
    _sb(b, (0.05, 0.36, -0.08), 0.88, "fur_peach", scale=(1.0, 0.2, 0.4))              # its lighter top
    for x in (-0.5, -0.2, 0.1, 0.4):
        b.box((x, 0.47, -0.08), (0.06, 0.04, 0.62), "offwhite", rot=rot_y(28))         # fat stripes
    b.box((0.98, 0.33, -0.05), (0.14, 0.08, 0.3), "fur_strawberry")                    # its tail end
    return [b.finalize("CatCafe_IconArt_Salmon", mat)]


def caviar(mat):
    """A small round tin heaped with shiny black pearls, its gold lid leaning against the back."""
    b = RB()
    b.cyl((0, 0.22, 0), 0.82, 0.44, "galaxy_blue", segments=24)                         # the tin, y 0 to 0.44
    for y in (0.03, 0.42):
        b.cyl((0, y, 0), 0.85, 0.07, "gold_mid", segments=24)                           # gold bands
    b.ball((0, 0.44, 0), 0.74, "fur_black", scale=(1.0, 0.3, 1.0))                     # the pearls, heaped
    for k in range(3):                                                                  # rows of pearls on top
        n, r, y = ((10, 0.6, 0.52), (7, 0.36, 0.6), (1, 0.0, 0.66))[k]
        for i in range(n):
            a = 2 * math.pi * i / n + 0.3 * k
            b.ball((r * math.cos(a), y, r * math.sin(a)), 0.12, "fur_black")
    for (x, y, z) in ((0.2, 0.7, -0.22), (-0.3, 0.64, -0.38), (0.45, 0.62, -0.42), (-0.05, 0.76, -0.04)):
        b.ball((x, y, z), 0.04, "offwhite")                                             # their shine
    t = 72                                                                              # the lid, leaning back
    c = (0.1, 0.4 + 0.86 * math.sin(math.radians(t)), 0.86 - 0.86 * math.cos(math.radians(t)) + 0.1)
    b.b.cyl(RB.p(*c), 0.88, 0.1, "gold_mid", segments=24, bevel=False, rot=RB._rot(rot_x(t)))
    b.b.cyl(RB.p(c[0], c[1], c[2] - 0.04), 0.6, 0.06, "gold_light", segments=20, bevel=False, rot=RB._rot(rot_x(t)))
    _twinkle(b, -0.9, 0.95, -0.4, 0.45)
    return [b.finalize("CatCafe_IconArt_Caviar", mat)]


def moon_milk(mat):
    """A glass bottle of glowing milk with a night-blue label and a crescent moon on it, a cork, and two little
    stars beside it."""
    b = RB()
    b.cyl((0, 0.6, 0), 0.5, 1.2, "milk", segments=20)                                   # the bottle, y 0 to 1.2
    b.cyl((0, 1.38, 0), 0.5, 0.36, "milk", r2=0.24, segments=20)                       # its shoulder
    b.cyl((0, 1.7, 0), 0.24, 0.3, "glass", segments=16)                                 # the neck
    b.cyl((0, 1.92, 0), 0.2, 0.2, "treat_tan", segments=12)                             # cork
    b.cyl((0, 0.62, 0), 0.52, 0.66, "night_sky", segments=20)                           # the label
    _crescent(b, 0.04, 0.64, -0.535, 0.19, 0.09, 0.03, "sparkle")
    b.box((-0.2, 0.84, -0.53), (0.06, 0.06, 0.03), "sparkle", rot=rot_z(45))
    b.box((0.24, 0.42, -0.53), (0.05, 0.05, 0.03), "sparkle", rot=rot_z(45))
    b.cyl((0, 0.06, 0), 0.52, 0.12, "pastel_lilac", segments=20)                        # a soft glow at the base
    _star_up(b, -0.85, 1.55, -0.1, 0.2, 0.09, 0.06, "sparkle")
    _star_up(b, 0.82, 1.15, -0.1, 0.14, 0.06, 0.06, "sparkle")
    _twinkle(b, -0.75, 0.55, -0.2, 0.36)
    return [b.finalize("CatCafe_IconArt_MoonMilk", mat)]


def star_treat(mat):
    """A golden star-shaped biscuit standing up, a raised butter star on it and sugar flecks, with a twinkle."""
    b = RB()
    _star_up(b, 0, 1.0, 0, 1.0, 0.48, 0.3, "rarity_legend")
    _star_up(b, 0, 1.0, -0.17, 0.72, 0.34, 0.06, "pastel_butter")
    for (x, y) in ((0.15, 1.2), (-0.2, 1.05), (0.05, 0.82), (-0.05, 1.4), (0.3, 0.95)):
        b.box((x, y, -0.22), (0.07, 0.07, 0.03), "offwhite", rot=rot_z(30))
    _twinkle(b, -0.95, 1.8, -0.2, 0.55)
    _twinkle(b, 0.95, 0.35, -0.2, 0.32)
    return [b.finalize("CatCafe_IconArt_StarTreat", mat)]


# --- the Golden Fish Market perks ---------------------------------------------------------------------------------

def _paw(b, x, y, z, s, sw):
    """A paw print lying flat on a top face at height y."""
    b.cyl((x, y, z), 0.26 * s, 0.03, sw, segments=12)
    for (dx, dz) in ((-0.27, -0.2), (-0.1, -0.34), (0.1, -0.34), (0.27, -0.2)):
        b.cyl((x + dx * s, y, z + dz * s), 0.09 * s, 0.03, sw, segments=8)


def golden_espresso(mat):
    """A gold espresso cup on its saucer, cream foam with a cat's paw drawn in it, and two glints."""
    b = RB()
    b.cyl((0, 0.05, 0), 0.8, 0.1, "gold_mid", segments=20)                              # saucer
    b.cyl((0, 0.13, 0), 0.6, 0.06, "gold_light", segments=20)
    b.cyl((0, 0.5, 0), 0.4, 0.7, "gold_light", r2=0.5, segments=20)                     # the cup
    b.cyl((0, 0.86, 0), 0.47, 0.03, "gold_mid", segments=20)                            # its lip
    b.cyl((0, 0.87, 0), 0.44, 0.03, "cream", segments=20)                               # foam
    b.ball((0, 0.88, 0), 0.43, "cream", scale=(1.0, 0.14, 1.0))
    b.b.ring(RB.p(0.56, 0.52, 0), 0.2, 0.07, 0.1, "gold_mid", segments=10, bevel=False, rot=(math.radians(90), "X"))
    _paw(b, 0, 0.95, 0.06, 0.95, "choco")
    _twinkle(b, -0.62, 1.15, -0.3, 0.42)
    b.box((0.3, 0.32, -0.5), (0.08, 0.08, 0.02), "sparkle")
    return [b.finalize("CatCafe_IconArt_GoldenEspresso", mat)]


def big_bowl(mat):
    """A big red bowl heaped with kibble, a little tag hung on its rim reading -2:00 (the shorter bowl wait)."""
    b = RB()
    b.cyl((0, 0.06, 0), 0.85, 0.12, "bowl_red", segments=20)
    b.b.ring(RB.p(0, 0.3, 0), 1.05, 0.2, 0.5, "bowl_red", segments=20, bevel=False)
    b.b.ring(RB.p(0, 0.44, 0), 1.08, 0.08, 0.08, "offwhite", segments=20, bevel=False)
    b.cyl((0, 0.5, 0), 0.88, 0.1, "kibble", segments=16)
    for k, (r, n, y) in enumerate(((0.62, 9, 0.62), (0.32, 6, 0.74), (0.0, 1, 0.84))):
        for i in range(n):
            a = 2 * math.pi * i / n + 0.4 * k
            b.ball((r * math.cos(a), y, r * math.sin(a)), 0.17, "kibble" if (i + k) % 2 else "treat_tan")
    cx, cy, cz = -0.45, 0.4, -1.2                                                       # the tag, standing in front
    b.box((cx, cy, cz), (1.62, 0.74, 0.06), "offwhite")                                 # z -1.23 to -1.17
    b.box((cx, cy, cz + 0.04), (1.76, 0.88, 0.04), "mint")                              # its border, behind
    b.cyl((cx + 0.7, cy + 0.22, cz - 0.03), 0.06, 0.02, "choco", axis="Z", segments=8)  # the string hole
    px = 0.085
    _glyphs(b, "-2:00", (cx + 8.5 * px, cy - 2.5 * px, cz - 0.03), px, 0.03, "fur_black", (-1, 0, 0), (0, 1, 0),
            DIGITS)
    return [b.finalize("CatCafe_IconArt_BigBowl", mat)]


def extra_decor_spot(mat):
    """A dotted square on the floor with a gold plus in it and a tiny potted plant in its back corner."""
    b = RB()
    b.span((-1.1, 0.0, -1.1), (1.1, 0.06, 1.1), "cream")                                # the floor tile
    n, s = 5, 2.0                                                                       # dashes round the edge
    for i in range(n):
        u = -s / 2 + (i + 0.5) * s / n
        for (lo, hi) in (((u - 0.14, 0.06, -0.98), (u + 0.14, 0.1, -0.88)), ((u - 0.14, 0.06, 0.88), (u + 0.14, 0.1, 0.98)),
                         ((-0.98, 0.06, u - 0.14), (-0.88, 0.11, u + 0.14)), ((0.88, 0.06, u - 0.14), (0.98, 0.11, u + 0.14))):
            b.span(lo, hi, "mint")                                                      # sides 0.01 taller
    b.span((-0.5, 0.06, -0.12), (0.5, 0.26, 0.12), "rarity_legend")                     # the plus
    b.span((-0.12, 0.06, -0.5), (0.12, 0.28, 0.5), "rarity_legend")                    # 0.02 taller, no shared top
    px, pz = -0.62, 0.6                                                                 # a tiny plant, back corner
    b.cyl((px, 0.26, pz), 0.18, 0.4, "terracotta", r2=0.22, segments=12)
    b.cyl((px, 0.46, pz), 0.2, 0.03, "choco", segments=12)
    for (x, y, z, r) in ((0, 0.66, 0, 0.18), (-0.14, 0.58, -0.06, 0.12), (0.15, 0.6, 0.03, 0.13)):
        b.ball((px + x, y, pz + z), r, "leaf_green" if r > 0.15 else "leaf_dark")
    return [b.finalize("CatCafe_IconArt_ExtraDecorSpot", mat)]


# --- prize pictures -----------------------------------------------------------------------------------------------

def coins(mat):
    """A stack of three gold coins, a little askew, a $ on the top one (the game shows money with $)."""
    b = RB()
    for i, (dx, dz) in enumerate(((0.0, 0.0), (0.1, -0.06), (-0.05, 0.04))):
        y = 0.13 + 0.26 * i
        b.cyl((dx, y, dz), 1.0, 0.24, "gold_mid", segments=24)
        b.cyl((dx, y, dz), 0.84, 0.26, "gold_light", segments=24)
    dx, dz, top = -0.05, 0.04, 0.13 + 0.52 + 0.13
    px = 0.2
    b.text("$", (dx + 1.5 * px, top, dz - 2.5 * px), px, 0.04, "gold_dark", right=(-1, 0, 0), up=(0, 0, 1))
    b.span((dx - 0.25 * px, top, dz - 3.5 * px), (dx + 0.25 * px, top + 0.04, dz + 3.5 * px), "gold_dark")
    _twinkle(b, -1.05, 1.1, -0.2, 0.55)
    return [b.finalize("CatCafe_IconArt_Coins", mat)]


def spin_wheel(mat):
    """The Spin Wheel's own wheel (spinwheel.py): eight prize slices, the gold frame with its cat ears and the pink
    pointer at the top, without the stage."""
    w = RB()
    spinwheel._wheel(w)
    spinwheel._vring(w, 0, -0.25, 0.25, spinwheel.R_FRAME_IN, spinwheel.R_FRAME_OUT, "rarity_legend")
    for s in (-1, 1):
        mid = math.radians(s * 36)

        def at(deg_off, r, mid=mid):
            a = mid + math.radians(deg_off)
            return (-math.sin(a) * r, math.cos(a) * r)
        w.fan_z(0.0, at(0, 6.35), [at(-15, spinwheel.R_FRAME_OUT - 0.2), at(15, spinwheel.R_FRAME_OUT - 0.2)], 0.4,
                "rarity_legend")
        w.fan_z(-0.22, at(0, 5.85), [at(-9, spinwheel.R_FRAME_OUT + 0.15), at(9, spinwheel.R_FRAME_OUT + 0.15)], 0.04,
                "nose_pink")
    w.box((0, 4.62, -0.6), (0.8, 0.8, 0.22), spinwheel.BOW, rot=rot_z(45))               # the pointer
    w.cyl((0, spinwheel.R_FRAME_OUT + 0.45, -0.36), 0.24, 0.3, spinwheel.BOW, axis="Z", segments=12)
    return [w.finalize("CatCafe_IconArt_Spin", mat)]
