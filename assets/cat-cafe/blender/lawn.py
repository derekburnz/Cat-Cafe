"""Front lawn pieces and styles (F91, docs/design/cat-cafe/front-lawn.md): what a player buys with coins and places on
the six lawn spots of the front garden, plus the path and fence styles. Pieces stand on the garden's grass with the
front toward the street (-Z); the pivot is the base centre on the grass top.

  Small spots (2 x 2)   CatCafe_Lawn_TulipBed, _SandwichBoard, _PottedCatTopiary, _Mailbox (Tier 1);
                        _LampPost, _BirdBath, _GardenGnomeCat (Tier 2); _BalloonBunch (Tier 4)
  Big spots (4 x 4)     _BicycleWithBasket, _GardenBench (Tier 2); _UmbrellaTable, _LittleFountain (Tier 3);
                        _FairyLightArch, _FlowerCart (Tier 4); _CatTreeSign, _GoldenPawStatue (Tier 5)
  Paths (7 x 5)         CatCafe_Lawn_Path_GreySlabs, _RedBrick, _SteppingStones, _PawPrintPath: the path from the
                        sidewalk to the door (plot x -3.5..3.5, z -20..-15), pivot its centre at the plot's floor level
                        (0.05 over the grass), so the door mat still has ground under it
  Fences                CatCafe_Lawn_Fence_WhitePicket, _LowHedge, _IronRailing, _FlowerBoxFence: both halves along
                        the sidewalk edge (plot x 3.9..19 each side) with the gap at the path; pivot the gap's centre
                        on the fence line (plot z -19.85)

Night lights are `_Bulbs` (WorldController lights them at night); lights that stay on are `_Glow`. Moving touches for
VFX-Agent follow the F89 2c contract: a child Model ending `_Swing` (about its pivot's Z, the pivot on the hook),
`_Spin` (about its Y) or `_Bob` (along Y), a light inside it a nested `_Glow`. `_Water` is water, `_Flowers` the
blooms butterflies visit. Every part is anchored.
"""

import math

from mathutils import Matrix, Vector

import common
from common import GLYPHS, RB, text_width
from crate_decor import _arc, _half_disc, _mushroom, _ring_flat, _ring_front, _rod
from plot import rot_x, rot_y, rot_z

RED, YELLOW = "shirt_red", "fur_golden"
BLOOMS = ("blush", "offwhite", "fur_golden", "pastel_lilac", "nose_pink", "shirt_red")


def _tri(b, p0, p1, p2, depth, sw):
    """One flat triangle through three Roblox points, `depth` thick: parasol panels, scallops."""
    a, c1, c2 = Vector(p0), Vector(p1), Vector(p2)
    e1 = (c1 - a).normalized()
    v = c2 - a
    e2 = (v - e1 * v.dot(e1)).normalized()
    R = Matrix((e1, e2, e1.cross(e2))).transposed()
    b.b.fan(RB.p(*a), (0.0, 0.0), [((c1 - a).length, 0.0), (v.dot(e1), v.dot(e2))], depth, sw,
            rot=common.TO_ROBLOX @ R)


def _hang(rb, name, mat, at):
    """Finalize a child Model built in the asset's own coordinates, its pivot moved to `at` (a hook, an axle)."""
    ob = rb.finalize(name, mat)
    loc = Vector(RB.p(*at))
    T = Matrix.Translation(-loc)
    ob.data.transform(T)
    common.PRIMS[ob.data.name] = [(k, T @ m, sw, ex) for k, m, sw, ex in common.PRIMS.get(ob.data.name, [])]
    ob.location = loc
    return ob


class _Local:
    """Boxes in a turned frame (a leaning board): origin o and turn R in Roblox space, sizes along the frame's axes."""

    def __init__(self, b, o, R):
        self.b, self.o, self.R = b, Vector(o), R

    def at(self, u, v, w):
        return tuple(self.o + self.R @ Vector((u, v, w)))

    def span(self, lo, hi, sw, turn=None):
        c = [(p + q) / 2 for p, q in zip(lo, hi)]
        s = [abs(q - p) for p, q in zip(lo, hi)]
        self.b.box(self.at(*c), s, sw, rot=self.R if turn is None else self.R @ turn)

    def text(self, s, u0, v0, px, w0, w1, sw, dirn=-1):
        """Block letters reading along dirn * u from u0 (the first letter's outer edge), bottom at v0."""
        cur = 0
        for ch in s.upper():
            g = GLYPHS.get(ch)
            if g is None:
                cur += 2
                continue
            for row, bits in enumerate(g):
                col = 0
                while col < len(bits):
                    if bits[col] == "1":
                        end = col
                        while end < len(bits) and bits[end] == "1":
                            end += 1
                        ua, ub = u0 + dirn * (cur + col) * px, u0 + dirn * (cur + end) * px
                        v = v0 + (4 - row) * px
                        d = 0.002 * (row % 2) * (1 if w1 < w0 else -1)       # rows never share a vertex
                        self.span((ua, v, w0 + d), (ub, v + px, w1 + d), sw)
                        col = end
                    else:
                        col += 1
            cur += len(g[0]) + 1


def _bloom(b, x, y, z, s, sw, leaf="leaf_green"):
    """A little flower clump: a leaf tuft turned 45 degrees with two blooms on it."""
    b.box((x, y + 0.5 * s, z), (s, s, s), leaf, rot=rot_y(45))
    b.box((x - 0.2 * s, y + 0.95 * s, z - 0.15 * s), (0.45 * s, 0.4 * s, 0.45 * s), sw)
    b.box((x + 0.25 * s, y + 0.85 * s, z + 0.2 * s), (0.4 * s, 0.4 * s, 0.4 * s), BLOOMS[(BLOOMS.index(sw) + 1) % 6])


def _tulip(b, x, y0, z, h, sw, leaf_a):
    """A tulip on a stem from y0 (the soil): a flared cup with its petals' tips peeking over the rim, one leaf."""
    b.span((x - 0.025, y0 - 0.05, z - 0.025), (x + 0.025, y0 + h, z + 0.025), "leaf_green")
    b.cyl((x, y0 + h + 0.08, z), 0.065, 0.18, sw, r2=0.1, segments=6)
    b.box((x, y0 + h + 0.16, z), (0.09, 0.12, 0.09), sw, rot=rot_y(45))
    a = math.radians(leaf_a)
    b.wedge((x + 0.06 * math.cos(a), y0 + 0.14, z + 0.06 * math.sin(a)), (0.03, 0.3, 0.14), "leaf_dark",
            rot=rot_y(leaf_a))


def _pot(b, x, y0, z, r, h, sw="terracotta", rim="rust"):
    """A flared flower pot standing on y0 with a rim band; returns the soil height."""
    b.cyl((x, y0 + h / 2, z), r, h, sw, r2=r * 1.2, segments=8)
    b.cyl((x, y0 + h - 0.04, z), r * 1.3, 0.1, rim, segments=8)
    return y0 + h + 0.01


# -- small spots ---------------------------------------------------------------------------------------------------
def build_tulip_bed(mat):
    """Tier 1 small: a raised wooden planter of red and yellow tulips, capped posts at the corners, a wooden plant
    label and a trowel left in the soil."""
    name = "CatCafe_Lawn_TulipBed"
    b = RB()
    H = 0.5
    b.span((-0.95, 0, -0.95), (0.95, H, -0.8), "caramel_wood")
    b.span((-0.95, 0, 0.8), (0.95, H, 0.95), "caramel_wood")
    for sx in (-1, 1):
        b.span((sx * 0.8, 0, -0.85), (sx * 0.93, H, 0.85), "caramel_wood")
        for sz in (-1, 1):
            x, z = sx * 0.9, sz * 0.9
            b.span((x - 0.08, 0, z - 0.08), (x + 0.08, 0.62, z + 0.08), "dark_wood")
            b.span((x - 0.1, 0.6, z - 0.1), (x + 0.1, 0.68, z + 0.1), "cream")
    b.span((-0.85, 0.05, -0.85), (0.85, 0.42, 0.85), "choco")
    hs = (0.62, 0.78, 0.66, 0.74, 0.58, 0.8, 0.7, 0.64, 0.76)
    k = 0
    for i, x in enumerate((-0.48, 0.0, 0.48)):
        for j, z in enumerate((-0.48, 0.0, 0.48)):
            jx, jz = 0.07 * ((k * 37) % 3 - 1), 0.07 * ((k * 53) % 3 - 1)
            _tulip(b, x + jx, 0.42, z + jz, hs[k], RED if (i + j) % 2 == 0 else YELLOW, 40 + 70 * k)
            k += 1
    b.span((-0.72, 0.38, -0.66), (-0.68, 0.78, -0.62), "caramel_wood")              # plant label on its stick
    b.span((-0.84, 0.72, -0.68), (-0.56, 0.9, -0.64), "cream")
    for dx in (-0.06, 0.0, 0.06):                                                    # a tulip drawn on it
        b.span((-0.7 + dx - 0.02, 0.8, -0.69), (-0.7 + dx + 0.02, 0.85, -0.675), RED)
    b.box((0.62, 0.46, -0.6), (0.15, 0.2, 0.03), "metal", rot=rot_x(-20))            # the trowel's blade in the soil
    _rod(b, (0.62, 0.54, -0.63), (0.66, 0.84, -0.73), 0.06, RED)
    return [b.finalize(name, mat)]


def build_sandwich_board(mat):
    """Tier 1 small: an A-frame chalkboard with cat ears on both boards, MENU over two drawn items, a coffee cup and a
    paw, on a brass hinge; a pot of daisies at its foot. The front chalk face is the child Model `_Chalk` (the newest
    menu item from F90 can be drawn on its front face)."""
    name = "CatCafe_Lawn_SandwichBoard"
    b, chalk = RB(), RB()
    W, HP, T, TILT = 1.1, 1.9, 0.08, 12
    s = math.sin(math.radians(TILT))
    for side in (-1, 1):                                     # -1 the front board, +1 the back board
        R = rot_x(-side * TILT)
        L = _Local(b, (0, s * T / 2, side * 0.42), R)
        L.span((-W / 2, 0, -T / 2), (W / 2, HP, T / 2), "caramel_wood")
        for u in (-0.36, 0.36):                                                       # ears
            L.span((u - 0.11, HP - 0.11, -T / 2 + 0.005), (u + 0.11, HP + 0.11, T / 2 - 0.005), "caramel_wood",
                   turn=rot_z(45))
        out = side * T / 2
        face = chalk if side < 0 else b
        Lf = _Local(face, L.o, R)
        Lf.span((-0.42, 0.32, out - side * 0.005), (0.42, 1.72, out + side * 0.02), "fur_black")
        if side > 0:
            continue
        w0, w1 = out - 0.02, out - 0.03                    # drawings stand proud of the chalk
        px = 0.04
        Lf_d = _Local(b, L.o, R)
        Lf_d.text("MENU", text_width("MENU", px) / 2, 1.42, px, w0, w1, "offwhite")
        for v, ln, dot in ((1.2, 0.5, "blush"), (1.02, 0.42, "pastel_sky")):        # two items with a price dot
            Lf_d.span((0.32, v, w0), (0.32 - ln, v + 0.035, w1), "offwhite")
            Lf_d.span((-0.24, v - 0.01, w0), (-0.32, v + 0.05, w1), dot)
        Lf_d.span((0.28, 0.48, w0), (0.06, 0.72, w1), "pastel_sky")                  # a cup with a handle and steam
        Lf_d.span((0.04, 0.54, w0), (-0.02, 0.66, w1), "pastel_sky")
        Lf_d.span((0.32, 0.45, w0), (0.02, 0.49, w1 - 0.008), "offwhite")
        Lf_d.span((-0.12, 0.5, w0), (-0.3, 0.62, w1), "blush")                       # a paw
        for du, dv in ((-0.12, 0.66), (-0.19, 0.69), (-0.26, 0.66)):
            Lf_d.span((du + 0.025, dv, w0), (du - 0.025, dv + 0.05, w1), "blush")
    b.cyl((0, 1.83, 0), 0.05, W + 0.08, "brass", axis="X", segments=8)               # the hinge
    y = _pot(b, 0.72, 0, -0.62, 0.14, 0.26)
    b.cyl((0.72, y - 0.03, -0.62), 0.15, 0.04, "choco", segments=8)
    _bloom(b, 0.72, y - 0.02, -0.62, 0.22, "offwhite")
    return [b.finalize(name, mat), chalk.finalize(name + "_Chalk", mat)]


def build_potted_cat_topiary(mat):
    """Tier 1 small: a box hedge trimmed into a sitting cat with its tail curled up its side and a pink bow, in a
    terracotta pot with a blush band."""
    name = "CatCafe_Lawn_PottedCatTopiary"
    b = RB()
    b.cyl((0, 0.4, 0), 0.5, 0.8, "terracotta", r2=0.6, segments=10)
    _ring_flat(b, (0, 0.84, 0), 0.66, 0.14, 0.12, "rust", segments=10)
    b.cyl((0, 0.42, 0), 0.57, 0.1, "blush", segments=10)
    b.cyl((0, 0.79, 0), 0.56, 0.06, "choco", segments=10)
    b.ball((0, 1.3, 0.05), 0.45, "leaf_green", scale=(1.0, 1.15, 0.95))
    b.ball((0, 2.0, -0.05), 0.33, "leaf_green")
    for sx in (-1, 1):
        b.b.pyramid(RB.p(sx * 0.17, 2.2, -0.05), 0.2, 0.25, "leaf_green")
        b.ball((sx * 0.16, 0.95, -0.36), 0.14, "leaf_dark")
    _arc(b, 0.42, 1.0, 0.25, 0.28, -60, 150, 5, 0.13, 0.13, "leaf_dark")
    _ring_flat(b, (0, 1.72, -0.02), 0.31, 0.07, 0.08, "blush", segments=10)
    for sx in (-1, 1):
        b.box((sx * 0.09, 1.7, -0.33), (0.14, 0.1, 0.05), "blush", rot=rot_z(sx * 25))
    b.span((-0.04, 1.66, -0.36), (0.04, 1.74, -0.3), "nose_pink")
    return [b.finalize(name, mat)]


def build_mailbox(mat):
    """Tier 1 small: a sky blue mailbox with cat ears on a wooden post in a ring of flowers, a cream door with a paw
    and a brass handle, a name plate. The red flag is the child Model `_Flag`, pivot on its hinge: it lies along the
    side pointing back, and turning it -90 degrees about its pivot's X raises it (a bait cat is ready)."""
    name = "CatCafe_Lawn_Mailbox"
    b, flag = RB(), RB()
    b.cyl((0, 0.05, 0.1), 0.5, 0.1, "choco", segments=10)
    b.span((-0.1, 0, 0.0), (0.1, 1.62, 0.2), "dark_wood")
    b.span((-0.16, 0.08, -0.06), (0.16, 0.2, 0.26), "dark_wood")
    for k in range(6):
        a = math.radians(30 + 60 * k)
        _bloom(b, 0.36 * math.cos(a), 0.08, 0.1 + 0.36 * math.sin(a), 0.16, BLOOMS[k])
    b.span((-0.25, 1.6, -0.5), (0.25, 2.0, 0.5), "pastel_sky")
    b.cyl((0, 2.0, 0), 0.25, 0.98, "pastel_sky", axis="Z", segments=12)
    b.span((-0.28, 1.57, -0.535), (0.28, 2.02, -0.495), "offwhite")
    _half_disc(b, 0, 2.0, -0.515, 0.28, 0, 180, 8, 0.04, "offwhite")
    b.span((-0.22, 1.62, -0.55), (0.22, 2.0, -0.53), "pastel_sky")
    b.cyl((0, 1.78, -0.555), 0.07, 0.02, "nose_pink", axis="Z", segments=8)
    for dx, dy in ((-0.08, 1.87), (0.0, 1.9), (0.08, 1.87)):
        b.cyl((dx, dy, -0.555), 0.03, 0.02, "nose_pink", axis="Z", segments=6)
    b.span((-0.05, 1.64, -0.58), (0.05, 1.69, -0.54), "brass")
    for sx in (-1, 1):
        b.b.pyramid(RB.p(sx * 0.14, 2.17, -0.3), 0.16, 0.18, "pastel_sky")
    b.span((-0.27, 1.66, -0.2), (-0.245, 1.86, 0.2), "offwhite")                       # name plate
    b.span((-0.28, 1.74, -0.12), (-0.265, 1.78, 0.12), "dark_wood")
    b.cyl((0.29, 1.8, 0.3), 0.05, 0.1, "brass", axis="X", segments=8)                 # the flag's hinge
    flag.span((0.31, 1.77, 0.25), (0.36, 1.83, 0.64), RED)
    flag.span((0.31, 1.69, 0.6), (0.36, 1.91, 0.9), RED)
    return [b.finalize(name, mat), _hang(flag, name + "_Flag", mat, (0.335, 1.8, 0.3))]


def build_lamp_post(mat):
    """Tier 2 small: a black iron garden lamp: an octagonal foot, a fluted post with collars, a glass lantern under a
    pyramid roof with a little gold cat on top, and a hanging flower basket on a scrolled arm. The lantern's glass is
    `_Bulbs`, lit at night."""
    name = "CatCafe_Lawn_LampPost"
    b, bulbs = RB(), RB()
    b.cyl((0, 0.2, 0), 0.38, 0.4, "fur_black", segments=8)
    b.cyl((0, 0.45, 0), 0.26, 0.12, "fur_black", segments=8)
    b.cyl((0, 2.75, 0), 0.11, 4.6, "fur_black", segments=8)
    for y in (1.3, 4.6):
        b.cyl((0, y, 0), 0.16, 0.1, "fur_black", segments=8)
    b.span((-0.32, 5.0, -0.32), (0.32, 5.1, 0.32), "fur_black")
    for sx in (-1, 1):
        for sz in (-1, 1):
            b.span((sx * 0.27 - 0.03, 5.1, sz * 0.27 - 0.03), (sx * 0.27 + 0.03, 5.85, sz * 0.27 + 0.03), "fur_black")
    b.span((-0.34, 5.85, -0.34), (0.34, 5.93, 0.34), "fur_black")
    b.b.pyramid(RB.p(0, 5.93, 0), 0.8, 0.45, "fur_black")
    bulbs.span((-0.25, 5.1, -0.25), (0.25, 5.85, 0.25), "lamp_warm")
    b.ball((0, 6.48, 0), 0.12, "gold_mid", scale=(1.0, 1.2, 0.9))                     # the gold cat on top
    b.ball((0, 6.68, 0), 0.09, "gold_mid")
    for sx in (-1, 1):
        b.b.pyramid(RB.p(sx * 0.05, 6.72, 0), 0.06, 0.08, "gold_mid")
    b.span((0.1, 4.25, -0.04), (0.66, 4.33, 0.04), "fur_black")                        # arm and its scroll
    _arc(b, 0.3, 4.1, 0, 0.15, 90, 300, 5, 0.04, 0.05, "fur_black")
    for k in range(3):
        a = math.radians(90 + 120 * k)
        _rod(b, (0.62, 4.27, 0), (0.62 + 0.2 * math.cos(a), 3.62, 0.2 * math.sin(a)), 0.02, "fur_black")
    b.cyl((0.62, 3.52, 0), 0.22, 0.22, "treat_tan", r2=0.27, segments=8)
    b.ball((0.62, 3.7, 0), 0.25, "leaf_green", scale=(1.2, 0.6, 1.2))
    for k, (dx, dz) in enumerate(((-0.15, -0.18), (0.12, -0.2), (0.22, 0.05), (-0.2, 0.12), (0.0, 0.0))):
        b.span((0.62 + dx - 0.06, 3.76, dz - 0.06), (0.62 + dx + 0.06, 3.88, dz + 0.06), BLOOMS[k])
    for dx in (-0.2, 0.2):
        b.span((0.62 + dx - 0.03, 3.25, -0.2), (0.62 + dx + 0.03, 3.6, -0.14), "leaf_dark")
    return [b.finalize(name, mat), bulbs.finalize(name + "_Bulbs", mat)]


def build_bird_bath(mat):
    """Tier 2 small: a stone bird bath, its bowl full of water, moss and flowers at its foot, and a robin on the rim.
    The robin is the child Model `_Bird_Bob`, pivot at its feet (VFX hops it on and off by day)."""
    name = "CatCafe_Lawn_BirdBath"
    b, water, bird = RB(), RB(), RB()
    b.span((-0.4, 0, -0.4), (0.4, 0.22, 0.4), "paving_tan")
    b.cyl((0, 0.28, 0), 0.28, 0.14, "paving_light", segments=8)
    b.cyl((0, 0.85, 0), 0.17, 1.1, "paving_light", r2=0.13, segments=8)
    b.cyl((0, 1.35, 0), 0.22, 0.1, "paving_tan", segments=8)
    b.cyl((0, 1.52, 0), 0.35, 0.3, "paving_light", r2=0.8, segments=12)
    _ring_flat(b, (0, 1.68, 0), 0.84, 0.12, 0.08, "paving_tan", segments=12)
    water.cyl((0, 1.6825, 0), 0.74, 0.035, "fish_blue", segments=12)
    for k, (x, z) in enumerate(((-0.55, -0.5), (0.6, -0.45), (0.55, 0.55), (-0.6, 0.5))):
        _bloom(b, x, 0, z, 0.2, BLOOMS[k + 1])
    b.span((-0.44, 0.0, -0.3), (-0.38, 0.12, 0.2), "leaf_dark")                         # moss on the foot
    b.span((0.2, 0.18, -0.44), (0.36, 0.25, -0.36), "leaf_dark")
    bx, by, bz = 0.78, 1.72, 0.05
    for dz in (-0.03, 0.03):
        bird.span((bx - 0.015, by - 0.02, bz + dz - 0.015), (bx + 0.015, by + 0.1, bz + dz + 0.015), "fur_golden")
    bird.ball((bx, by + 0.21, bz), 0.13, "fur_brown", scale=(1.35, 0.85, 1.0))
    bird.ball((bx - 0.1, by + 0.18, bz), 0.09, RED)
    bird.ball((bx - 0.12, by + 0.35, bz), 0.09, "fur_brown")
    bird.span((bx - 0.245, by + 0.335, bz - 0.015), (bx - 0.185, by + 0.365, bz + 0.015), "fur_golden")
    for dz in (-1, 1):
        bird.span((bx - 0.165, by + 0.37, bz + dz * 0.07 - 0.0125), (bx - 0.14, by + 0.395, bz + dz * 0.07 + 0.0125),
                  "fur_black")
    bird.box((bx + 0.2, by + 0.27, bz), (0.18, 0.03, 0.08), "fur_brown", rot=rot_z(-25))
    return [b.finalize(name, mat), water.finalize(name + "_Water", mat),
            _hang(bird, name + "_Bird_Bob", mat, (bx, by, bz))]


def build_garden_gnome_cat(mat):
    """Tier 2 small: a glazed garden gnome that is a ginger cat: tall red hat with its ears poking through, a white
    beard, a blue coat with a belt and buckle, boots, a lantern held in both paws, on a stone with two toadstools."""
    name = "CatCafe_Lawn_GardenGnomeCat"
    b = RB()
    b.cyl((0, 0.06, 0), 0.5, 0.12, "paving_light", segments=10)
    for sx in (-1, 1):
        b.span((sx * 0.04, 0.1, -0.22), (sx * 0.2, 0.24, 0.08), "dark_wood")
    b.cyl((0, 0.5, 0), 0.34, 0.6, "shirt_blue", r2=0.24, segments=8)
    b.cyl((0, 0.52, 0), 0.3, 0.08, "fur_black", segments=8)
    b.span((-0.06, 0.48, -0.31), (0.06, 0.56, -0.27), "gold_mid")
    for sx in (-1, 1):
        b.ball((sx * 0.29, 0.66, -0.06), 0.11, "shirt_blue")
        b.ball((sx * 0.12, 0.55, -0.3), 0.08, "fur_orange")
    b.ball((0, 1.02, -0.02), 0.27, "fur_orange")
    b.ball((0, 0.84, -0.17), 0.2, "offwhite", scale=(1.1, 1.0, 0.6))
    b.span((-0.03, 0.99, -0.29), (0.03, 1.04, -0.25), "nose_pink")
    for sx in (-1, 1):
        b.span((sx * 0.09 - 0.03, 1.06, -0.26), (sx * 0.09 + 0.03, 1.12, -0.22), "fur_black")
        b.b.pyramid(RB.p(sx * 0.2, 1.2, 0), 0.12, 0.18, "fur_orange")
    b.cyl((0, 1.42, 0), 0.27, 0.7, RED, r2=0.02, segments=8)
    b.cyl((0, 1.1, 0), 0.29, 0.06, RED, segments=8)
    _arc(b, 0.25, 0.45, 0.28, 0.18, -90, 120, 4, 0.08, 0.08, "fur_orange")
    b.span((-0.08, 0.36, -0.46), (0.08, 0.38, -0.3), "fur_black")                    # the lantern in its paws
    b.span((-0.06, 0.38, -0.44), (0.06, 0.52, -0.32), "lamp_warm")
    b.span((-0.08, 0.52, -0.46), (0.08, 0.55, -0.3), "fur_black")
    b.span((-0.015, 0.55, -0.39), (0.015, 0.6, -0.37), "fur_black")
    _mushroom(b, 0.33, 0.12, -0.28, 1.0)
    _mushroom(b, -0.34, 0.12, 0.22, 0.8, RED)
    return [b.finalize(name, mat)]


BALLOONS = ((-0.55, 3.4, -0.2, "blush"), (0.55, 3.6, -0.25, "pastel_sky"), (-0.45, 4.45, 0.35, "mint"),
            (0.5, 4.6, 0.3, "fur_golden"), (0.0, 4.0, 0.15, "cat"), (0.05, 5.2, -0.1, "led"))


def build_balloon_bunch(mat):
    """Tier 4 small: six balloons tied to a lilac gift box with a gold ribbon and bow: four pastel ones, a gold foil
    cat head and a clear LED balloon with its light inside. The balloons and strings are the child Model
    `_Balloons_Swing`, pivot on the knot (VFX sways them in the wind); the LED is its nested `_Balloons_Glow`."""
    name = "CatCafe_Lawn_BalloonBunch"
    b, sw, glow = RB(), RB(), RB()
    b.span((-0.32, 0, -0.32), (0.32, 0.58, 0.32), "pastel_lilac")
    b.span((-0.35, 0.56, -0.35), (0.35, 0.68, 0.35), "pastel_lilac")
    b.span((-0.06, 0.0, -0.36), (0.06, 0.69, 0.36), "gold_mid")
    b.span((-0.36, 0.0, -0.06), (0.36, 0.695, 0.06), "gold_mid")
    for sx in (-1, 1):
        b.box((sx * 0.12, 0.76, 0), (0.22, 0.12, 0.08), "gold_mid", rot=rot_z(sx * 25))
    b.span((-0.05, 0.69, -0.05), (0.05, 0.79, 0.05), "gold_mid")
    for x, y, z, col in BALLOONS:
        if col == "cat":
            sw.ball((x, y, z), 0.5, "gold_light", scale=(1.15, 0.95, 0.45))
            for sx in (-1, 1):
                sw.b.pyramid(RB.p(x + sx * 0.29, y + 0.33, z), 0.22, 0.26, "gold_light")
                sw.span((x + sx * 0.17 - 0.035, y + 0.05, z - 0.2), (x + sx * 0.17 + 0.035, y + 0.14, z - 0.175),
                        "fur_black")
            sw.span((x - 0.035, y - 0.06, z - 0.215), (x + 0.035, y, z - 0.19), "nose_pink")
            bottom = y - 0.47
        else:
            sw.ball((x, y, z), 0.44, "glass" if col == "led" else col, scale=(1.0, 1.18, 1.0))
            if col == "led":
                glow.ball((x, y, z), 0.2, "lamp_warm")
                _rod(sw, (x, y - 0.5, z), (x, y - 0.15, z), 0.015, "offwhite")            # the LED's wire
            bottom = y - 0.44 * 1.18
        knot = "gold_light" if col in ("cat", "led") else col
        sw.b.pyramid(RB.p(x, bottom - 0.06, z), 0.1, 0.1, knot)
        _rod(sw, (0, 0.75, 0), (x, bottom - 0.04, z), 0.02, "offwhite")
    return [b.finalize(name, mat), _hang(sw, name + "_Balloons_Swing", mat, (0, 0.79, 0)),
            _hang(glow, name + "_Balloons_Glow", mat, (0, 0.79, 0))]


# -- big spots -----------------------------------------------------------------------------------------------------
def _wheel(b, x, y, z, r, tire, rim, spokes=3):
    """A spoked wheel facing the front (-Z)."""
    _ring_front(b, (x, y, z), r, 0.09, 0.09, tire, segments=12)
    _ring_front(b, (x, y, z), r - 0.07, 0.05, 0.05, rim, segments=10)
    for k in range(spokes):
        b.box((x, y, z), (2 * (r - 0.11), 0.025, 0.025), rim, rot=rot_z(180 * k / spokes))
    b.cyl((x, y, z), 0.07, 0.16, rim, axis="Z", segments=8)


def build_bicycle_with_basket(mat):
    """Tier 2 big: a mint step-through bicycle on its kickstand: a wicker basket of flowers and a baguette on the
    front, a crate with a fern on the rear rack, fenders, a brown saddle and a gold bell; a watering can and a pot of
    lavender beside it."""
    name = "CatCafe_Lawn_BicycleWithBasket"
    b = RB()
    F, ZB = "mint", -0.35
    RH, FH, WR = (-0.95, 0.6), (1.0, 0.6), 0.62
    for hx, hy in (RH, FH):
        _wheel(b, hx, hy, ZB, WR, "fur_black", "metal")
        _arc(b, hx, hy, ZB, 0.645, 25 if hx > 0 else 30, 150 if hx > 0 else 170, 6, 0.07, 0.15, F)
    BB = (-0.15, 0.62)
    p = lambda x, y, dz=0.0: (x, y, ZB + dz)                                         # noqa: E731
    _rod(b, p(*BB), p(-0.38, 1.45), 0.08, F)                                         # seat tube
    _rod(b, p(*BB), p(0.79, 1.12), 0.08, F)                                          # down tube
    _rod(b, p(-0.25, 1.05), p(0.78, 1.25), 0.07, F)                                  # the low top tube
    _rod(b, p(0.8, 1.08), p(0.74, 1.42), 0.1, F)                                     # head tube
    b.box(p(0.81, 1.1), (0.14, 0.1, 0.22), F)                                        # fork crown
    for dz in (-0.075, 0.075):
        _rod(b, p(BB[0], BB[1], dz), p(RH[0], RH[1], dz), 0.05, F)                   # chain stays
        _rod(b, p(-0.36, 1.4, dz), p(RH[0], RH[1], dz), 0.05, F)                     # seat stays
        _rod(b, p(0.81, 1.08, dz), p(FH[0], FH[1], dz), 0.05, F)                     # fork
    _ring_front(b, p(BB[0], BB[1], 0.09), 0.17, 0.05, 0.03, "metal", segments=8)    # chainring
    _rod(b, p(-0.38, 1.4), p(-0.41, 1.55), 0.05, "metal")
    b.box(p(-0.43, 1.58), (0.42, 0.1, 0.22), "fur_brown")                            # saddle
    _rod(b, p(0.74, 1.4), p(0.68, 1.76), 0.06, "metal")
    b.box(p(0.66, 1.76), (0.06, 0.06, 0.8), "metal")                                 # handlebar and grips
    for dz in (-0.34, 0.34):
        b.box(p(0.66, 1.76, dz), (0.09, 0.09, 0.14), "caramel_wood")
    b.cyl(p(0.7, 1.82, 0.22), 0.05, 0.06, "gold_mid", segments=8)                    # bell
    # wicker basket on the front, on a bracket from the head tube
    x0, x1, y0, y1, h = 0.86, 1.38, 1.36, 1.78, 0.3
    b.span(p(x0, y0, -h), p(x1, y0 + 0.04, h), "treat_tan")
    b.span(p(x0, y0, -h), p(x0 + 0.04, y1, h), "treat_tan")
    b.span(p(x1 - 0.04, y0, -h), p(x1, y1, h), "treat_tan")
    for dz in (-h, h):
        b.span(p(x0 + 0.02, y0, dz - 0.02), p(x1 - 0.02, y1, dz + 0.02), "treat_tan")
    for y in (1.48, 1.62):                                                           # weave
        b.span(p(x0 - 0.01, y, -h - 0.03), p(x1 + 0.01, y + 0.04, -h + 0.01), "kibble")
    _rod(b, p(0.76, 1.36), p(0.9, 1.46), 0.05, "metal")
    b.span(p(x0 + 0.05, y0 + 0.04, -h + 0.05), p(x1 - 0.05, 1.7, h - 0.05), "leaf_green")
    for k, (dx, dz) in enumerate(((0.1, -0.15), (0.3, -0.05), (0.18, 0.12), (0.38, 0.18), (0.25, -0.22))):
        b.span(p(x0 + dx - 0.07, 1.7, dz - 0.07), p(x0 + dx + 0.07, 1.85, dz + 0.07), BLOOMS[k])
    _rod(b, p(1.0, 1.6, 0.15), p(1.3, 2.05, 0.2), 0.11, "kibble")                    # baguette
    # rear rack with a crate and a fern
    b.span(p(-1.25, 1.18, -0.16), p(-0.72, 1.22, 0.16), "metal")
    for dz in (-0.12, 0.12):
        _rod(b, p(-1.2, 1.19, dz), p(RH[0], RH[1], dz * 0.6), 0.04, "metal")
    b.span(p(-1.22, 1.22, -0.18), p(-0.76, 1.5, 0.18), "caramel_wood")
    b.span(p(-1.18, 1.26, -0.185), p(-0.8, 1.3, 0.185), "dark_wood")
    b.ball(p(-0.99, 1.62), 0.2, "leaf_green", scale=(1.2, 0.8, 1.0))
    _rod(b, (-0.3, 0.0, ZB + 0.35), (BB[0], BB[1], ZB + 0.06), 0.04, "metal")        # kickstand
    # a watering can and lavender beside it
    b.cyl((1.25, 0.22, 0.95), 0.2, 0.44, "pastel_sky", segments=8)
    _rod(b, (1.08, 0.2, 0.95), (0.8, 0.5, 0.95), 0.05, "pastel_sky")
    _arc(b, 1.25, 0.44, 0.95, 0.14, 0, 180, 4, 0.04, 0.05, "pastel_sky")
    y = _pot(b, 0.45, 0, 1.0, 0.18, 0.3)
    for k in range(4):
        a = math.radians(90 * k + 20)
        b.span((0.45 + 0.08 * math.cos(a) - 0.03, y - 0.05, 1.0 + 0.08 * math.sin(a) - 0.03),
               (0.45 + 0.08 * math.cos(a) + 0.03, y + 0.45, 1.0 + 0.08 * math.sin(a) + 0.03), "pastel_lilac")
    return [b.finalize(name, mat)]


GARDEN_BENCH_SPOTS = {"NapSpot": (-0.9, 1.16, 0.0)}


def build_garden_bench(mat):
    """Tier 2 big: a park bench of caramel slats on cast iron ends with paw feet and a brass cat head on the back, a
    blush cushion, a sky blue pillow with a paw, and a pot of lavender at each front corner. Its `NapSpot`
    attachment is where a roaming cat curls up on the cushion."""
    name = "CatCafe_Lawn_GardenBench"
    b = RB()
    for sx in (-1, 1):
        x = sx * 1.6
        b.span((x - 0.07, 0, -0.48), (x + 0.07, 1.45, -0.36), "fur_black")
        _rod(b, (x, 0, 0.5), (x, 2.1, 0.42), 0.12, "fur_black")
        b.span((x - 0.07, 1.4, -0.6), (x + 0.07, 1.5, 0.47), "fur_black")
        b.span((x - 0.07, 0.82, -0.47), (x + 0.07, 0.9, 0.48), "fur_black")
        b.ball((x, 0.07, -0.47), 0.11, "fur_black", scale=(1.0, 0.6, 1.3))
        for dx in (-0.05, 0.05):
            b.ball((x + dx, 0.05, -0.6), 0.04, "fur_black")
    for z in (-0.42, -0.21, 0.0, 0.21, 0.4):
        b.span((-1.62, 0.88, z - 0.085), (1.62, 1.0, z + 0.085), "caramel_wood")
    b.span((-0.05, 0.6, -0.38), (0.05, 0.89, 0.38), "fur_black")
    for y in (1.25, 1.55, 1.85):
        z = 0.5 - 0.08 * y / 2.1
        b.span((-1.62, y - 0.1, z - 0.05), (1.62, y + 0.1, z + 0.05), "caramel_wood")
    zf = 0.5 - 0.08 * 1.55 / 2.1 - 0.06
    b.cyl((0, 1.55, zf - 0.02), 0.26, 0.06, "brass", axis="Z", segments=12)
    for sx in (-1, 1):
        b.fan_z(zf - 0.02, (sx * 0.2, 1.98), [(sx * 0.04, 1.72), (sx * 0.26, 1.66)], 0.06, "brass")
        b.span((sx * 0.09 - 0.03, 1.58, zf - 0.06), (sx * 0.09 + 0.03, 1.64, zf - 0.045), "fur_black")
    b.span((-0.03, 1.5, zf - 0.06), (0.03, 1.54, zf - 0.045), "nose_pink")
    b.span((-1.42, 0.99, -0.42), (-0.38, 1.16, 0.36), "blush")
    b.box((1.0, 1.32, 0.28), (0.6, 0.5, 0.15), "pastel_sky", rot=rot_x(-12))
    b.cyl((1.0, 1.32, 0.2), 0.08, 0.04, "offwhite", axis="Z", segments=8)
    for sx in (-1, 1):
        y = _pot(b, sx * 1.62, 0, -1.0, 0.2, 0.34)
        for k in range(4):
            a = math.radians(90 * k + 30)
            b.span((sx * 1.62 + 0.09 * math.cos(a) - 0.03, y - 0.05, -1.0 + 0.09 * math.sin(a) - 0.03),
                   (sx * 1.62 + 0.09 * math.cos(a) + 0.03, y + 0.42, -1.0 + 0.09 * math.sin(a) + 0.03),
                   "pastel_lilac")
    return [b.finalize(name, mat)]


UMBRELLA_TABLE_SPOTS = {"Seat1": (-1.3, 0, 0), "Seat2": (1.3, 0, 0)}


def build_umbrella_table(mat):
    """Tier 3 big: a round iron cafe table set for two under a blush and cream striped parasol with a scalloped edge:
    a vase of flowers, a cup on its saucer and a slice of cake. The chairs' cushions sit as high as the cafe's, and
    the `Seat1` and `Seat2` attachments are on the floor under them (a customer faces the table)."""
    name = "CatCafe_Lawn_UmbrellaTable"
    b = RB()
    b.span((-0.45, 0, -0.06), (0.45, 0.08, 0.06), "fur_black")
    b.span((-0.06, 0, -0.45), (0.06, 0.085, 0.45), "fur_black")
    b.cyl((0, 1.18, 0), 0.06, 2.26, "fur_black", segments=8)
    b.cyl((0, 2.35, 0), 0.75, 0.08, "offwhite", segments=14)
    _ring_flat(b, (0, 2.35, 0), 0.79, 0.07, 0.1, "fur_black", segments=14)
    b.cyl((0, 2.4, 0), 0.5, 0.02, "pastel_sky", segments=14)
    b.cyl((0, 3.9, 0), 0.05, 3.2, "offwhite", segments=6)
    apex, rim_y, R = 5.4, 4.55, 1.9
    for k in range(8):
        a0, a1 = math.radians(45 * k), math.radians(45 * (k + 1))
        up = 0.03 * (k % 2)
        col = "blush" if k % 2 else "offwhite"
        p1 = (R * math.cos(a0), rim_y + up, R * math.sin(a0))
        p2 = (R * math.cos(a1), rim_y + up, R * math.sin(a1))
        _tri(b, (0, apex + up, 0), p1, p2, 0.04, col)
        q1 = Vector(p1).lerp(Vector(p2), 0.12)
        q2 = Vector(p1).lerp(Vector(p2), 0.88)
        mid = Vector(p1).lerp(Vector(p2), 0.5)
        _tri(b, (q1.x, q1.y + 0.01, q1.z), (q2.x, q2.y + 0.01, q2.z), (mid.x, mid.y - 0.28, mid.z), 0.03,
             "offwhite" if k % 2 else "blush")
    b.ball((0, apex + 0.08, 0), 0.1, "offwhite")
    b.cyl((0, 4.95, 0), 0.08, 0.12, "offwhite", segments=6)
    for sx in (-1, 1):
        cx = sx * 1.3
        b.cyl((cx, 1.45, 0), 0.38, 0.1, "fur_black", segments=12)
        b.cyl((cx, 1.53, 0), 0.34, 0.08, "blush", segments=12)
        for dx in (-0.26, 0.26):
            for dz in (-0.26, 0.26):
                _rod(b, (cx + dx * 1.1, 0, dz * 1.1), (cx + dx * 0.85, 1.42, dz * 0.85), 0.05, "fur_black")
        for dz in (-0.22, 0.22):
            _rod(b, (cx + sx * 0.3, 1.45, dz), (cx + sx * 0.4, 2.65, dz * 1.1), 0.05, "fur_black")
        for y in (2.1, 2.55):
            b.span((cx + sx * 0.36 - 0.03, y - 0.04, -0.27), (cx + sx * 0.36 + 0.03, y + 0.04, 0.27), "fur_black")
    b.cyl((0.28, 2.53, -0.18), 0.07, 0.24, "glass", segments=8)                     # vase
    for k, (dx, dz) in enumerate(((-0.04, -0.03), (0.05, 0.0), (0.0, 0.05))):
        _rod(b, (0.28 + dx * 0.5, 2.6, -0.18 + dz * 0.5), (0.28 + dx * 2, 2.85, -0.18 + dz * 2), 0.02, "leaf_green")
        b.span((0.28 + dx * 2 - 0.05, 2.83, -0.18 + dz * 2 - 0.05), (0.28 + dx * 2 + 0.05, 2.93, -0.18 + dz * 2 + 0.05),
               BLOOMS[k])
    b.cyl((-0.3, 2.42, 0.05), 0.16, 0.02, "offwhite", segments=10)                  # saucer, cup, handle
    b.cyl((-0.3, 2.5, 0.05), 0.09, 0.14, "mint", segments=8)
    b.span((-0.42, 2.47, 0.03), (-0.385, 2.55, 0.07), "mint")
    b.cyl((0.1, 2.42, 0.32), 0.18, 0.02, "offwhite", segments=10)                   # cake on a plate
    b.box((0.1, 2.5, 0.32), (0.22, 0.14, 0.16), "cream", rot=rot_y(30))
    b.box((0.1, 2.58, 0.32), (0.235, 0.03, 0.175), "blush", rot=rot_y(30))
    b.ball((0.1, 2.63, 0.32), 0.04, RED)
    return [b.finalize(name, mat)]


FOUNTAIN_SCALE = 0.78


def build_little_fountain(mat):
    """Tier 3 big: an octagonal stone fountain: a stone cat on top pours a jug into the upper bowl, which spills into
    the basin on four sides; lily pads, a water lily and coins in the water; a flowering shrub in each corner. All
    the water is `_Water` (VFX ripples it)."""
    name = "CatCafe_Lawn_LittleFountain"
    b, water = RB(), RB()
    b.cyl((0, 0.3, 0), 1.75, 0.6, "paving_light", segments=8)
    _ring_flat(b, (0, 0.64, 0), 1.85, 0.3, 0.12, "paving_tan", segments=8)
    water.cyl((0, 0.62, 0), 1.6, 0.06, "fish_blue", segments=8)
    for x, z, r in ((0.8, -0.75, 0.28), (-0.95, 0.45, 0.24), (0.55, 0.9, 0.2)):
        b.cyl((x, 0.655, z), r, 0.02, "leaf_green", segments=8)
    b.span((0.75, 0.66, -0.8), (0.87, 0.74, -0.68), "fur_bubblegum")
    b.span((0.78, 0.7, -0.77), (0.84, 0.77, -0.71), "pastel_butter")
    for x, z in ((-0.6, -0.9), (-1.1, -0.2), (1.1, 0.2)):
        b.cyl((x, 0.61, z), 0.08, 0.02, "gold_mid", segments=8)
    b.cyl((0, 1.15, 0), 0.32, 1.1, "paving_light", r2=0.24, segments=8)
    b.cyl((0, 1.85, 0), 0.3, 0.3, "paving_light", r2=0.8, segments=10)
    _ring_flat(b, (0, 2.02, 0), 0.84, 0.12, 0.08, "paving_tan", segments=10)
    water.cyl((0, 2.015, 0), 0.74, 0.05, "fish_blue", segments=10)
    b.cyl((0, 2.1, 0), 0.22, 0.2, "paving_tan", segments=8)
    b.ball((0, 2.55, 0.05), 0.3, "cream", scale=(1.0, 1.25, 0.9))                   # the stone cat
    b.ball((0, 3.05, -0.05), 0.22, "cream")
    for sx in (-1, 1):
        b.b.pyramid(RB.p(sx * 0.11, 3.18, -0.05), 0.12, 0.15, "cream")
    _arc(b, 0.25, 2.3, 0.25, 0.18, -90, 110, 4, 0.08, 0.08, "cream")
    b.cyl((0, 2.6, -0.33), 0.1, 0.24, "terracotta", segments=8)                      # its jug and spout
    b.span((-0.03, 2.66, -0.47), (0.03, 2.71, -0.4), "terracotta")
    water.span((-0.022, 2.03, -0.5), (0.022, 2.7, -0.45), "fish_blue")
    for k in range(4):
        a = math.radians(45 + 90 * k)
        x, z = 0.86 * math.cos(a), 0.86 * math.sin(a)
        water.span((x - 0.04, 0.63, z - 0.04), (x + 0.04, 2.03, z + 0.04), "fish_blue")
    for sx in (-1, 1):
        for sz in (-1, 1):
            x, z = sx * 1.68, sz * 1.68
            b.ball((x, 0.32, z), 0.34, "leaf_green", scale=(1.0, 0.9, 1.0))
            for k in range(3):
                a = math.radians(120 * k + 40 * sx)
                b.span((x + 0.2 * math.cos(a) - 0.06, 0.5, z + 0.2 * math.sin(a) - 0.06),
                       (x + 0.2 * math.cos(a) + 0.06, 0.62, z + 0.2 * math.sin(a) + 0.06),
                       BLOOMS[(k + (sx + 1) + (sz + 1) // 2) % 6])
    objs = [b.finalize(name, mat), water.finalize(name + "_Water", mat)]
    for ob in objs:                 # 3.1 across: a big spot under a window has 3.2 of depth (front-lawn.md, Layout)
        common.scale_mesh(ob, FOUNTAIN_SCALE)
    return objs


def build_fairy_light_arch(mat):
    """Tier 4 big: a white garden arbour with lattice sides and a bench seat, climbing roses over the arch, a strand
    of fairy lights along the front and up the posts (`_Bulbs`, lit at night) and a lantern hanging from the top of
    the arch: the child Model `_Lantern_Swing`, pivot on its hook, its light the nested `_Lantern_Glow`."""
    name = "CatCafe_Lawn_FairyLightArch"
    b, bulbs, lan, lglow = RB(), RB(), RB(), RB()
    X, Z, TOP, R = 1.45, 0.55, 3.4, 1.45
    for sx in (-1, 1):
        for sz in (-1, 1):
            b.span((sx * X - 0.1, 0, sz * Z - 0.1), (sx * X + 0.1, TOP, sz * Z + 0.1), "offwhite")
        x = sx * X
        for z in (-0.15, 0.15):
            b.span((x - 0.025, 0.3, z - 0.025), (x + 0.025, 3.2, z + 0.025), "offwhite")
        for y in (0.6, 1.2, 1.8, 2.4, 3.0):
            b.span((x - 0.03, y - 0.03, -Z), (x + 0.03, y + 0.03, Z), "offwhite")
    for z in (-Z, Z):
        _arc(b, 0, TOP, z, R, 0, 180, 9, 0.2, 0.2, "offwhite")
    for k in range(1, 8):
        a = math.radians(22.5 * k)
        b.box(((R + 0.12) * math.cos(a), TOP + (R + 0.12) * math.sin(a), 0), (0.08, 0.08, 1.5), "offwhite",
              rot=rot_z(22.5 * k))
    for z in (0.1, 0.28, 0.46):                                                        # the bench seat
        b.span((-X, 0.9, z - 0.075), (X, 1.0, z + 0.075), "caramel_wood")
    b.span((-X, 0.6, 0.0), (X, 0.9, 0.06), "offwhite")
    b.span((-1.2, 0.99, 0.05), (1.2, 1.12, 0.52), "blush")
    for y in (1.4, 1.8):                                                               # back rails
        b.span((-X, y - 0.05, Z - 0.04), (X, y + 0.05, Z + 0.04), "offwhite")
    roses = [(R * math.cos(math.radians(a)), TOP + R * math.sin(math.radians(a)), -Z - 0.1)
             for a in (15, 50, 85, 120, 160)]
    roses += [(-X - 0.1, 1.5, -Z), (-X - 0.1, 2.6, -Z), (X + 0.1, 2.2, -Z), (X + 0.1, 0.8, -Z),
              (0.3, TOP + R + 0.1, 0.0), (-0.9, TOP + 1.1, 0.4)]
    for k, (x, y, z) in enumerate(roses):
        for j in range(3):
            a = 47 * k + 120 * j
            dx, dy = 0.14 * math.cos(math.radians(a)), 0.14 * math.sin(math.radians(a))
            b.box((x + dx, y + dy, z + 0.035 * j), (0.24, 0.24, 0.24), "leaf_dark" if j else "leaf_green",
                  rot=rot_z(a + 20))
        for j in range(2):
            a = 47 * k + 180 * j + 60
            b.box((x + 0.12 * math.cos(math.radians(a)), y + 0.12 * math.sin(math.radians(a)), z - 0.1),
                  (0.12, 0.12, 0.12), ("blush", RED, "offwhite")[(k + j) % 3], rot=rot_z(45))
    pts = []                                                                           # the fairy light strand
    for k in range(13):
        a = math.radians(5 + 170 * k / 12)
        rr = R - (0.0 if k % 2 == 0 else 0.22)
        pts.append((rr * math.cos(a), TOP + rr * math.sin(a), -Z - 0.09))
    for p0, p1 in zip(pts, pts[1:]):
        _rod(b, p0, p1, 0.025, "leaf_dark")
    for k, (x, y, z) in enumerate(pts):
        if k % 2:
            bulbs.span((x - 0.04, y - 0.12, z - 0.04), (x + 0.04, y - 0.01, z + 0.04), "lamp_warm")
        bulbs.span((x - 0.035, y - 0.035, z - 0.035), (x + 0.035, y + 0.035, z + 0.035), "lamp_warm")
    for sx in (-1, 1):
        for k, y in enumerate((0.7, 1.3, 1.9, 2.5, 3.1)):
            dz = -0.105 if k % 2 == 0 else 0.0
            x = sx * (X + (0.105 if k % 2 else 0.0))
            bulbs.span((x - 0.04, y - 0.04, -Z + dz - 0.04), (x + 0.04, y + 0.04, -Z + dz + 0.04), "lamp_warm")
    hy = TOP + R - 0.1                                                                 # hook under the arch top
    b.cyl((0, hy, -Z), 0.03, 0.12, "fur_black", segments=6)
    lan.span((-0.015, hy - 0.55, -Z - 0.015), (0.015, hy + 0.04, -Z + 0.015), "fur_black")
    lan.span((-0.13, hy - 0.58, -Z - 0.13), (0.13, hy - 0.52, -Z + 0.13), "fur_black")
    lan.span((-0.13, hy - 0.94, -Z - 0.13), (0.13, hy - 0.88, -Z + 0.13), "fur_black")
    for sx in (-1, 1):
        for sz in (-1, 1):
            lan.span((sx * 0.11 - 0.02, hy - 0.9, -Z + sz * 0.11 - 0.02), (sx * 0.11 + 0.02, hy - 0.56,
                     -Z + sz * 0.11 + 0.02), "fur_black")
    lglow.span((-0.1, hy - 0.89, -Z - 0.1), (0.1, hy - 0.57, -Z + 0.1), "lamp_warm")
    return [b.finalize(name, mat), bulbs.finalize(name + "_Bulbs", mat),
            _hang(lan, name + "_Lantern_Swing", mat, (0, hy, -Z)),
            _hang(lglow, name + "_Lantern_Glow", mat, (0, hy, -Z))]


def build_flower_cart(mat):
    """Tier 4 big: a florist's cart on two wagon wheels under a mint and cream striped canopy with a scalloped edge:
    three tiers of potted flowers (the blooms are `_Flowers`, which butterflies visit), a chalkboard reading
    FLOWERS, a bucket of tulips at its foot and a lantern on the canopy's corner: the child Model `_Lantern_Swing`
    with its light the nested `_Lantern_Glow`."""
    name = "CatCafe_Lawn_FlowerCart"
    b, fl, lan, lglow = RB(), RB(), RB(), RB()
    b.span((-1.3, 0.9, -0.55), (1.3, 1.0, 0.55), "caramel_wood")
    b.span((-1.32, 1.0, -0.6), (1.32, 1.4, -0.52), "mint")
    b.span((-1.32, 1.0, 0.52), (1.32, 1.4, 0.6), "mint")
    for sx in (-1, 1):
        b.span((sx * 1.27, 1.0, -0.53), (sx * 1.35, 1.4, 0.53), "mint")
    b.span((-1.34, 1.38, -0.64), (1.34, 1.44, -0.58), "offwhite")
    for sz in (-1, 1):
        _wheel(b, 0.1, 0.74, sz * 0.7, 0.75, "dark_wood", "caramel_wood", spokes=3)
    b.cyl((0.1, 0.74, 0), 0.06, 1.5, "fur_black", axis="Z", segments=8)
    b.span((-0.05, 0.74, -0.5), (0.25, 0.92, 0.5), "dark_wood")
    for sz in (-1, 1):
        _rod(b, (1.2, 1.0, sz * 0.4), (1.9, 1.25, sz * 0.4), 0.07, "caramel_wood")
    _rod(b, (-1.15, 0.0, 0.0), (-1.15, 0.92, 0.0), 0.1, "dark_wood")
    b.span((-1.25, 0.99, -0.15), (1.25, 1.35, 0.5), "caramel_wood")
    b.span((-1.25, 1.34, 0.15), (1.25, 1.7, 0.5), "caramel_wood")
    rows = ((1.0, -0.35, 5), (1.35, -0.0, 5), (1.7, 0.33, 4))
    n = 0
    for y0, z, cnt in rows:
        for k in range(cnt):
            x = -1.0 + 2.0 * k / (cnt - 1)
            b.cyl((x, y0 + 0.1, z), 0.12, 0.2, "terracotta", r2=0.15, segments=6)
            y = y0 + 0.2
            b.box((x, y + 0.06, z), (0.24, 0.18, 0.24), "leaf_green", rot=rot_y(45 + 20 * k))
            fl.span((x - 0.13, y + 0.14, z - 0.1), (x - 0.01, y + 0.26, z + 0.02), BLOOMS[n % 6])
            fl.span((x + 0.0, y + 0.12, z - 0.02), (x + 0.12, y + 0.24, z + 0.1), BLOOMS[(n + 2) % 6])
            n += 1
    b.span((-0.74, 3.04, -0.76), (0.74, 3.46, -0.68), "caramel_wood")                  # sign on the canopy
    b.span((-0.66, 3.1, -0.775), (0.66, 3.4, -0.755), "fur_black")
    px = 1.2 / text_width("FLOWERS", 1.0)
    _Local(b, (0, 0, 0), Matrix.Identity(3)).text("FLOWERS", 0.6, 3.25 - 2.5 * px, px, -0.77, -0.785, "offwhite")
    for sx in (-1, 1):
        for sz in (-1, 1):
            b.span((sx * 1.22 - 0.04, 1.0, sz * 0.47 - 0.04), (sx * 1.22 + 0.04, 3.02, sz * 0.47 + 0.04), "offwhite")
    for k in range(6):
        x0 = -1.41 + 0.47 * k
        col = "mint" if k % 2 == 0 else "offwhite"
        t = 0.06 if k % 2 == 0 else 0.07
        b.span((x0, 3.0, -0.75), (x0 + 0.48, 3.0 + t, 0.65), col)
        b.fan_z(-0.76, (x0 + 0.24, 2.78), [(x0 + 0.03, 3.02), (x0 + 0.45, 3.02)], 0.03, col)
    for (x, z) in ((-0.6, -1.0),):                                                     # a bucket of tulips
        b.cyl((x, 0.18, z), 0.2, 0.36, "metal", r2=0.24, segments=8)
        for k in range(3):
            a = math.radians(120 * k + 45)
            _tulip(b, x + 0.09 * math.cos(a), 0.33, z + 0.09 * math.sin(a), 0.35 + 0.05 * (k % 2),
                   (RED, YELLOW, "blush")[k], 120 * k)
    hx, hy, hz = 1.2, 2.99, -0.62
    lan.span((hx - 0.015, hy - 0.4, hz - 0.015), (hx + 0.015, hy + 0.02, hz + 0.015), "fur_black")
    lan.span((hx - 0.12, hy - 0.43, hz - 0.12), (hx + 0.12, hy - 0.38, hz + 0.12), "fur_black")
    lan.span((hx - 0.12, hy - 0.76, hz - 0.12), (hx + 0.12, hy - 0.71, hz + 0.12), "fur_black")
    for sx in (-1, 1):
        for sz in (-1, 1):
            lan.span((hx + sx * 0.1 - 0.02, hy - 0.73, hz + sz * 0.1 - 0.02),
                     (hx + sx * 0.1 + 0.02, hy - 0.41, hz + sz * 0.1 + 0.02), "fur_black")
    lglow.span((hx - 0.09, hy - 0.72, hz - 0.09), (hx + 0.09, hy - 0.42, hz + 0.09), "lamp_warm")
    return [b.finalize(name, mat), fl.finalize(name + "_Flowers", mat),
            _hang(lan, name + "_Lantern_Swing", mat, (hx, hy, hz)),
            _hang(lglow, name + "_Lantern_Glow", mat, (hx, hy, hz))]


def build_cat_tree_sign(mat):
    """Tier 5 big: a tall sign built like a cat tree: sisal posts on a carpeted base with paw prints, two carpeted
    platforms, a marquee board ringed with bulbs (`_Bulbs`, lit at night) with a cat asleep in a bed on top, a gold
    star that turns on the left post (`_Star_Spin`) and a pom-pom toy that swings under the right platform
    (`_Toy_Swing`). The board's front face is the child Model `_NameBoard` for the cafe's name; the painted CAT CAFE
    on it is the child Model `_NameText`, which the UI hides when it writes the real name."""
    name = "CatCafe_Lawn_CatTreeSign"
    b, bulbs, board, text, star, toy = RB(), RB(), RB(), RB(), RB(), RB()
    b.span((-1.7, 0, -0.9), (1.7, 0.35, 0.9), "pastel_lilac")
    b.span((-1.73, 0, -0.93), (1.73, 0.08, 0.93), "blush")
    for px_ in (-1.2, -0.75, -0.3):                                                    # paw prints on the base
        b.cyl((px_, 0.18, -0.905), 0.07, 0.02, "offwhite", axis="Z", segments=8)
        for dx, dy in ((-0.07, 0.09), (0.0, 0.12), (0.07, 0.09)):
            b.cyl((px_ + dx, 0.18 + dy - 0.01, -0.905), 0.03, 0.02, "offwhite", axis="Z", segments=6)
    for x, top in ((-1.2, 6.0), (1.2, 5.6)):
        b.cyl((x, (0.3 + top) / 2, 0.1), 0.22, top - 0.3, "treat_tan", segments=10)
        for y in [0.8 + 1.0 * k for k in range(int(top - 1))]:
            if 3.45 < y < 5.15:
                continue
            b.cyl((x, y, 0.1), 0.235, 0.06, "kibble", segments=10)
        b.cyl((x, top + 0.05, 0.1), 0.42, 0.12, "pastel_lilac", segments=12)
        _ring_flat(b, (x, top + 0.05, 0.1), 0.44, 0.06, 0.14, "blush", segments=12)
    b.cyl((-1.2, 2.25, 0.1), 0.55, 0.12, "pastel_lilac", segments=12)
    _ring_flat(b, (-1.2, 2.25, 0.1), 0.57, 0.06, 0.14, "blush", segments=12)
    b.cyl((1.2, 3.0, 0.1), 0.5, 0.12, "pastel_lilac", segments=12)
    _ring_flat(b, (1.2, 3.0, 0.1), 0.52, 0.06, 0.14, "blush", segments=12)
    b.span((-1.48, 3.5, -0.1), (1.48, 5.1, 0.15), "dark_wood")
    board.span((-1.3, 3.66, -0.16), (1.3, 4.94, -0.08), "cream")
    px = 2.1 / text_width("CAT CAFE", 1.0)
    _Local(text, (0, 0, 0), Matrix.Identity(3)).text("CAT CAFE", 1.05, 4.3 - 2.5 * px, px, -0.155, -0.18,
                                                     "galaxy_blue")
    for k in range(12):                                                                # marquee bulbs on the frame
        x = -1.39 + 2.78 * k / 11
        for y in (3.58, 5.02):
            bulbs.span((x - 0.05, y - 0.05, -0.14), (x + 0.05, y + 0.05, -0.08), "lamp_warm")
    for k in range(1, 4):
        y = 3.58 + 1.44 * k / 4
        for x in (-1.39, 1.39):
            bulbs.span((x - 0.05, y - 0.05, -0.14), (x + 0.05, y + 0.05, -0.08), "lamp_warm")
    b.cyl((0, 5.22, 0.02), 0.62, 0.25, "mint", segments=12)                            # the bed and its sleeper
    _ring_flat(b, (0, 5.36, 0.02), 0.64, 0.14, 0.14, "blush", segments=12)
    b.ball((0.05, 5.42, 0.05), 0.4, "fur_orange", scale=(1.2, 0.55, 1.0))
    b.ball((-0.32, 5.5, -0.15), 0.2, "fur_orange")
    for dx in (-0.12, 0.12):
        b.b.pyramid(RB.p(-0.32 + dx, 5.6, -0.15), 0.1, 0.12, "fur_orange")
        b.span((-0.32 + dx - 0.05, 5.52, -0.315), (-0.32 + dx + 0.03, 5.54, -0.295), "fur_black")
    _arc(b, 0.05, 5.42, -0.3, 0.34, 200, 330, 4, 0.09, 0.09, "fur_orange_dark")
    b.cyl((-1.2, 6.33, 0.1), 0.03, 0.5, "gold_mid", segments=6)
    star.b.star(RB.p(-1.2, 6.62, 0.1), 0.35, 0.15, 0.12, "gold_mid", rot=(math.radians(90), "X"))
    hx, hy, hz = 1.42, 2.94, -0.3
    toy.span((hx - 0.012, hy - 0.62, hz - 0.012), (hx + 0.012, hy + 0.02, hz + 0.012), "cream")
    toy.ball((hx, hy - 0.72, hz), 0.12, "neon_pink")
    return [b.finalize(name, mat), bulbs.finalize(name + "_Bulbs", mat),
            board.finalize(name + "_NameBoard", mat), text.finalize(name + "_NameText", mat),
            _hang(star, name + "_Star_Spin", mat, (-1.2, 6.36, 0.1)),
            _hang(toy, name + "_Toy_Swing", mat, (hx, hy, hz))]


def build_golden_paw_statue(mat):
    """Tier 5 big: a big gold paw with pink beans raised on a gold-trimmed marble plinth with a plaque, uplights in
    the step's corners (`_Bulbs`, lit at night). The paw, its arm and the turntable are the child Model `_Paw_Spin`,
    pivot on the plinth's top centre (it turns slowly and VFX makes it glint)."""
    name = "CatCafe_Lawn_GoldenPawStatue"
    b, bulbs, spin = RB(), RB(), RB()
    b.span((-1.5, 0, -1.5), (1.5, 0.3, 1.5), "paving_light")
    b.span((-1.2, 0.28, -1.2), (1.2, 0.6, 1.2), "offwhite")
    b.span((-0.75, 0.58, -0.75), (0.75, 2.2, 0.75), "offwhite")
    b.span((-0.8, 0.6, -0.8), (0.8, 0.72, 0.8), "gold_mid")
    b.span((-0.85, 2.15, -0.85), (0.85, 2.3, 0.85), "gold_mid")
    b.span((-0.8, 2.29, -0.8), (0.8, 2.36, 0.8), "offwhite")
    b.span((-0.45, 1.15, -0.78), (0.45, 1.75, -0.74), "gold_mid")
    b.cyl((0, 1.38, -0.79), 0.12, 0.02, "gold_dark", axis="Z", segments=8)
    for dx, dy in ((-0.13, 1.52), (-0.05, 1.58), (0.05, 1.58), (0.13, 1.52)):
        b.cyl((dx, dy, -0.79), 0.04, 0.02, "gold_dark", axis="Z", segments=6)
    for sx in (-1, 1):                                                                 # laurel either side
        for k in range(4):
            b.box((sx * (0.55 + 0.03 * k), 1.2 + 0.15 * k, -0.77), (0.1, 0.16, 0.03), "gold_light",
                  rot=rot_z(-sx * (20 + 10 * k)))
    for sx in (-1, 1):
        for sz in (-1, 1):
            x, z = sx * 1.32, sz * 1.32
            b.span((x - 0.11, 0.29, z - 0.11), (x + 0.11, 0.36, z + 0.11), "fur_black")
            bulbs.span((x - 0.08, 0.36, z - 0.08), (x + 0.08, 0.46, z + 0.08), "lamp_warm")
    spin.cyl((0, 2.415, 0), 0.6, 0.13, "gold_dark", segments=12)
    spin.cyl((0, 3.05, 0), 0.32, 1.2, "gold_mid", r2=0.42, segments=10)
    spin.cyl((0, 3.2, 0), 0.46, 0.14, "gold_light", segments=10)
    spin.ball((0, 4.25, 0), 1.0, "gold_mid", scale=(1.0, 0.95, 0.72))
    spin.ball((0, 4.0, -0.6), 0.38, "nose_pink", scale=(1.25, 1.0, 0.45))
    for x, y, z in ((-0.52, 4.62, -0.5), (0.52, 4.62, -0.5), (-0.19, 4.92, -0.44), (0.19, 4.92, -0.44)):
        spin.ball((x, y, z), 0.17, "nose_pink", scale=(1.0, 1.15, 0.5))
    return [b.finalize(name, mat), bulbs.finalize(name + "_Bulbs", mat),
            _hang(spin, name + "_Paw_Spin", mat, (0, 2.36, 0))]


# -- paths ---------------------------------------------------------------------------------------------------------
PX, PZ = 3.5, 2.5                         # half the path's width and depth


def _landing(b, sw):
    """The stone under the door mat at the door end, so the mat (on the shell) keeps its ground."""
    b.span((-2.4, -0.08, 0.1), (2.4, 0.025, 2.45), sw)


def build_path_grey_slabs(mat):
    """Path style, free and the default: big grey slabs in a running bond on grout, kerbs along both sides."""
    name = "CatCafe_Lawn_Path_GreySlabs"
    b = RB()
    b.span((-PX + 0.02, -0.2, -PZ + 0.02), (PX - 0.02, 0.0, PZ - 0.02), "paving_grout")
    rows = 4
    dz = 2 * PZ / rows
    for r in range(rows):
        z0, z1 = -PZ + r * dz + 0.04, -PZ + (r + 1) * dz - 0.04
        edges = [-3.25, -1.1, 1.1, 3.25] if r % 2 == 0 else [-3.25, -2.15, 0.0, 2.15, 3.25]
        for k, (x0, x1) in enumerate(zip(edges, edges[1:])):
            b.span((x0 + 0.04, -0.05, z0), (x1 - 0.04, 0.035, z1), "fur_silver" if (r + k) % 3 else "fur_pewter")
    for sx in (-1, 1):
        b.span((sx * 3.27, -0.05, -PZ), (sx * PX, 0.06, PZ), "concrete")
    return [b.finalize(name, mat)]


def build_path_red_brick(mat):
    """Path style, Tier 1: red bricks in a running bond across the path with a soldier course along each side."""
    name = "CatCafe_Lawn_Path_RedBrick"
    b = RB()
    b.span((-PX + 0.02, -0.2, -PZ + 0.02), (PX - 0.02, 0.0, PZ - 0.02), "paving_grout")
    rows, L = 8, 1.1
    dz = 2 * PZ / rows
    cols = ("brick", "nose_brick", "brick", "fur_copper", "brick")
    n = 0
    for r in range(rows):
        z0, z1 = -PZ + r * dz + 0.03, -PZ + (r + 1) * dz - 0.03
        x = -3.0 - (L / 2 if r % 2 else 0)
        while x < 3.0:
            x0, x1 = max(x, -3.0), min(x + L, 3.0)
            if x1 - x0 > 0.2:
                b.span((x0 + 0.03, -0.05, z0), (x1 - 0.03, 0.035, z1), cols[n % 5])
                n += 1
            x += L
    for sx in (-1, 1):
        for k in range(9):
            z0 = -PZ + k * 5.0 / 9
            b.span((sx * 3.03, -0.05, z0 + 0.03), (sx * 3.47, 0.05, z0 + 5.0 / 9 - 0.03), cols[(k + 1) % 5])
    return [b.finalize(name, mat)]


def build_path_stepping_stones(mat):
    """Path style, Tier 2: rounded stepping stones zig-zagging through the grass to a flagstone landing at the door,
    pebbles and moss between them (the grass shows through)."""
    name = "CatCafe_Lawn_Path_SteppingStones"
    b = RB()
    _landing(b, "paving_tan")
    for x0, x1, z0, z1 in ((-2.3, -0.1, 0.2, 1.25), (0.0, 2.3, 0.2, 1.1), (-2.3, 0.6, 1.35, 2.35),
                           (0.7, 2.3, 1.2, 2.35)):
        b.span((x0, 0.02, z0), (x1, 0.04, z1), "paving_sand")
    stones = ((-0.55, -2.05, 0.62, "paving_light", 200), (0.5, -1.3, 0.6, "fur_silver", -20),
              (-0.45, -0.55, 0.58, "paving_sand", 160))
    for x, z, r, sw, lobe in stones:                      # each stone a round with a lobe, so no two look alike
        b.cyl((x, -0.025, z), r, 0.11, sw, segments=9)
        a = math.radians(lobe)
        b.cyl((x + 0.45 * r * math.cos(a), -0.03, z + 0.45 * r * math.sin(a)), 0.65 * r, 0.11, sw, segments=8)
        b.cyl((x + 0.05, 0.04, z - 0.03), r * 0.7, 0.02, "paving_light" if sw != "paving_light" else "fur_silver",
              segments=9)
    for k, (x, z, r, _, _) in enumerate(stones):                     # pebbles and moss tucked against each stone
        for j, a in enumerate((200 + 40 * k, 330 - 50 * k)):
            rp = 0.09 + 0.02 * ((k + j) % 3)
            c, s = math.cos(math.radians(a)), math.sin(math.radians(a))
            b.ball((x + (r + 0.06) * c, -0.08 + 0.7 * rp, z + (r + 0.06) * s), rp,
                   ("fur_silver", "paving_tan", "concrete")[(k + j) % 3], scale=(1.2, 0.7, 1.0))
        a = math.radians(100 + 70 * k)
        mx, mz = x + (r + 0.08) * math.cos(a), z + (r + 0.08) * math.sin(a)
        b.span((mx - 0.15, -0.08, mz - 0.1), (mx + 0.15, 0.06, mz + 0.1), "leaf_dark")
    return [b.finalize(name, mat)]


def _paw(b, x, z, s, sw, y=0.035, turn=0):
    t = math.radians(turn)
    b.cyl((x, y, z), 0.3 * s, 0.02, sw, segments=8)
    for k, (dx, dz) in enumerate(((-0.27, 0.3), (-0.1, 0.42), (0.1, 0.42), (0.27, 0.3))):
        rx, rz = dx * math.cos(t) - dz * math.sin(t), dx * math.sin(t) + dz * math.cos(t)
        b.cyl((x + rx * s, y, z + rz * s), 0.1 * s, 0.02, sw, segments=6)


def build_path_paw_print(mat):
    """Path style, Tier 3: sand flagstones with a blush border, inlaid with a trail of paw prints walking up to the
    door, left and right, in rose and cream."""
    name = "CatCafe_Lawn_Path_PawPrintPath"
    b = RB()
    b.span((-PX + 0.02, -0.2, -PZ + 0.02), (PX - 0.02, 0.0, PZ - 0.02), "paving_tan")
    for r in range(4):
        z0, z1 = -PZ + r * 1.25 + 0.03, -PZ + (r + 1) * 1.25 - 0.03
        for k, (x0, x1) in enumerate(((-2.95, -0.02), (0.02, 2.95))):
            b.span((x0 + 0.03, -0.05, z0), (x1 - 0.03, 0.025, z1), "paving_sand")
    for sx in (-1, 1):
        b.span((sx * 2.98, -0.05, -PZ), (sx * 3.22, 0.045, PZ), "blush")
        b.span((sx * 3.24, -0.05, -PZ), (sx * PX, 0.03, PZ), "paving_light")
    for k, z in enumerate((-2.0, -1.2, -0.4, 0.4, 1.2, 2.0)):
        x = -0.6 if k % 2 == 0 else 0.6
        _paw(b, x, z, 0.9, "fur_bubblegum" if k % 2 == 0 else "offwhite", y=0.03, turn=-8 if k % 2 == 0 else 8)
    return [b.finalize(name, mat)]


# -- fences --------------------------------------------------------------------------------------------------------
GAP, END = 3.9, 19.0                       # the fence runs from the path's gap to the plot's edge, each side


def _halves():
    return ((-END, -GAP), (GAP, END))


def build_fence_white_picket(mat):
    """Fence style, Tier 1: a white picket fence with pointed pickets, two rails and posts with ball caps, a taller
    post either side of the path."""
    name = "CatCafe_Lawn_Fence_WhitePicket"
    b = RB()
    for x0, x1 in _halves():
        n = int(round((x1 - x0) / 0.7))
        for k in range(n + 1):
            x = x0 + (x1 - x0) * k / n
            if k % 5 == 0:
                tall = 1.75 if (k == 0 and x0 > 0) or (k == n and x1 < 0) else 1.55
                b.span((x - 0.12, 0, -0.12), (x + 0.12, tall, 0.12), "offwhite")
                b.ball((x, tall + 0.08, 0), 0.12, "offwhite")
                continue
            b.span((x - 0.09, 0, -0.04), (x + 0.09, 1.2, 0.04), "offwhite")
            b.box((x, 1.2, 0), (0.127, 0.127, 0.075), "offwhite", rot=rot_z(45))
        for y in (0.4, 0.95):
            b.span((x0, y - 0.06, 0.035), (x1, y + 0.06, 0.11), "cream")
    return [b.finalize(name, mat)]


def build_fence_low_hedge(mat):
    """Fence style, Tier 2: a clipped box hedge with a softened top, rounded ends at the path and the corners, and
    small white and pink flowers in it."""
    name = "CatCafe_Lawn_Fence_LowHedge"
    b = RB()
    for x0, x1 in _halves():
        a, c = x0 + 0.4, x1 - 0.4
        b.span((a, 0, -0.4), (c, 0.95, 0.4), "leaf_dark")
        b.box(((a + c) / 2, 0.95, 0), (c - a, 0.5, 0.5), "leaf_green", rot=rot_x(45))
        for x in (a, c):
            b.cyl((x, 0.55, 0), 0.4, 1.1, "leaf_green", segments=10)
        nb = int((c - a) / 1.6)
        for j in range(nb):                                 # soft bumps along the clipped top
            x = a + 0.8 + j * (c - a - 1.6) / max(nb - 1, 1)
            b.box((x, 1.08, 0.04 * (j % 3 - 1)), (0.5, 0.45, 0.5), "leaf_green", rot=rot_y(30 + 17 * j) @ rot_x(20))
        k = 0
        x = a + 0.5
        while x < c - 0.3:
            y = 0.35 + 0.25 * ((k * 7) % 3)
            b.span((x - 0.06, y - 0.06, -0.42), (x + 0.06, y + 0.06, -0.37), ("offwhite", "blush")[k % 2])
            x += 0.9
            k += 1
    return [b.finalize(name, mat)]


def build_fence_iron_railing(mat):
    """Fence style, Tier 3: a black wrought iron railing on a low stone kerb, bars with gold spear tips, square posts
    with gold balls and a scroll at each end by the path."""
    name = "CatCafe_Lawn_Fence_IronRailing"
    b = RB()
    for x0, x1 in _halves():
        b.span((x0, 0, -0.22), (x1, 0.2, 0.22), "paving_tan")
        np_ = 5
        for k in range(np_ + 1):
            x = x0 + (x1 - x0) * k / np_
            b.span((x - 0.11, 0.19, -0.11), (x + 0.11, 1.75, 0.11), "fur_black")
            b.span((x - 0.14, 1.72, -0.14), (x + 0.14, 1.8, 0.14), "fur_black")
            b.ball((x, 1.9, 0), 0.1, "gold_mid")
        n = int(round((x1 - x0) / 0.5))
        for k in range(n + 1):
            x = x0 + (x1 - x0) * k / n
            if k % (n // np_) == 0:
                continue
            b.span((x - 0.03, 0.19, -0.03), (x + 0.03, 1.5, 0.03), "fur_black")
            b.b.pyramid(RB.p(x, 1.49, 0), 0.1, 0.16, "gold_mid")
        for y in (0.38, 1.32):
            b.span((x0, y - 0.04, -0.045), (x1, y + 0.04, 0.045), "fur_black")
        xe, s = (x1, -1) if x1 < 0 else (x0, 1)
        _arc(b, xe + s * 0.35, 1.32, 0, 0.25, 0 if s > 0 else 180, -150 if s > 0 else 330, 5, 0.05, 0.05,
             "fur_black")
    return [b.finalize(name, mat)]


def build_fence_flower_box(mat):
    """Fence style, Tier 4: cream flower boxes with mint trim between short posts, overflowing with blooms in six
    colours (`_Flowers`, which butterflies visit)."""
    name = "CatCafe_Lawn_Fence_FlowerBoxFence"
    b, fl = RB(), RB()
    for x0, x1 in _halves():
        nb = 4
        L = (x1 - x0) / nb
        for k in range(nb + 1):
            x = x0 + L * k
            b.span((x - 0.15, 0, -0.35), (x + 0.15, 1.05, 0.35), "mint")
            b.span((x - 0.18, 1.03, -0.38), (x + 0.18, 1.1, 0.38), "offwhite")
        for k in range(nb):
            a, c = x0 + L * k + 0.12, x0 + L * (k + 1) - 0.12
            b.span((a, 0, -0.3), (c, 0.7, 0.3), "cream")
            b.span((a + 0.02, 0.62, -0.32), (c - 0.02, 0.7, 0.32), "mint")
            b.span((a + 0.05, 0.05, -0.25), (c - 0.05, 0.74, 0.25), "choco")
            b.span((a + 0.08, 0.68, -0.24), (c - 0.08, 0.92, 0.24), "leaf_green")
            n = 7
            for j in range(n):
                x = a + 0.25 + j * (c - a - 0.5) / max(n - 1, 1)
                fl.span((x - 0.2, 0.88 + 0.03 * (j % 2), -0.26), (x - 0.02, 1.06 + 0.03 * (j % 2), -0.08),
                        BLOOMS[(j + k) % 6])
                fl.span((x + 0.0, 0.9, -0.02), (x + 0.18, 1.08, 0.16), BLOOMS[(j + k + 3) % 6])
    return [b.finalize(name, mat), fl.finalize(name + "_Flowers", mat)]


SMALL, BIG = 800, 1500
ASSETS = {
    "CatCafe_Lawn_TulipBed": (build_tulip_bed, SMALL),
    "CatCafe_Lawn_SandwichBoard": (build_sandwich_board, SMALL),
    "CatCafe_Lawn_PottedCatTopiary": (build_potted_cat_topiary, SMALL),
    "CatCafe_Lawn_Mailbox": (build_mailbox, SMALL),
    "CatCafe_Lawn_LampPost": (build_lamp_post, SMALL),
    "CatCafe_Lawn_BirdBath": (build_bird_bath, SMALL),
    "CatCafe_Lawn_GardenGnomeCat": (build_garden_gnome_cat, SMALL),
    "CatCafe_Lawn_BalloonBunch": (build_balloon_bunch, 1200),
    "CatCafe_Lawn_BicycleWithBasket": (build_bicycle_with_basket, BIG),
    "CatCafe_Lawn_GardenBench": (build_garden_bench, BIG),
    "CatCafe_Lawn_UmbrellaTable": (build_umbrella_table, BIG),
    "CatCafe_Lawn_LittleFountain": (build_little_fountain, BIG),
    "CatCafe_Lawn_FairyLightArch": (build_fairy_light_arch, 2500),
    "CatCafe_Lawn_FlowerCart": (build_flower_cart, 2500),
    "CatCafe_Lawn_CatTreeSign": (build_cat_tree_sign, 2500),
    "CatCafe_Lawn_GoldenPawStatue": (build_golden_paw_statue, 2500),
    "CatCafe_Lawn_Path_GreySlabs": (build_path_grey_slabs, 1000),
    "CatCafe_Lawn_Path_RedBrick": (build_path_red_brick, 1000),
    "CatCafe_Lawn_Path_SteppingStones": (build_path_stepping_stones, 1000),
    "CatCafe_Lawn_Path_PawPrintPath": (build_path_paw_print, 1000),
    "CatCafe_Lawn_Fence_WhitePicket": (build_fence_white_picket, 2400),
    "CatCafe_Lawn_Fence_LowHedge": (build_fence_low_hedge, 2400),
    "CatCafe_Lawn_Fence_IronRailing": (build_fence_iron_railing, 2400),
    "CatCafe_Lawn_Fence_FlowerBoxFence": (build_fence_flower_box, 2400),
}
NEST = {"_Glow": "_Swing"}                 # a lantern's light rides its swing
SPOTS = {"CatCafe_Lawn_GardenBench": GARDEN_BENCH_SPOTS, "CatCafe_Lawn_UmbrellaTable": UMBRELLA_TABLE_SPOTS}
