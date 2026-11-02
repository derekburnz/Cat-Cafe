"""The hometown's welcome arches (F84, hometown-cannon.md section 2: "a 'Cat Cafe Town' welcome arch over the street
end with a garden backdrop behind it"). One model serves both street ends (Layout.townEnds, WorldBuilder buildArch).

  CatCafe_Town_WelcomeArch   a 36 stud opening over the street and both sidewalks between two brick towers with
                             teal roofs, lit windows and paw medallions; a cream arch between them with bulbs along
                             its top; a teal name board hung under it (CAT CAFE TOWN toward the square, WELCOME TO CAT
                             CAFE TOWN on the outer face); a big ginger cat peeking over the top with its paws over the
                             edge and its tail down the back; and a garden bed across the street's end (brick kerb,
                             a clipped hedge, flowers and potted topiary balls), so the street ends in a garden and not
                             at the town's end hedge.
    _Lamp_Bulb, _Bulbs       the lanterns and the bulbs along the arch, the tower windows: lit at night.
    _Flowers                 the hanging baskets and the bed's flowers (butterflies).

Pivot at the opening's base centre on the street's top (world y 0.1), front -Z toward the Town Square. WorldBuilder
places it at (0, -123) turned 180 and (0, 123) unturned, one stud in from each street end, and the town's end hedge
stands 2.5 to 3.5 behind the pivot, so nothing here reaches past local z 2.3 or in front of z -2.6. The grass beside
the street is 0.1 below the pivot; the towers stand on it, outside the sidewalks (|x| 16 to 18).
"""

from alleyway import bar, flower_clump, label, lantern
from common import RB
from plot import rot_z

N = "CatCafe_Town_WelcomeArch"
HALF = 18.0                 # the opening's half width: the street (16) and a sidewalk (2)
TW = 4.0                    # a tower's width
TD = 1.9                    # a tower's half depth
GROUND = -0.1               # the grass beside the street
TOP = 15.0                  # the towers' brick top, under the cornice
SPRING, RISE, T = 12.6, 4.0, 1.0      # the arch's centreline springs at y 12.6 and rises 4; the arch is 1 thick
BOARD = (12.5, 8.6, 13.0)   # the name board's half width, bottom and top
BED = (-0.8, 2.3)           # the garden bed's front and back (z)


def arch_y(x):
    """The arch's centreline height at x."""
    return SPRING + RISE * (1 - (x / HALF) ** 2)


def tower(b, lamps, bulbs, flowers, s):
    """One tower, its inner face on x = s * HALF."""
    x0, x1 = sorted((s * HALF, s * (HALF + TW)))
    cx = (x0 + x1) / 2
    b.span((x0 - 0.3, GROUND - 0.2, -TD - 0.3), (x1 + 0.3, 1.4, TD + 0.3), "concrete")          # plinth
    b.span((x0, 1.4, -TD), (x1, TOP, TD), "brick")
    for y in (5.0, 10.0):                                                                     # cream bands
        b.span((x0 - 0.12, y, -TD - 0.12), (x1 + 0.12, y + 0.45, TD + 0.12), "cream")
    b.span((x0 - 0.3, TOP, -TD - 0.3), (x1 + 0.3, TOP + 0.6, TD + 0.3), "cream")              # cornice
    b.ball((cx, TOP + 1.0, 0), 1.85, "sign_teal", scale=(1, 1.15, 1))                         # dome, sunk to its waist
    b.span((cx - 0.08, TOP + 3.0, -0.08), (cx + 0.08, TOP + 3.9, 0.08), "gold_mid")             # spire
    b.ball((cx, TOP + 3.95, 0), 0.32, "gold_mid")                                             # finial
    for f in (-1, 1):                                                                         # front and back faces
        zf = f * TD
        o = lambda d: (zf, zf + f * d) if f > 0 else (zf + f * d, zf)  # noqa: E731  (a layer d proud of the face)
        g0, g1 = o(0.06)
        bulbs.span((cx - 0.8, 11.0, g0), (cx + 0.8, 13.0, g1), "lamp_warm")                  # lit window
        w0, w1 = o(0.14)
        b.span((cx - 1.0, 10.8, w0), (cx + 1.0, 11.0, w1), "cream")                           # sill
        b.span((cx - 1.0, 13.0, w0), (cx + 1.0, 13.25, w1), "cream")                          # head
        for xx in (cx - 1.0, cx + 0.8):
            b.span((xx, 11.0, w0), (xx + 0.2, 13.0, w1), "cream")                             # jambs
        m0, m1 = o(0.1)
        b.span((cx - 0.06, 11.0, m0), (cx + 0.06, 13.0, m1), "fur_black")                     # glazing bars
        b.span((cx - 0.8, 11.94, m0), (cx + 0.8, 12.06, m1), "fur_black")
        d0, d1 = o(0.12)
        b.cyl((cx, 7.5, (d0 + d1) / 2), 1.15, 0.12, "sign_teal", axis="Z", segments=14)       # paw medallion
        p0, p1 = (d1, d1 + 0.05) if f > 0 else (d0 - 0.05, d0)
        for (dx, dy, r) in ((0, -0.2, 0.36), (-0.5, 0.33, 0.16), (-0.17, 0.55, 0.16), (0.17, 0.55, 0.15),
                            (0.5, 0.33, 0.15)):
            b.span((cx + dx - r, 7.5 + dy - r, p0), (cx + dx + r, 7.5 + dy + r, p1), "gold_mid")
    # inner face: a lantern on a bracket and a hanging basket under the arch
    xi = s * HALF
    b.span((min(xi, s * (HALF - 0.9)), 6.3, -0.12), (max(xi, s * (HALF - 0.9)), 6.5, 0.12), "fur_black")
    lantern(b, lamps, s * (HALF - 0.5), 6.5, 0, 0.8)
    bx = s * (HALF - 1.6)
    b.span((min(xi, bx - 0.04), 9.25, -0.08), (max(xi, bx + 0.04), 9.4, 0.08), "fur_black")
    b.span((bx - 0.04, 8.5, -0.04), (bx + 0.04, 9.25, 0.04), "fur_black")
    b.cyl((bx, 8.15, 0), 0.6, 0.6, "terracotta", r2=0.75, segments=10)
    flowers.span((bx - 0.6, 8.45, -0.6), (bx + 0.6, 8.6, 0.6), "leaf_green")
    flower_clump(flowers, bx, 8.6, 0, n=5, spread=0.55)
    for dz in (-0.45, 0.45):
        b.span((bx - 0.15, 7.0, dz - 0.15), (bx + 0.15, 7.85, dz + 0.15), "leaf_dark")       # trailing ivy


def arch(b, bulbs):
    """The cream arch from tower to tower, a terracotta edge along its top and bulbs on it."""
    n = 16
    pts = [(-HALF + 2 * HALF * k / n, arch_y(-HALF + 2 * HALF * k / n)) for k in range(n + 1)]
    for p0, p1 in zip(pts, pts[1:]):
        bar(b, p0, p1, T, -1.1, 1.1, "cream")
        bar(b, (p0[0], p0[1] + T / 2 + 0.17), (p1[0], p1[1] + T / 2 + 0.17), 0.34, -1.16, 1.16, "terracotta")
    for x, y in pts[1:-1]:
        if abs(x) < 3.5 or 2.0 < x < 6.5:                                                     # the cat and its tail
            continue
        top = y + T / 2 + 0.34
        bulbs.span((x - 0.2, top - 0.05, -0.2), (x + 0.2, top + 0.4, 0.2), "lamp_warm")


def board(b, bulbs):
    """The teal name board under the arch on two chains, a terracotta frame and bulbs round it."""
    w, y0, y1 = BOARD
    b.span((-w, y0, -0.3), (w, y1, 0.3), "sign_teal")
    for (xa, xb, ya, yb) in ((-w - 0.25, w + 0.25, y0 - 0.05, y0 + 0.25), (-w - 0.25, w + 0.25, y1 - 0.25, y1 + 0.05),
                             (-w - 0.25, -w + 0.05, y0 + 0.25, y1 - 0.25), (w - 0.05, w + 0.25, y0 + 0.25, y1 - 0.25)):
        b.span((xa, ya, -0.38), (xb, yb, 0.38), "terracotta")
    for x in (-w + 2.0, w - 2.0):                                                             # chains into the arch
        b.span((x - 0.07, y1 + 0.05, -0.07), (x + 0.07, arch_y(x) - T / 2 + 0.15, 0.07), "fur_black")
    for k in range(9):                                                                        # bulbs along the bottom
        x = -w + 1.4 + k * (2 * w - 2.8) / 8
        bulbs.span((x - 0.17, y0 - 0.39, -0.17), (x + 0.17, y0 - 0.05, 0.17), "lamp_warm")
    # toward the square (-Z): CAT CAFE TOWN between two paws; the outer face: WELCOME TO over CAT CAFE TOWN
    label(b, "CAT CAFE TOWN", 0, 9.8, -0.3, 0.4, 0.08, "cream", -1)
    for s in (-1, 1):
        _paw(b, s * 10.9, 10.8, -0.3, -1)
    label(b, "WELCOME TO", 0, 11.35, 0.3, 0.25, 0.07, "pastel_butter", 1)
    label(b, "CAT CAFE TOWN", 0, 9.3, 0.3, 0.36, 0.08, "cream", 1)


def _paw(b, x, y, z, facing):
    """A cream paw print on the board's face at depth z."""
    z0, z1 = (z - 0.06, z) if facing < 0 else (z, z + 0.06)
    for (dx, dy, r) in ((0, -0.25, 0.42), (-0.55, 0.35, 0.18), (-0.19, 0.6, 0.18), (0.19, 0.6, 0.17),
                        (0.55, 0.35, 0.17)):
        b.span((x + dx - r, y + dy - r, z0), (x + dx + r, y + dy + r, z1), "pastel_butter")


def peeking_cat(b):
    """A big ginger cat behind the arch's top, its head over it and its front paws hooked over the front edge; its
    tail hangs down the back. Blocky like the game's cats: closed W mouth, black eyes with a shine, pink nose."""
    top = arch_y(0) + T / 2 + 0.34                                                            # the arch's top edge
    hy0, hy1, hz0, hz1 = top - 0.7, top + 3.6, -0.9, 0.9
    b.span((-2.6, hy0, hz0), (2.6, hy1, hz1), "fur_ginger")                                   # head
    b.span((-2.9, hy0 + 0.25, hz0 + 0.15), (2.9, hy0 + 1.7, hz1 - 0.15), "fur_ginger")         # cheeks
    for s in (-1, 1):
        ex = s * 1.7
        b.box((ex, hy1 - 0.1, 0), (1.5, 1.5, 1.0), "fur_ginger", rot=rot_z(45))               # ears
        b.box((ex, hy1 - 0.05, -0.53), (0.85, 0.85, 0.08), "nose_pink", rot=rot_z(45))        # inner ears
        b.span((ex - 0.42 + s * -0.2, hy0 + 1.85, hz0 - 0.06), (ex + 0.42 + s * -0.2, hy0 + 2.85, hz0), "fur_black")
        b.span((ex - 0.25 + s * -0.2, hy0 + 2.45, hz0 - 0.1), (ex + 0.0 + s * -0.2, hy0 + 2.7, hz0 - 0.06),
               "offwhite")                                                                    # eye shine
        b.span((s * 2.0 - 0.3, hy0 + 1.25, hz0 - 0.04), (s * 2.0 + 0.3, hy0 + 1.5, hz0), "nose_pink")   # blush
        for k, wy in enumerate((1.0, 1.35)):                                                  # whiskers
            b.span((s * 2.2 - 0.6, hy0 + wy - 0.05, hz0 - 0.08), (s * 2.2 + 0.6, hy0 + wy + 0.05, hz0 + 0.06),
                   "offwhite")
        # front paws over the arch's front edge, white toes
        px = s * 1.25
        b.span((px - 0.6, top - 1.0, -1.7), (px + 0.6, top + 0.25, -0.7), "fur_ginger")
        for k in (-1, 0, 1):
            b.span((px + k * 0.38 - 0.15, top - 1.0, -1.78), (px + k * 0.38 + 0.15, top - 0.6, -1.7), "offwhite")
    b.span((-1.1, hy0 + 0.35, hz0 - 0.08), (1.1, hy0 + 1.55, hz0), "offwhite")                 # muzzle
    b.span((-0.35, hy0 + 1.35, hz0 - 0.16), (0.35, hy0 + 1.75, hz0 - 0.08), "nose_pink")         # nose
    for k, x in enumerate((-0.75, -0.25, 0.25, 0.75)):                                        # W mouth
        yy = hy0 + (0.7 if k in (0, 2) else 0.88)
        b.span((x - 0.2, yy, hz0 - 0.14), (x + 0.2, yy + 0.2, hz0 - 0.08), "fur_black")
    for x in (-0.5, 0.0, 0.5):                                                                # tabby marks
        b.span((x - 0.12, hy1 - 0.9, hz0 - 0.04), (x + 0.12, hy1 - 0.1, hz0), "fur_russet")
    for y in (hy1 - 0.8, hy1 - 1.6):                                                          # and on the back
        b.span((-2.0, y - 0.15, hz1), (2.0, y + 0.15, hz1 + 0.04), "fur_russet")
    # the tail along the arch's top behind the head, its tip curling up
    for k, (xa, xb) in enumerate(((2.4, 3.6), (3.5, 4.7), (4.6, 5.8))):
        y = arch_y((xa + xb) / 2) + T / 2 + 0.34
        b.span((xa, y - 0.1, 0.05), (xb, y + 0.55, 0.75), "fur_russet" if k == 1 else "fur_ginger")
    yt = arch_y(5.2) + T / 2 + 0.34
    b.span((5.15, yt + 0.45, 0.05), (5.8, yt + 1.5, 0.75), "fur_ginger")
    b.span((5.15, yt + 1.5, 0.05), (5.8, yt + 2.0, 0.75), "offwhite")                          # white tip


def garden_bed(b, flowers):
    """Across the street's end, between the towers: a brick kerb round grass, a clipped box hedge along the back,
    flowers in front and four topiary balls in terracotta pots."""
    z0, z1 = BED
    x = HALF - 0.1
    b.span((-x, GROUND - 0.2, z0), (x, 0.55, z1), "brick")                                    # kerb all round
    b.span((-x + 0.35, 0.55, z0 + 0.35), (x - 0.35, 0.6, z1 - 0.35), "leaf_green")              # grass top
    b.span((-x + 0.35, 0.6, z1 - 1.3), (x - 0.35, 1.7, z1 - 0.4), "leaf_dark")                 # clipped hedge
    for k in range(17):
        fx = -x + 1.4 + k * (2 * x - 2.8) / 16
        if abs(fx) < 1.2:
            continue
        cols = (("blush", "sparkle", "offwhite", "nose_pink"), ("pastel_sky", "offwhite", "pastel_butter", "blush"))
        flower_clump(flowers, fx, 0.6, z0 + 0.95, colours=cols[k % 2], n=4, spread=0.45)
    tulips = ("bowl_red", "pastel_butter", "nose_pink", "sparkle")
    for k in range(20):                                                                       # tulips by the hedge
        fx = -x + 1.0 + k * (2 * x - 2.0) / 19
        if min(abs(fx - px) for px in (-12.0, -4.0, 0.0, 4.0, 12.0)) < 1.1:
            continue
        fz = z1 - 1.55 + 0.12 * (k % 3)
        h = 0.7 + 0.12 * (k % 4)
        flowers.span((fx - 0.04, 0.6, fz - 0.04), (fx + 0.04, 0.6 + h, fz + 0.04), "leaf_green")
        flowers.span((fx - 0.16, 0.6 + h, fz - 0.16), (fx + 0.16, 0.6 + h + 0.34, fz + 0.16), tulips[k % 4])
    for px in (-12.0, -4.0, 4.0, 12.0):
        b.cyl((px, 0.6 + 0.5, z0 + 1.55), 0.55, 1.0, "terracotta", r2=0.7, segments=10)
        b.ball((px, 0.6 + 1.0 + 0.75, z0 + 1.55), 0.85, "leaf_dark")
    # a little sign in the middle of the bed, toward the square: a paw on a post
    b.span((-0.08, 0.6, z0 + 0.95), (0.08, 1.5, z0 + 1.11), "dark_wood")
    b.span((-0.55, 1.5, z0 + 0.9), (0.55, 2.3, z0 + 1.16), "dark_wood")
    _paw_small(b, 0, 1.9, z0 + 0.9)


def _paw_small(b, x, y, z):
    for (dx, dy, r) in ((0, -0.08, 0.16), (-0.22, 0.15, 0.07), (-0.08, 0.25, 0.07), (0.08, 0.25, 0.065),
                        (0.22, 0.15, 0.065)):
        b.span((x + dx - r, y + dy - r, z - 0.04), (x + dx + r, y + dy + r, z), "cream")


def build(mat):
    b, lamps, bulbs, flowers = RB(), RB(), RB(), RB()
    for s in (-1, 1):
        tower(b, lamps, bulbs, flowers, s)
    arch(b, bulbs)
    board(b, bulbs)
    peeking_cat(b)
    garden_bed(b, flowers)
    return [b.finalize(N, mat), flowers.finalize(N + "_Flowers", mat), lamps.finalize(N + "_Lamp_Bulb", mat),
            bulbs.finalize(N + "_Bulbs", mat)]


ASSETS = {N: (build, 8000)}
