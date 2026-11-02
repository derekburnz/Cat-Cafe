"""One extra at each camp from the Park on (F100, docs/design/cat-cafe/camp-extras.md): small models in the area's
theme, about the size of an Index Board, each with one moving touch for Animation-Engineer and VFX-Agent.

  CatCafe_Camp_Park_PicnicBasket       a red checked blanket with a wicker basket (lid half open, a cloth and a Money
                                       Potion peeking out), a teal thermos and a mug, sandwiches on a plate, an apple
                                       and a bowl of fish crackers. Attachment `Steam` on the thermos's mouth.
  CatCafe_Camp_Neighbourhood_YardSale  a folding table with a gingham cloth on a rug: two cardboard boxes with "40"
                                       tags and a gold fish on each (the two crates for golden fish), a lamp, books,
                                       a teapot and a cash tin. Beside it a hand-painted YARD SALE board hangs from a
                                       little frame: `_Sign_Swing`, pivot at the bar it hangs from (turn about Z).
  CatCafe_Camp_Woods_FishPond          a small pond in a ring of stones with lily pads, reeds and cattails, and a
                                       cat-sized jetty with a bucket of golden fish. `_Rod`: the rod in its holder on
                                       the jetty with its line and bobber, pivot at the rod's butt (the cast turns it
                                       about X). `_Fish`: an orange fish under the water, pivot at its middle, and an
                                       Attachment `FishJump` on the water above it. `_Water` is see-through glass.
  CatCafe_Camp_Sewer_LostFound         a battered wooden crate stencilled LOST AND / FOUND under a dripping pipe, a
                                       sock, an umbrella handle and a teddy's ear poking out under the lid, a list
                                       pinned to its side, a boot and a puddle. `_Lid`: pivot on the back hinge, so
                                       a rattle is a small turn about X. Attachment `Drip` at the pipe's mouth.

Every one: pivot at the base centre on the camp's ground, front -Z toward the camp, no turn, and an Attachment
`PromptAnchor` in front at 1.5 studs. Spots (area space, the camp sets as of F84, clear of every theme prop):
SPOTS below, beside the way out across from the Index Board.
"""

import math

from mathutils import Matrix, Vector

from cannon import frame_at
from common import RB
from icon_art import _glyphs
from plot import rot_x, rot_z

# area space (x, z) for Layout.camps[area].campExtra, from CatCafe_Camp_<Area>'s props
SPOTS = {"Park": (23.0, -65.5), "Neighbourhood": (26.0, -145.5), "Woods": (21.5, -125.0), "Sewer": (20.0, -94.5)}
DIGITS = {"4": ("101", "101", "111", "001", "001"), "0": ("111", "101", "101", "101", "111")}
ATTACHMENTS = {}        # asset -> [(name, Roblox point)]


def label(b, s, cx, y, z, px, depth, swatch):
    """Block letters centred on x = cx, bottom at y, on a face at depth z read from -Z."""
    cols = sum((len(DIGITS[c][0]) if c in DIGITS else 3) + 1 if c != " " else 2 for c in s) - 1
    w = cols * px
    _glyphs(b, s, (cx + w / 2, y, z), px, depth, swatch, (-1, 0, 0), (0, 1, 0), DIGITS)


def gold_fish(b, x, y, z, s=1.0, up=False):
    """A little gold fish, side on along X (head -X), or standing on its head when `up` (a tail out of a bucket)."""
    if up:
        b.span((x - 0.09 * s, y, z - 0.05 * s), (x + 0.09 * s, y + 0.34 * s, z + 0.05 * s), "gold_mid")
        b.span((x - 0.16 * s, y + 0.34 * s, z - 0.03 * s), (x + 0.16 * s, y + 0.46 * s, z + 0.03 * s), "gold_light")
        return
    b.span((x - 0.22 * s, y, z - 0.05 * s), (x + 0.12 * s, y + 0.18 * s, z + 0.05 * s), "gold_mid")
    b.span((x + 0.12 * s, y - 0.03 * s, z - 0.03 * s), (x + 0.24 * s, y + 0.21 * s, z + 0.03 * s), "gold_light")


def prompt(name, p=(0.0, 1.5, -2.0)):
    ATTACHMENTS.setdefault(name, []).append(("PromptAnchor", p))


# ------------------------------------------------------------------------------------------------ picnic --
def build_picnic(mat):
    name = "CatCafe_Camp_Park_PicnicBasket"
    b = RB()
    W, D = 4.4, 3.6
    b.span((-W / 2, 0, -D / 2), (W / 2, 0.04, D / 2), "offwhite")                             # the blanket
    nx, nz = 8, 6
    for i in range(nx):
        for j in range(nz):
            if (i + j) % 2 == 0:
                x0, z0 = -W / 2 + i * W / nx, -D / 2 + j * D / nz
                b.span((x0, 0.04, z0), (x0 + W / nx, 0.06, z0 + D / nz), "bowl_red")
    # the basket, lid half open, a cloth and a potion peeking out
    bx, bz, by = -0.9, 0.55, 0.06
    b.span((bx - 0.75, by, bz - 0.45), (bx + 0.75, by + 0.8, bz + 0.45), "caramel_wood")
    for y in (0.3, 0.58):
        b.span((bx - 0.78, by + y, bz - 0.48), (bx + 0.78, by + y + 0.08, bz + 0.48), "kibble")   # weave bands
    b.span((bx - 0.79, by + 0.8, bz - 0.49), (bx + 0.79, by + 0.88, bz + 0.49), "dark_wood")     # rim
    b.span((bx - 0.66, by + 0.88, bz - 0.36), (bx + 0.05, by + 0.98, bz + 0.36), "blush")        # the cloth
    b.span((bx, by + 0.88, bz - 0.49), (bx + 0.79, by + 0.95, bz + 0.49), "caramel_wood")       # closed half lid
    b.span((bx - 0.79, by + 0.88, bz + 0.42), (bx, by + 1.6, bz + 0.5), "caramel_wood")         # the open half
    for x in (bx - 0.55, bx + 0.55):                                                            # handle
        b.span((x - 0.04, by + 0.95, bz - 0.04), (x + 0.04, by + 1.45, bz + 0.04), "dark_wood")
    b.span((bx - 0.59, by + 1.45, bz - 0.04), (bx + 0.59, by + 1.53, bz + 0.04), "dark_wood")
    px, pz = bx - 0.35, bz - 0.05                                                               # the Money Potion
    b.cyl((px, by + 1.08, pz), 0.17, 0.32, "gold_light", segments=10)
    b.cyl((px, by + 1.31, pz), 0.07, 0.14, "glass", segments=8)
    b.cyl((px, by + 1.42, pz), 0.08, 0.08, "kibble", segments=8)
    # thermos and mug: steam from the thermos's mouth
    tx, tz = 1.35, 0.95
    b.cyl((tx, 0.06 + 0.42, tz), 0.22, 0.84, "sign_teal", segments=12)
    b.cyl((tx, 0.9 + 0.06, tz), 0.24, 0.12, "cream", segments=12)
    b.cyl((tx, 1.02 + 0.03, tz), 0.12, 0.06, "fur_black", segments=10)                           # its open mouth
    ATTACHMENTS.setdefault(name, []).append(("Steam", (tx, 1.08, tz)))
    b.cyl((1.85, 0.06 + 0.15, 0.45), 0.16, 0.3, "cream", segments=10)                            # mug
    b.cyl((1.85, 0.36 + 0.01, 0.45), 0.12, 0.02, "choco", segments=10)                           # tea in it
    b.span((2.01, 0.12, 0.42), (2.09, 0.3, 0.48), "cream")                                       # handle
    # plate of sandwiches, an apple, fish crackers
    b.cyl((0.55, 0.06 + 0.025, -0.65), 0.5, 0.05, "offwhite", segments=14)
    for k, (sx, sz) in enumerate(((0.35, -0.75), (0.75, -0.5))):
        y = 0.11 + k * 0.0
        b.span((sx - 0.22, y, sz - 0.2), (sx + 0.22, y + 0.08, sz + 0.2), "treat_tan")
        b.span((sx - 0.24, y + 0.08, sz - 0.22), (sx + 0.24, y + 0.12, sz + 0.22), "pastel_butter")   # cheese
        b.span((sx - 0.2, y + 0.12, sz - 0.18), (sx + 0.2, y + 0.15, sz + 0.18), "leaf_green")       # lettuce
        b.span((sx - 0.22, y + 0.15, sz - 0.2), (sx + 0.22, y + 0.23, sz + 0.2), "treat_tan")
    b.ball((-0.25, 0.06 + 0.17, -1.05), 0.17, "bowl_red")                                        # apple
    b.span((-0.27, 0.38, -1.07), (-0.23, 0.48, -1.03), "dark_wood")
    b.span((-0.23, 0.44, -1.06), (-0.12, 0.47, -1.04), "leaf_green")
    b.cyl((-1.45, 0.06 + 0.09, -0.85), 0.32, 0.18, "pastel_sky", segments=12)                    # cracker bowl
    for k in range(4):
        a = k * 1.6
        gold_fish(b, -1.45 + 0.13 * math.cos(a), 0.24 + 0.02 * k, -0.85 + 0.12 * math.sin(a), 0.6)
    prompt(name, (0.0, 1.5, -D / 2 - 0.4))
    return [b.finalize(name, mat)]


# ------------------------------------------------------------------------------------------------- yard sale --
def build_yard_sale(mat):
    name = "CatCafe_Camp_Neighbourhood_YardSale"
    b, sign = RB(), RB()
    b.span((-2.3, 0, -1.2), (2.0, 0.04, 1.0), "pastel_lilac")                                   # rug
    b.span((-2.2, 0.04, -1.1), (1.9, 0.06, 0.9), "blush")
    T, h = (-1.8, 1.5, -0.7, 0.7), 2.3                                                          # table top x0 x1 z0 z1
    x0, x1, z0, z1 = T
    b.span((x0, h, z0), (x1, h + 0.1, z1), "offwhite")
    leg = math.hypot(h, 1.1)
    for x in (x0 + 0.25, x1 - 0.25):                                                            # X legs at each end
        for s in (-1, 1):
            b.box((x + s * 0.06, h / 2 + 0.03, 0), (0.08, leg, 0.08), "metal",
                  rot=rot_x(s * math.degrees(math.atan2(1.1, h))))
        b.span((x - 0.16, 0.06, -0.62), (x + 0.16, 0.1, -0.48), "fur_black")                   # feet
        b.span((x - 0.16, 0.06, 0.48), (x + 0.16, 0.1, 0.62), "fur_black")
    # a gingham cloth over the front edge
    b.span((x0 + 0.1, h + 0.1, z0 - 0.02), (x1 - 0.1, h + 0.13, z1 - 0.3), "pastel_sky")
    b.span((x0 + 0.1, h - 0.45, z0 - 0.05), (x1 - 0.1, h + 0.13, z0 - 0.02), "pastel_sky")
    for k in range(9):
        cx = x0 + 0.3 + k * (x1 - x0 - 0.6) / 8
        b.span((cx - 0.09, h - 0.45, z0 - 0.07), (cx + 0.09, h + 0.1, z0 - 0.05), "offwhite")
    top = h + 0.13
    # the two boxes (the crates for golden fish) with their price tags
    for bxx in (-1.0, 0.4):
        b.span((bxx - 0.42, top, -0.35), (bxx + 0.42, top + 0.6, 0.35), "cardboard")
        b.span((bxx - 0.42, top + 0.6, -0.35), (bxx + 0.42, top + 0.62, -0.31), "kibble")       # tape
        b.box((bxx - 0.32, top + 0.75, -0.2), (0.3, 0.04, 0.5), "cardboard", rot=rot_z(-40))      # open flaps
        b.box((bxx + 0.32, top + 0.75, -0.2), (0.3, 0.04, 0.5), "cardboard", rot=rot_z(40))
        b.span((bxx - 0.3, top + 0.6, -0.25), (bxx + 0.3, top + 0.72, 0.25), "rarity_rare")       # a crate inside
        b.span((bxx - 0.32, top + 0.1, -0.41), (bxx + 0.32, top + 0.46, -0.37), "offwhite")       # tag
        label(b, "40", bxx - 0.12, top + 0.17, -0.41, 0.045, 0.02, "bowl_red")
        gold_fish(b, bxx + 0.18, top + 0.21, -0.43, 0.55)
    # a lamp, a stack of books, a teapot and a cash tin
    b.cyl((1.15, top + 0.04, 0.3), 0.18, 0.08, "brass", segments=10)
    b.span((1.12, top + 0.08, 0.27), (1.18, top + 0.6, 0.33), "brass")
    b.cyl((1.15, top + 0.75, 0.3), 0.3, 0.35, "pastel_butter", segments=10)
    for k, sw in enumerate(("shirt_blue", "bowl_red", "mint")):
        b.span((-1.65 + 0.03 * k, top + 0.12 * k, 0.15), (-1.15 - 0.02 * k, top + 0.12 * (k + 1), 0.55), sw)
    b.ball((1.0, top + 0.18, -0.35), 0.2, "pastel_lilac", scale=(1, 0.85, 1))                    # teapot
    b.span((1.17, top + 0.2, -0.38), (1.33, top + 0.26, -0.32), "pastel_lilac")
    b.span((0.75, top + 0.12, -0.37), (0.83, top + 0.3, -0.33), "pastel_lilac")
    b.span((0.95, top + 0.33, -0.4), (1.05, top + 0.4, -0.3), "offwhite")
    b.span((-0.5, top, 0.2), (-0.1, top + 0.18, 0.5), "metal")                                # cash tin
    # the hanging sign's frame, right of the table; the board swings from the bar
    fx, bar = 2.55, 2.55
    for z in (-0.35, 0.35):
        b.span((fx - 0.85, 0, z - 0.06), (fx - 0.73, bar + 0.12, z + 0.06), "dark_wood")
        b.span((fx + 0.73, 0, z - 0.06), (fx + 0.85, bar + 0.12, z + 0.06), "dark_wood")
    b.span((fx - 0.85, bar, -0.06), (fx + 0.85, bar + 0.12, 0.06), "dark_wood")                   # the bar
    for x in (fx - 0.85, fx + 0.73):                                                            # feet
        b.span((x, 0, -0.4), (x + 0.12, 0.08, 0.4), "dark_wood")
    # the board, in sign space: its origin at the middle of the bar's underside
    for x in (-0.45, 0.45):
        sign.span((x - 0.02, -0.35, -0.02), (x + 0.02, 0.0, 0.02), "offwhite")                  # strings
    sign.span((-0.66, -1.35, -0.04), (0.66, -0.35, 0.04), "cardboard")
    sign.span((-0.7, -1.39, -0.02), (0.7, -0.31, 0.02), "kibble")                               # its torn edge
    label(sign, "YARD", 0, -0.75, -0.04, 0.075, 0.02, "bowl_red")
    label(sign, "SALE", 0, -1.2, -0.04, 0.075, 0.02, "bowl_red")
    prompt(name, (-0.15, 1.5, -1.6))
    return [b.finalize(name, mat), sign.finalize(name + "_Sign_Swing", mat, location=(fx, bar, 0.0))]


# --------------------------------------------------------------------------------------------------- pond --
def build_fish_pond(mat):
    name = "CatCafe_Camp_Woods_FishPond"
    b, water, rod, fish = RB(), RB(), RB(), RB()
    A, C, cz = 2.6, 1.9, 0.5                                                                    # the pond's half axes
    b.ball((0, 0.1, cz), 1.0, "pants_navy", scale=(A, 0.06, C))                                 # its deep bottom
    water.ball((0, 0.22, cz), 1.0, "fish_blue", scale=(A - 0.05, 0.06, C - 0.05))
    stones = ("paving_grout", "fur_ash", "concrete", "fur_pewter")
    n = 16
    for k in range(n):
        a = 2 * math.pi * k / n
        if abs(a - 1.5 * math.pi) < 0.35:                                                       # the jetty's gap
            continue
        r = 0.52 + 0.07 * ((k * 7) % 3)
        b.ball(((A + 0.15) * math.cos(a), 0.12, cz + (C + 0.15) * math.sin(a)), r, stones[k % 4],
               scale=(1.0, 0.62, 0.9))
    for (lx, lz, r, flower) in ((-1.3, 0.9, 0.36, True), (-0.6, 1.5, 0.3, False), (1.4, 1.2, 0.34, False)):
        b.cyl((lx, 0.29, cz + lz - 0.5), r, 0.03, "leaf_green", segments=10)                     # lily pads
        b.span((lx + 0.1 - 0.025, 0.08, cz + lz - 0.5 - 0.025), (lx + 0.1 + 0.025, 0.28, cz + lz - 0.5 + 0.025),
               "leaf_dark")                                                                    # on stems
        if flower:
            b.span((lx - 0.08, 0.3, cz + lz - 0.58), (lx + 0.08, 0.42, cz + lz - 0.42), "nose_pink")
            b.span((lx - 0.04, 0.42, cz + lz - 0.54), (lx + 0.04, 0.47, cz + lz - 0.46), "pastel_butter")
    for k, (rx, rz, h) in enumerate(((-2.2, 1.7, 1.5), (-1.9, 2.0, 1.2), (-1.55, 2.15, 1.6), (-2.45, 1.25, 1.1),
                                     (1.9, 1.95, 1.3), (2.25, 1.6, 1.0))):
        s = math.hypot(rx / (A + 0.15), rz / (C + 0.15))                                      # rooted in the stones
        rx, rz = rx / s, rz / s
        b.span((rx - 0.04, 0.0, cz + rz - 0.04), (rx + 0.04, 0.2 + h, cz + rz + 0.04), "leaf_dark")     # reeds
        if k % 2 == 0:
            b.span((rx - 0.07, 0.2 + h - 0.35, cz + rz - 0.07), (rx + 0.07, 0.2 + h - 0.05, cz + rz + 0.07), "choco")
    # the jetty: planks on two stringers and four posts, from the bank out over the water
    jz0, jz1, jy = -2.7, -0.2, 0.5
    for x in (-0.45, 0.45):
        b.span((x - 0.07, jy - 0.16, jz0), (x + 0.07, jy, jz1), "dark_wood")
        for z in (jz0 + 0.2, jz1 - 0.2):
            b.span((x - 0.09, 0.0, z - 0.09), (x + 0.09, jy - 0.16, z + 0.09), "dark_wood")
    k, z = 0, jz0
    while z + 0.34 <= jz1 + 1e-6:
        b.span((-0.62, jy, z), (0.62, jy + 0.09, z + 0.34), "caramel_wood" if k % 2 else "kibble")
        z += 0.36
        k += 1
    # a bucket of golden fish on the jetty
    b.cyl((-0.3, jy + 0.09 + 0.18, jz0 + 0.45), 0.24, 0.36, "metal", segments=12)
    b.cyl((-0.3, jy + 0.09 + 0.3675, jz0 + 0.45), 0.2, 0.015, "fish_blue", segments=12)
    gold_fish(b, -0.36, jy + 0.47, jz0 + 0.42, 0.9, up=True)
    gold_fish(b, -0.22, jy + 0.44, jz0 + 0.52, 0.8, up=True)
    # the rod holder on the jetty's end, the rod in it (pivot at its butt), its line and bobber
    hx, hz = 0.45, jz1 - 0.35
    b.span((hx - 0.08, jy + 0.09, hz - 0.08), (hx + 0.08, jy + 0.5, hz + 0.08), "dark_wood")
    butt = (hx, jy + 0.5, hz)
    L, ang = 2.6, 50.0
    dy, dz = L * math.cos(math.radians(ang)), L * math.sin(math.radians(ang))
    rod.box((0, dy / 2, dz / 2), (0.06, L, 0.06), "fur_black", rot=rot_x(ang))
    rod.box((0, 0.235 * math.cos(math.radians(ang)), 0.235 * math.sin(math.radians(ang))), (0.1, 0.53, 0.1), "kibble",
            rot=rot_x(ang))                                                                   # cork grip
    rod.cyl((0.08, 0.6 * math.cos(math.radians(ang)), 0.6 * math.sin(math.radians(ang))), 0.09, 0.08, "metal",
            axis="X", segments=10)                                                             # reel
    by = 0.3 - butt[1]
    rod.span((-0.012, by, dz - 0.012), (0.012, dy, dz + 0.012), "offwhite")                     # the line
    rod.ball((0.0, by, dz), 0.07, "bowl_red")                                                  # bobber
    # an orange fish under the water, and where it jumps
    fx, fz = -1.0, cz + 0.1
    fish.span((-0.22, -0.06, -0.07), (0.16, 0.06, 0.07), "fur_orange")
    fish.span((0.16, -0.09, -0.03), (0.3, 0.09, 0.03), "fur_orange_dark")
    ATTACHMENTS.setdefault(name, []).append(("FishJump", (fx, 0.3, fz)))
    prompt(name, (0.0, 1.5, jz0 - 0.5))
    return [b.finalize(name, mat), water.finalize(name + "_Water", mat),
            rod.finalize(name + "_Rod", mat, location=butt),
            fish.finalize(name + "_Fish", mat, location=(fx, 0.16, fz))]


# ----------------------------------------------------------------------------------------------- lost and found --
def build_lost_found(mat):
    name = "CatCafe_Camp_Sewer_LostFound"
    b, lid = RB(), RB()
    W, H, D = 2.6, 1.4, 1.6
    b.span((-W / 2, 0, -D / 2), (W / 2, H, D / 2), "kibble")                                    # the crate
    for x in (-W / 2, W / 2 - 0.16):                                                            # corner posts
        for z in (-D / 2 - 0.03, D / 2 - 0.13):
            b.span((x - 0.02, -0.02, z), (x + 0.18, H + 0.02, z + 0.16), "dark_wood")
    for y in (0.0, H - 0.16):                                                                   # top and bottom bands
        b.span((-W / 2 + 0.16, y, -D / 2 - 0.03), (W / 2 - 0.16, y + 0.16, -D / 2), "caramel_wood")
        b.span((-W / 2 + 0.16, y, D / 2), (W / 2 - 0.16, y + 0.16, D / 2 + 0.03), "caramel_wood")
    label(b, "LOST AND", 0, 0.78, -D / 2, 0.06, 0.02, "offwhite")                               # stencil
    label(b, "FOUND", 0, 0.38, -D / 2, 0.06, 0.02, "offwhite")
    b.span((-0.95, 0.22, -D / 2 - 0.02), (-0.6, 0.3, -D / 2), "rust")                            # a scrape
    b.span((W / 2, 0.35, -0.45), (W / 2 + 0.02, 1.05, 0.25), "offwhite")                         # the list on its side
    for k in range(5):
        b.span((W / 2 + 0.02, 0.48 + 0.11 * k, -0.38), (W / 2 + 0.03, 0.52 + 0.11 * k, 0.1 - 0.06 * (k % 2)),
               "fur_charcoal")
    b.span((W / 2 + 0.02, 0.98, -0.12), (W / 2 + 0.05, 1.03, -0.07), "bowl_red")                 # its pin
    # things poking out under the lid at the front: a striped sock, an umbrella's hook, a teddy's ear
    for k in range(4):
        b.span((-1.1, H - 0.12 - 0.15 * k, -D / 2 - 0.08), (-0.92, H + 0.03 - 0.15 * k, -D / 2 - 0.03),
               "bowl_red" if k % 2 == 0 else "offwhite")
    b.span((0.35, H, -D / 2 + 0.1), (0.45, H + 0.42, -D / 2 + 0.2), "fur_black")                  # umbrella hook
    b.span((0.45, H + 0.32, -D / 2 + 0.1), (0.7, H + 0.42, -D / 2 + 0.2), "fur_black")
    b.span((0.62, H + 0.18, -D / 2 + 0.1), (0.7, H + 0.32, -D / 2 + 0.2), "fur_black")
    b.ball((-0.05, H + 0.08, -D / 2 + 0.3), 0.16, "fur_caramel")                                 # teddy's ear
    # the lid, ajar: in lid space, its origin on the back hinge, tipped up 7 degrees at the front
    t = math.radians(7)
    lid.box((0, 0.06 + 0.83 * math.sin(t), -0.83 * math.cos(t)), (W + 0.1, 0.12, D + 0.06), "caramel_wood",
            rot=rot_x(7))
    for x in (-0.8, 0.0, 0.8):
        lid.box((x, 0.13 + 0.83 * math.sin(t), -0.83 * math.cos(t)), (0.12, 0.04, D + 0.02), "dark_wood",
                rot=rot_x(7))
    lid.box((0.75, 0.155 + 0.55 * math.sin(t), -0.55 * math.cos(t)), (0.5, 0.01, 0.4), "puddle", rot=rot_x(7))
    # the dripping pipe behind: a standpipe with a valve, an elbow and its mouth over the lid
    px, pz, top = 0.75, D / 2 + 0.55, 3.4
    b.span((px - 0.45, 0, pz - 0.45), (px + 0.45, 0.12, pz + 0.45), "concrete")                  # base
    b.cyl((px, 0.12 + (top - 0.12) / 2, pz), 0.24, top - 0.12, "metal", segments=12)
    for y in (0.6, 2.3):
        b.cyl((px, y, pz), 0.29, 0.14, "rust", segments=12)                                       # rusty collars
    b.cyl((px, 1.55, pz - 0.3), 0.08, 0.12, "metal", axis="Z", segments=8)                        # valve stem
    b.cyl((px, 1.55, pz - 0.38), 0.3, 0.06, "bowl_red", axis="Z", segments=12)                    # valve wheel
    b.ball((px, top, pz), 0.3, "metal")                                                         # elbow
    mz, low = 0.25, top - 0.75                                                                  # over the lid
    b.cyl((px, top, (pz + mz) / 2), 0.24, pz - mz, "metal", axis="Z", segments=12)
    b.ball((px, top, mz), 0.3, "metal")                                                         # elbow down
    b.cyl((px, (top + low) / 2, mz), 0.24, top - low, "metal", segments=12)
    b.cyl((px, low + 0.04, mz), 0.3, 0.12, "rust", segments=12)                                  # flange
    b.cyl((px, low - 0.025, mz), 0.17, 0.01, "fur_black", segments=10)                           # the open mouth
    ATTACHMENTS.setdefault(name, []).append(("Drip", (px, low - 0.08, mz)))
    for (mx, mz2) in ((px - 0.4, pz + 0.3), (px + 0.35, pz - 0.35)):
        b.span((mx - 0.15, 0.12, mz2 - 0.12), (mx + 0.15, 0.2, mz2 + 0.12), "fur_moss")
    # a lost boot and a puddle
    b.span((-1.9, 0, -0.5), (-1.6, 0.7, -0.15), "choco")
    b.span((-2.15, 0, -0.5), (-1.6, 0.22, -0.15), "choco")
    b.span((-1.92, 0.6, -0.52), (-1.58, 0.72, -0.13), "dark_wood")
    b.span((0.9, 0, -1.35), (1.9, 0.02, -0.7), "puddle")
    prompt(name, (0.0, 1.5, -1.8))
    return [b.finalize(name, mat), lid.finalize(name + "_Lid", mat, location=(0.0, H, D / 2))]


def rbx_attachments(name):
    return [(name, n, frame_at(Vector(p), Matrix.Identity(3))) for n, p in ATTACHMENTS.get(name, [])]


ASSETS = {
    "CatCafe_Camp_Park_PicnicBasket": (build_picnic, 3000),
    "CatCafe_Camp_Neighbourhood_YardSale": (build_yard_sale, 3000),
    "CatCafe_Camp_Woods_FishPond": (build_fish_pond, 3000),
    "CatCafe_Camp_Sewer_LostFound": (build_lost_found, 3000),
}
