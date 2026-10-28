"""The Neighbourhood set for town layout v3.2 (town-layout-v3.md section 8, F81): 280 x 280 of streets behind the
Neighbourhood gate.

  CatCafe_Neighbourhood_SetV32   the whole area dressed, in area space (areakit): place it at the area's v3.2 centre
                                 on its floor, unturned, like the v3.1 set. The gate is at z -140. A new name, so the
                                 live game keeps CatCafe_Neighbourhood_Set (v3.1, 140 x 140) until Gameplay moves the
                                 Neighbourhood to its v3.2 Config and switches the set name in the same change.

The way in (8b): Whisker Lane runs north from the gate into a street of house blocks with fenced front gardens. Two
blocks of houses cross the whole width, each with one gap, on alternating sides: the lane turns east along the first
block's front to its gap (x 41 to 51), north through it, west along the second street between the blocks to the
second block's gap (x -51 to -41), and north through that past the village green to the playground hub. A crescent
cul-de-sac loops round the hub, with the corner shop at its far end, the back gardens behind its west houses and the
allotments behind its east houses, each reached by a footpath between two of its houses. Walked on a 0.5 stud grid
with a player 2 wide: about 340 studs gate to corner shop, 300 to 380 into the back gardens and 370 to 470 through the
allotments, against 280 straight.

The house blocks are the blockers: a 30 high `_Barrier` stands on each block from the house fronts back (the front
gardens stay open) and along the crescent's outer houses, open only at the two footpaths. Fences have cat-sized gaps
(a missing picket, a lifted board) but a player goes round. Every outer wall run has a 30 high `_Barrier` in its band
all round but the gate, as in the other v3.2 sets.

Points (manifest points_roblox): [x, y, z, zone], zone "near" (the gate half, z < 0) or "deep". The traps are built in
(as v3.1's shed was): `trap_shed` x2 (a garden shed with a jammed door, the door on the piece's -Z) and `trap_gutter`
x2 (a bungalow's front gutter, 7 up, with the downpipe at the house's corner; the cat lies in the gutter), one of each
near and one deep, each with the piece's turn as a fifth number.

Positions are area space in Roblox numbers (x across, z from the gate at -140 to the far wall at +140); bl() turns
them into Builder (Blender) axes. Pieces from the v3.1 kit (neighbourhood.py) and the Park set are reused.
"""

import math

from mathutils import Matrix

import neighbourhood as nb
import parkset as pk
from areakit import PI, Set, flowers, gable, rx, rz, tree_round, turned, window
from common import RB, Builder, text_width
from furniture import build_bench

N = "CatCafe_Neighbourhood_"
SET = N + "SetV32"
HALF = 140.0                         # WorldBuilder's walls at +-140
WALL_D = 2.4                         # the set's walls: inner face at IN, back against WorldBuilder's
IN = HALF - 0.5 - WALL_D             # 137.1
OUT = IN + WALL_D                    # 139.5
GATE_HALF = 23.0                     # the gate model is 44.6 wide, centred on the lane
BARRIER_H = 30.0
ROAD_Y, PAVE_Y, PATH_Y, DRIVE_Y = 0.24, 0.34, 0.3, 0.29       # slab tops; front lawns are the area floor
HD, PD = nb.HOUSE_D, nb.PORCH_D      # a house is 10 deep with a 4 deep porch
FRONT = HD / 2 + 7.5                 # a house's centre to its front fence
PLOT = 26.0                          # house plots along a row (a house is 20 wide)

S1_Z, S3_Z = -112.0, -46.0           # the two streets across (road centre lines)
S1_END, S3_END = 92.0, 100.0         # their dead ends, each with a turning head
G1_X, G2_X = 46.0, -46.0             # the gaps through the blocks, on alternating sides
ROW1 = (-104.0, -54.0)               # the first block: front fences on S1 and S3, houses back to back
ROW2 = (-38.0, -4.0)                 # the second block: houses on S3, back gardens to z -4
R1W, R1E = (-IN, 30.0), (62.0, IN)   # the blocks either side of each gap
R2W, R2E = (-IN, -62.0), (-30.0, IN)
H = (-14.0, 70.0)                    # the hub's centre; the crescent road loops round it
CR = 32.0                            # the crescent road's centre line radius (road 27 to 37)
EL_X, TURN_C, TURN_R = 18.0, (18.0, 40.0), 9.0     # the crescent's east leg and its turning circle
W_LINE, E_LINE = -62.1, 34.1         # the back gardens' and allotments' street-side boundaries
W_TWITTEN = (20.0, 36.0)             # the footpath from the west leg into the back gardens
CRESCENT = [(160.0, "house", "A2"), (124.0, "house", "C3"), (90.0, "shop", None), (56.0, "bungalow", "D2"),
            (20.0, "house", "B")]
TWITTENS = (142.0, 38.0)             # the footpaths off the crescent: to the back gardens, to the allotments

COLOURS = {                          # wall, roof, trim for each house variant (layout from its letter)
    "A": ("blush", "pants_navy", "offwhite"), "A2": ("pastel_sky", "dark_wood", "offwhite"),
    "A3": ("fur_peach", "pants_navy", "offwhite"),
    "B": ("mint", "dark_wood", "offwhite"), "B2": ("pastel_lilac", "pants_navy", "offwhite"),
    "B3": ("cream", "terracotta", "offwhite"),
    "C": ("pastel_butter", "terracotta", "offwhite"), "C2": ("blush", "dark_wood", "offwhite"),
    "C3": ("mint", "terracotta", "offwhite"),
    "D": ("pastel_sky", "terracotta", "offwhite"), "D2": ("pastel_butter", "pants_navy", "offwhite"),
}


def bl(x, z, h=0.0):
    """Area (Roblox x, z) to Builder coordinates (Blender x is Roblox -x)."""
    return (-x, z, h)


def face(x, z, tx, tz):
    """rot_y that turns a piece at (x, z) to face (tx, tz)."""
    return math.degrees(math.atan2(-(tx - x), -(tz - z)))


def polar(r, deg, c=H):
    a = math.radians(deg)
    return c[0] + r * math.cos(a), c[1] + r * math.sin(a)


def span(b, x0, x1, z0, z1, h0, h1, swatch, bevel=False):
    """An area-space box from Roblox x0..x1, z0..z1, height h0..h1."""
    b.box_base(bl((x0 + x1) / 2, (z0 + z1) / 2, h0), (abs(x1 - x0), abs(z1 - z0), h1 - h0), swatch, bevel=bevel)


def seg(b, p0, p1, w, h0, h1, swatch):
    """An area-space box along the line p0 -> p1, w thick, height h0..h1."""
    (ax, ay, _), (bx, by, _) = bl(*p0), bl(*p1)
    L = math.hypot(bx - ax, by - ay)
    b.box_base(((ax + bx) / 2, (ay + by) / 2, h0), (L, w, h1 - h0), swatch, bevel=False,
               rot=(math.atan2(by - ay, bx - ax), "Z"))


def _rect_minus(r, h):
    """Rect r minus rect h (both (x0, x1, z0, z1)) as up to four rects."""
    x0, x1, z0, z1 = r
    a0, a1, b0, b1 = h
    if a1 <= x0 or a0 >= x1 or b1 <= z0 or b0 >= z1:
        return [r]
    out = []
    if b0 > z0:
        out.append((x0, x1, z0, b0))
    if b1 < z1:
        out.append((x0, x1, b1, z1))
    lo, hi = max(z0, b0), min(z1, b1)
    if a0 > x0:
        out.append((x0, a0, lo, hi))
    if a1 < x1:
        out.append((a1, x1, lo, hi))
    return out


def rects_minus(rects, holes):
    for h in holes:
        rects = [p for r in rects for p in _rect_minus(r, h)]
    return [r for r in rects if r[1] - r[0] > 0.05 and r[3] - r[2] > 0.05]


# ---------------------------------------------------------------- houses -----
def house(variant, mat):
    """A v3.1 two-storey house front (A, B or C layout) in the variant's colours. Returns (objs, door_x), door_x
    in Blender local x as nb.house gives it."""
    letter = variant[0]
    old = nb.NB_WALLS[letter]
    nb.NB_WALLS[letter] = COLOURS[variant]
    try:
        return nb.house(letter, mat)
    finally:
        nb.NB_WALLS[letter] = old


GUTTER_Z = 7.05                      # the bungalow gutter's floor, where a stuck cat lies
GUTTER_SPOT = (-7.6, -6.0)           # Roblox local (x, z) of the stuck cat in the gutter, by the downpipe


def bungalow(mat, variant="D"):
    """A single-storey house, the DrainpipeGutter trap (areas-and-stations.md: `gutter`, a cat stuck in a roof gutter;
    hits shake the drainpipe): a side-gable roof whose front eave carries a deep gutter, and a downpipe down the
    house's right-hand front corner (seen from the street; Roblox local -X) to a shoe over a gully. 20 wide and 10 deep
    like the two-storey houses, so it takes their plots; the door is in the middle under a canopy."""
    wall, roof, trim = COLOURS[variant]
    b, panes, lamp = Builder(), Builder(), Builder()
    W, D, Hh, rise, over, thick = 20.0, HD, 7.6, 4.2, 0.7, 0.4
    fy = -D / 2
    b.box_base((0, 0, 0), (W + 0.4, D + 0.4, 0.8), "concrete")                             # foundation
    b.box_base((0, 0, 0.8), (W, D, Hh - 0.8), wall)
    for sx in (-1, 1):
        b.box_base((sx * (W / 2 + 0.05), fy + 0.2, 0.79), (0.4, 0.5, Hh - 0.8), trim, bevel=False)
    # side-gable roof, ridge along x: the gable prism in the wall colour, a slab each side, a ridge cap
    R = Matrix(((0, 0, 1), (1, 0, 0), (0, 1, 0)))                                          # local x -> y, y -> z
    b.fan((0, 0, Hh), (0, rise), [(-D / 2, 0), (D / 2, 0)], W, wall, rot=R)
    a = math.atan2(rise, D / 2)
    L = math.hypot(D / 2, rise) + over
    for sy in (-1, 1):
        cy = sy * D / 4 + sy * math.cos(a) * over / 2 + sy * math.sin(a) * thick / 2
        cz = Hh + rise / 2 - math.sin(a) * over / 2 + math.cos(a) * thick / 2
        b.box((0, cy, cz), (W + 2 * over, L, thick), roof, rot=rx(-sy * math.degrees(a)))
    b.box((0, 0, Hh + rise + 0.2), (W + 2 * over, 0.5, 0.35), roof, bevel=False)
    b.box_base((6.0, 1.5, Hh + 1.8), (1.6, 1.6, 4.4), "brick")                              # chimney
    b.box_base((6.0, 1.5, Hh + 6.2), (1.9, 1.9, 0.3), "concrete", bevel=False)
    # the fascia under the eave and the gutter on it: a channel 1 wide, ends capped, open on top
    b.box((0, fy - 0.12, Hh - 0.25), (W + 0.6, 0.24, 0.5), trim, bevel=False)
    gy, gl = fy - 0.95, W + 1.0
    b.box_base((0, gy, GUTTER_Z - 0.15), (gl, 1.0, 0.15), "metal", bevel=False)            # floor
    b.box_base((0, gy - 0.44, GUTTER_Z), (gl, 0.12, 0.55), "metal", bevel=False)           # front lip
    b.box_base((0, gy + 0.44, GUTTER_Z), (gl, 0.12, 0.4), "metal", bevel=False)            # back lip
    for sx in (-1, 1):
        b.box_base((sx * (gl / 2 - 0.06), gy, GUTTER_Z), (0.12, 0.76, 0.5), "metal", bevel=False)   # end caps
    for x in (-6.0, 0.0, 6.0):
        b.box((x, fy - 0.3, GUTTER_Z - 0.3), (0.2, 0.6, 0.15), "fur_charcoal", bevel=False)  # brackets
    # the downpipe at Blender +x (Roblox local -x), from the gutter down to a shoe over the gully
    px = W / 2 - 0.4
    b.box_base((px, gy, 0.55), (0.45, 0.45, GUTTER_Z - 0.7), "metal", bevel=False)
    b.box((px, gy - 0.25, 0.45), (0.45, 0.8, 0.3), "metal", bevel=False, rot=rx(-25))       # the shoe
    b.box_base((px, gy - 0.3, 0.0), (1.1, 1.1, 0.12), "fur_charcoal", bevel=False)        # the gully grate
    for z in (2.4, 4.8):
        b.box((px, gy + 0.32, z), (0.6, 0.2, 0.15), "fur_charcoal", bevel=False)            # pipe clips
    # front: two wide windows either side of the door, a canopy on brackets, one step
    for x in (-5.5, 5.5):
        window(b, panes, x, fy, 4.0, 4.4, 3.0)
    b.box_base((0, fy - 0.1, 0.8), (3.2, 0.3, 5.4), trim, bevel=False)                     # door frame
    b.box_base((0, fy - 0.22, 0.8), (2.6, 0.2, 4.9), "sign_teal" if variant == "D" else "shirt_red", bevel=False)
    b.box((0.9, fy - 0.42, 3.4), (0.25, 0.2, 0.25), "brass", bevel=False)
    b.box((0, fy - 0.9, 6.55), (4.4, 1.8, 0.25), roof, rot=rx(8))                           # canopy
    for sx in (-1, 1):
        b.box((sx * 1.9, fy - 0.4, 6.05), (0.2, 0.8, 0.6), trim, bevel=False)
    b.box_base((0, fy - 0.8, 0), (3.6, 1.2, 0.4), "concrete")                               # step
    lamp.box((-2.1, fy - 0.24, 5.6), (0.5, 0.5, 0.7), "lamp_warm", bevel=False)
    name = N + "Bungalow"
    return [b.finalize(name, mat), panes.finalize(name + "_Pane", mat), lamp.finalize(name + "_Bulb", mat)]


# ------------------------------------------------------------ boundaries -----
def front_fence(mat, kind, L, gap_bx, gap_w=3.8, cat_gap=True):
    """A front garden boundary L long along local x, on y 0, with a gap for the garden path at Blender x gap_bx:
    a white picket fence (one picket missing in each run, the cat's way in), a low brick wall with piers at the gap,
    or a clipped box hedge."""
    b = Builder()
    runs = [(-L / 2, gap_bx - gap_w / 2), (gap_bx + gap_w / 2, L / 2)]
    for k, (a0, a1) in enumerate(runs):
        a0, a1 = max(a0, -L / 2), min(a1, L / 2)
        rl = a1 - a0
        if rl < 0.6:
            continue
        c = (a0 + a1) / 2
        if kind == "picket":
            n = max(2, int(rl / 1.15) + 1)
            skip = 2 if cat_gap and n > 4 else -1
            for i in range(n):
                if i == skip:
                    continue
                x = a0 + 0.2 + i * (rl - 0.4) / (n - 1)
                b.box_base((x, 0, 0), (0.36, 0.36, 2.6), "offwhite", bevel=False)
            for z in (0.7, 1.9):                                       # rails, a hair into the pickets
                b.box((c, 0.23, z), (rl, 0.12, 0.25), "offwhite", bevel=False)
        elif kind == "wall":
            b.box_base((c, 0, 0), (rl, 0.8, 1.6), "brick", bevel=False)
            b.box_base((c, 0, 1.6), (rl + 0.1, 1.0, 0.2), "concrete", bevel=False)
        else:
            b.box_base((c, 0, 0), (rl, 1.4, 2.4), "leaf_dark", bevel=False)
            m = max(1, round(rl / 3.2))
            for i in range(m):
                b.ico((a0 + (i + 0.5) * rl / m, 0, 2.35), 0.85, "leaf_dark", subdivisions=1,
                      scale=(rl / m / 1.9, 0.85, 0.45))
    # gate posts either side of the gap
    for x in ((gap_bx - gap_w / 2 - 0.3, gap_bx + gap_w / 2 + 0.3) if gap_w > 0 else ()):
        if kind == "wall":
            b.box_base((x, 0, 0), (0.9, 0.9, 2.3), "brick", bevel=False)
            b.box_base((x, 0, 2.3), (1.1, 1.1, 0.25), "concrete", bevel=False)
        elif kind == "picket":
            b.box_base((x, 0.05, 0), (0.5, 0.5, 3.1), "offwhite", bevel=False)
    name = {"picket": "PicketFence", "wall": "GardenWall", "hedge": "BoxHedge"}[kind]
    return [b.finalize(N + name, mat)]


def side_fence(mat, L, h=6.5, gate=True):
    """A close-board fence L long (side gates between houses, the blocks' ends and backs): concrete posts, boards
    from 0.9 up (the gap under them is a cat's way through), a capping rail."""
    b = Builder()
    n = max(1, round(L / 6.0))
    for i in range(n + 1):
        x = -L / 2 + i * L / n
        b.box_base((x, 0, 0), (0.45, 0.45, h + 0.3), "concrete", bevel=False)
    for i in range(n):
        x0, x1 = -L / 2 + i * L / n + 0.23, -L / 2 + (i + 1) * L / n - 0.23
        sw = "dark_wood" if gate and n == 1 else "caramel_wood"
        b.box_base(((x0 + x1) / 2, 0, 0.9), (x1 - x0, 0.25, h - 0.9), sw, bevel=False)
    b.box_base((0, 0, h), (L + 0.1, 0.4, 0.15), "dark_wood", bevel=False)
    if gate and n == 1:
        b.box((L / 2 - 1.0, -0.2, 3.4), (0.15, 0.15, 0.6), "metal", bevel=False)           # the gate latch
    return [b.finalize(N + "SideFence", mat)]


def low_hedge(mat, L, h=2.2, d=1.2):
    """A low hedge between front gardens."""
    b = Builder()
    b.box_base((0, 0, 0), (L, d, h), "leaf_green", bevel=False)
    for i in range(max(1, round(L / 3.5))):
        m = max(1, round(L / 3.5))
        b.ico((-L / 2 + (i + 0.5) * L / m, 0, h - 0.05), 0.7, "leaf_green", subdivisions=1,
              scale=(L / m / 1.6, d / 1.3, 0.4))
    return [b.finalize(N + "LowHedge", mat)]


# ----------------------------------------------------------------- walls -----
def _seg_hedge(b, L, k):
    sw = ("leaf_dark", "leaf_green")[k % 2]
    b.box_base((0, WALL_D / 2, 0), (L, WALL_D, 9.4), sw, bevel=False)
    n = max(2, round(L / 3.6))
    for i in range(n):
        x = -L / 2 + (i + 0.5) * L / n
        b.ico((x, WALL_D / 2, 9.3 + 0.2 * (i % 2)), 1.6, sw, subdivisions=1, scale=(L / n / 2.9, 0.85, 0.5))


def _seg_brick(b, L, k):
    b.box_base((0, WALL_D / 2, 0), (L, WALL_D, 9.0), "brick", bevel=False)
    b.box_base((0, WALL_D / 2, 9.0), (L + 0.1, WALL_D + 0.3, 0.45), "concrete", bevel=False)     # coping
    b.box_base((0, WALL_D / 2 - 0.15, 0), (L + 0.02, WALL_D + 0.1, 1.0), "concrete_dark", bevel=False)  # plinth
    for x in (-L / 4, L / 4):                                                                    # piers
        b.box_base((x, -0.15, 1.0), (1.0, 0.3, 7.8), "brick", bevel=False)
    for i in range(2):                                                                            # ivy
        x = -L / 2 + L * (0.3 + 0.4 * i) + 0.6 * (k % 3)
        hh = 9.0 * (0.5 + 0.12 * ((k + i) % 3))
        b.ico((x, -0.05, hh / 2 + 0.3), 0.8, ("leaf_green", "leaf_dark")[(i + k) % 2], subdivisions=1,
              scale=(1.6, 0.35, hh / 1.7))


def _seg_fence(b, L, k):
    """A tall close-board fence on a brick plinth, a trellis band on top with climbing roses."""
    b.box_base((0, WALL_D / 2, 0), (L, WALL_D, 1.2), "brick", bevel=False)
    n = max(2, round(L / 6.0))
    for i in range(n + 1):
        x = -L / 2 + 0.25 + i * (L - 0.5) / n
        b.box_base((x, 0.4, 1.2), (0.5, 0.5, 8.0), "concrete", bevel=False)
    sw = ("caramel_wood", "dark_wood")[k % 2]
    b.box_base((0, 0.55, 1.2), (L - 0.2, 0.3, 6.4), sw, bevel=False)
    b.box_base((0, 0.6, 7.6), (L - 0.2, 0.2, 1.4), "caramel_wood", bevel=False)                   # trellis band
    b.box_base((0, 0.55, 9.0), (L + 0.1, 0.5, 0.22), "dark_wood", bevel=False)
    for i in range(max(1, round(L / 9.0))):                                                        # roses on it
        x = -L / 2 + (i + 0.5) * L / max(1, round(L / 9.0))
        b.ico((x, 0.35, 8.1), 1.1, "leaf_dark", subdivisions=1, scale=(1.4, 0.3, 0.7))


SEGMENTS = {"hedge": _seg_hedge, "brick": _seg_brick, "fence": _seg_fence}


def wall_segment(mat, kind, L, k=0):
    """One outer wall run L long along local x, its face at y 0 (facing -Y, into the area), its back at WALL_D."""
    b = Builder()
    SEGMENTS[kind](b, L, k)
    return [b.finalize(N + "Wall" + kind.capitalize(), mat)]


def pier(mat, h=10.4, w=1.8):
    b, bulb = Builder(), Builder()
    d = WALL_D + 0.2
    b.box_base((0, WALL_D / 2, 0), (w, d, h), "brick")
    b.box_base((0, WALL_D / 2, h), (w + 0.3, d + 0.3, 0.35), "concrete", bevel=False)
    b.box_base((0, WALL_D / 2, h + 0.35), (w - 0.6, d - 0.6, 0.5), "concrete", bevel=False)
    return [b.finalize(N + "Pier", mat)]


def _run(s, mat, kinds, n, length, place, seed):
    """n wall segments filling `length` with brick piers 1.8 wide between; place(t) -> (x, z, rot) at t along."""
    L = (length - (n - 1) * 1.8) / n
    for i in range(n):
        t = i * (L + 1.8) + L / 2
        s.put(wall_segment(mat, kinds[(i + seed) % len(kinds)], L, i + seed), *place(t))
        if i < n - 1:
            s.put(pier(mat), *place(t + L / 2 + 0.9))


def town_hedge(mat, L):
    """The town side (7d: see-through): a low hedge in blocks with gaps, as in v3.1."""
    b = Builder()
    n = max(1, round(L / 8.0))
    step = L / n
    b.box_base((0, WALL_D / 2, 0), (L, 2.0, 0.3), "brick", bevel=False)                     # the planter kerb
    for i in range(n):
        x = -L / 2 + (i + 0.5) * step
        b.box_base((x, WALL_D / 2, 0), (step - 1.6, 1.8, 3.0 + 0.3 * (i % 2)), ("leaf_green", "leaf_dark")[i % 2],
                   bevel=False)
    return [b.finalize(N + "TownHedge", mat)]


# ------------------------------------------------------------ street bits ----
def street_sign(mat, text):
    rb = RB()
    rb.box((0, 4.0, 0), (0.35, 8.0, 0.35), "metal")
    w = text_width(text, 0.17)
    rb.box((0, 7.0, -0.05), (w + 1.0, 1.4, 0.2), "shirt_green")
    rb.text(text, (w / 2, 6.58, -0.15), 0.17, 0.08, "offwhite", right=(-1, 0, 0), up=(0, 1, 0))
    rb.box((0, 8.2, -0.05), (0.5, 0.5, 0.5), "metal")
    return [rb.finalize(N + "StreetSign", mat)]


def fingerpost(mat, text):
    """A footpath sign: a post and one arm pointing along local -X (Roblox), the text on its -Z face."""
    rb = RB()
    rb.box((0, 3.5, 0), (0.35, 7.0, 0.35), "dark_wood")
    w = text_width(text, 0.15)
    rb.box((-(w / 2 + 0.6), 5.9, 0), (w + 1.4, 1.1, 0.22), "offwhite")
    rb.box((-(w + 1.45), 5.9, 0), (0.4, 0.75, 0.22), "offwhite", rot=Matrix.Rotation(PI / 4, 3, "Z"))  # the point
    rb.text(text, (-0.7, 5.53, -0.11), 0.15, 0.06, "dark_wood", right=(-1, 0, 0), up=(0, 1, 0))
    rb.box((0, 7.1, 0), (0.5, 0.25, 0.5), "dark_wood")
    return [rb.finalize(N + "Fingerpost", mat)]


def bus_stop(mat):
    """A bus shelter, open at the front (-Y): glass back and ends, a teal roof, a bench inside, a stop sign."""
    b, glass = Builder(), Builder()
    W, D = 8.0, 2.8
    for x in (-W / 2, W / 2):
        for y in (-D / 2 + 0.2, D / 2 - 0.2):
            b.box_base((x, y, 0), (0.25, 0.25, 6.6), "metal", bevel=False)
    b.box_base((0, 0.2, 6.6), (W + 0.8, D + 0.8, 0.35), "sign_teal")
    glass.box_base((0, D / 2 - 0.2, 0.4), (W - 0.3, 0.15, 5.8), "glass", bevel=False)
    for x in (-W / 2, W / 2):
        glass.box_base((x, 0.15, 0.4), (0.15, D - 0.9, 5.8), "glass", bevel=False)
    b.box_base((0, 0.6, 1.45), (W - 1.2, 0.9, 0.2), "caramel_wood", bevel=False)               # the bench
    for x in (-2.6, 2.6):
        b.box_base((x, 0.6, 0), (0.2, 0.6, 1.45), "metal", bevel=False)
    b.box((2.4, D / 2 - 0.305, 3.6), (1.6, 0.06, 2.2), "offwhite", bevel=False)                # timetable
    b.box_base((W / 2 + 1.2, -D / 2, 0), (0.22, 0.22, 7.6), "metal", bevel=False)              # stop sign
    b.cyl((W / 2 + 1.2, -D / 2, 7.9), 0.75, 0.15, "shirt_red", segments=12, rot=rx(90))
    b.cyl((W / 2 + 1.2, -D / 2, 7.9), 0.5, 0.18, "offwhite", segments=12, rot=rx(90))
    return [b.finalize(N + "BusStop", mat), glass.finalize(N + "BusStop_Glass", mat)]


BUS_SEAT = 1.65


def post_box(mat):
    b = Builder()
    b.cyl_base((0, 0, 0), 0.75, 0.3, "fur_black", segments=12)
    b.cyl_base((0, 0, 0.3), 0.65, 3.0, "bowl_red", segments=12)
    b.cyl_base((0, 0, 3.3), 0.78, 0.25, "bowl_red", segments=12, bevel=False)
    b.sphere((0, 0, 3.55), 0.62, "bowl_red", segments=12, rings=6, scale=(1, 1, 0.55))
    b.box((0, -0.62, 2.7), (0.7, 0.12, 0.16), "fur_black", bevel=False)                       # the slot
    b.box((0, -0.62, 1.9), (0.55, 0.06, 0.4), "offwhite", bevel=False)                         # collection plate
    return [b.finalize(N + "PostBox", mat)]


def car(mat, body="shirt_blue"):
    """A little hatchback 4.4 wide and 9 long, nose to -Y, standing on its wheels."""
    b, glass = Builder(), Builder()
    b.box_base((0, 0, 0.7), (4.4, 8.8, 2.1), body)
    b.box_base((0, 0.9, 2.8), (4.0, 5.0, 1.8), body)
    glass.box((0, -1.62, 3.65), (3.5, 0.12, 1.4), "glass", bevel=False)                       # windscreen
    glass.box((0, 3.42, 3.65), (3.3, 0.12, 1.3), "glass", bevel=False)                        # rear window
    for sx in (-1, 1):
        glass.box((sx * 2.02, 0.9, 3.7), (0.12, 4.4, 1.25), "glass", bevel=False)            # side windows
        for y in (-2.9, 2.9):
            b.cyl((sx * 1.9, y, 0.85), 0.85, 0.7, "fur_black", segments=12, rot=(PI / 2, "Y"))
            b.cyl((sx * 2.27, y, 0.85), 0.42, 0.06, "metal", segments=10, rot=(PI / 2, "Y"), bevel=False)
    for y, sw in ((-4.5, "metal"), (4.5, "metal")):
        b.box((0, y, 1.1), (4.5, 0.3, 0.5), sw, bevel=False)                                  # bumpers
    for sx in (-1, 1):
        b.box((sx * 1.5, -4.42, 2.15), (0.9, 0.12, 0.5), "lamp_warm", bevel=False)             # headlights
        b.box((sx * 1.6, 4.42, 2.15), (0.7, 0.12, 0.45), "bowl_red", bevel=False)              # tail lights
    return [b.finalize(N + "Car", mat), glass.finalize(N + "Car_Glass", mat)]


def corner_shop(mat):
    """The far landmark: a two-storey corner shop, its front (-Y) on the crescent. A teal fascia with CORNER SHOP,
    two big lit windows either side of the door, a striped awning, fruit and veg on trestles, a newspaper board,
    flats above with sash windows, a parapet and a chimney stack."""
    b, panes, lamp, deco = Builder(), Builder(), Builder(), Builder()
    W, D, Hh = 26.0, 12.0, 16.0
    fy = -D / 2
    b.box_base((0, 0, 0), (W + 0.4, D + 0.4, 0.6), "concrete")
    b.box_base((0, 0, 0.6), (W, D, Hh - 0.6), "brick")
    b.box_base((0, 0, Hh), (W + 0.4, D + 0.4, 0.45), "concrete", bevel=False)                   # parapet coping
    b.box((0, fy - 0.1, 9.2), (W + 0.2, 0.3, 0.4), "offwhite", bevel=False)                     # string course
    # the shop front: pilasters, fascia, two windows on stall risers, the door with a transom
    for x in (-W / 2 + 0.5, W / 2 - 0.5):
        b.box_base((x, fy - 0.25, 0.6), (1.0, 0.5, 8.0), "offwhite", bevel=False)
        b.box_base((x, fy - 0.3, 8.6), (1.3, 0.6, 0.4), "offwhite", bevel=False)
    b.box_base((0, fy - 0.2, 7.0), (W - 2.0, 0.4, 1.8), "sign_teal", bevel=False)               # fascia
    b.box((0, fy - 0.3, 8.85), (W - 1.6, 0.6, 0.15), "offwhite", bevel=False)
    for sx in (-1, 1):
        cx = sx * 6.9
        b.box_base((cx, fy - 0.15, 0.6), (9.4, 0.3, 1.2), "sign_teal", bevel=False)            # stall riser
        b.box_base((cx, fy - 0.12, 1.8), (9.4, 0.24, 0.25), "offwhite", bevel=False)            # sill
        panes.box_base((cx, fy - 0.08, 2.05), (9.0, 0.08, 4.7), "glass", bevel=False)
        for x in (cx - 1.5, cx + 1.5):
            b.box_base((x, fy - 0.18, 2.05), (0.18, 0.12, 4.7), "offwhite", bevel=False)        # mullions
        b.box_base((cx, fy - 0.18, 6.75), (9.4, 0.12, 0.25), "offwhite", bevel=False)
    b.box_base((0, fy - 0.1, 0.6), (3.4, 0.25, 6.4), "offwhite", bevel=False)                  # door frame
    b.box_base((0, fy - 0.2, 0.6), (2.8, 0.2, 5.2), "sign_teal", bevel=False)
    panes.box_base((0, fy - 0.32, 2.6), (1.8, 0.06, 2.6), "glass", bevel=False)
    panes.box_base((0, fy - 0.24, 5.9), (2.8, 0.06, 0.8), "glass", bevel=False)                 # transom
    b.box((0.95, fy - 0.38, 2.9), (0.15, 0.2, 0.7), "brass", bevel=False)
    b.box_base((0, fy - 0.85, 0), (4.6, 1.4, 0.3), "concrete")                                   # the step
    lamp.box((0, fy - 0.45, 6.95), (0.6, 0.5, 0.4), "lamp_warm", bevel=False)
    # the striped awning over the windows, sloping out from under the fascia, with a valance
    n = 12
    aw = (W - 3.0) / n
    for i in range(n):
        x = -(W - 3.0) / 2 + (i + 0.5) * aw
        b.box((x, fy - 1.45, 6.45), (aw, 2.7, 0.1), ("bowl_red", "offwhite")[i % 2], bevel=False, rot=rx(22))
    b.box((0, fy - 2.68, 5.75), (W - 2.96, 0.1, 0.45), "bowl_red", bevel=False)
    for sx in (-1, 1):
        b.box((sx * (W - 3.0) / 2, fy - 1.4, 6.0), (0.1, 2.6, 0.1), "metal", bevel=False, rot=rx(22))  # arms
    # flats above: three sash windows and a chimney stack on the party wall
    for x in (-8.0, 0.0, 8.0):
        window(b, panes, x, fy, 12.3, 3.0, 3.6)
    b.box_base((W / 2 - 2.5, 2.5, Hh + 0.45), (3.0, 1.8, 3.2), "brick")
    for dx in (-0.7, 0.7):
        b.cyl_base((W / 2 - 2.5 + dx, 2.5, Hh + 3.65), 0.3, 0.9, "terracotta", segments=8)
    for sx in (-1, 1):                                                                           # side windows
        b.box((sx * (W / 2 + 0.05), 0, 12.3), (0.2, 3.4, 4.0), "offwhite", bevel=False)
        panes.box((sx * (W / 2 + 0.17), 0, 12.3), (0.06, 3.0, 3.6), "glass", bevel=False)
    # outside: fruit and veg on two trestles, a newspaper board, hanging baskets
    for sx, fruit in ((-1, ("fur_orange", "shirt_red", "pastel_butter")), (1, ("leaf_green", "fur_orange", "shirt_red"))):
        tx = sx * 9.0
        b.box_base((tx, fy - 2.0, 2.0), (4.6, 1.8, 0.2), "caramel_wood", bevel=False)
        for x in (tx - 2.0, tx + 2.0):
            b.box_base((x, fy - 2.0, 0), (0.2, 1.5, 2.0), "dark_wood", bevel=False)
        for j, sw in enumerate(fruit):
            cx = tx - 1.5 + 1.5 * j
            b.box_base((cx, fy - 2.0, 2.2), (1.4, 1.5, 0.5), "cardboard", bevel=False)
            for q in range(3):
                deco.ico((cx - 0.35 + 0.35 * q, fy - 2.0 + 0.3 * (q % 2 - 0.5), 2.85), 0.3, sw, subdivisions=1)
    for r in (-1, 1):
        b.box((4.6, fy - 1.9 + 0.33 * r, 1.34), (1.4, 0.12, 2.7), "offwhite", bevel=False, rot=rx(r * 14))
    for z in (2.0, 1.5, 1.0):
        b.box((4.6, fy - 1.9 - 0.33 - 0.08 + 0.249 * (z - 1.34), z), (1.0, 0.04, 0.12), "fur_black", bevel=False,
              rot=rx(-14))
    for x in (-W / 2 + 0.5, W / 2 - 0.5):
        b.box((x, fy - 1.1, 8.3), (0.12, 1.2, 0.12), "fur_black", bevel=False)
        b.cyl((x, fy - 1.6, 7.6), 0.6, 0.5, "dark_wood", segments=10, radius2=0.4)
        flowers(deco, x, fy - 1.6, 7.85, n=4, r=0.35, seed=3)
    name = N + "CornerShop"
    objs = [b.finalize(name, mat), panes.finalize(name + "_Pane", mat), lamp.finalize(name + "_Bulb", mat),
            deco.finalize(name + "_Decor", mat)]
    rb = RB()                                                                                     # the fascia sign
    tw = text_width("CORNER SHOP", 0.3)
    rb.text("CORNER SHOP", (tw / 2, 7.15, -(D / 2 + 0.4)), 0.3, 0.08, "offwhite", right=(-1, 0, 0))
    objs.append(rb.finalize(name + "Sign", mat))
    return objs


SHOP_D = 12.0


# --------------------------------------------------------------- gardens -----
def flower_bed(mat, seed=0):
    """A front garden flower bed 5 x 2.2 (the v3.1 bed's size, soil top 0.7): leafy mounds and blooms as
    _Flowers, so a cat sits in among them."""
    b, fl = Builder(), Builder()
    b.box_base((0, 0, 0), (5.0, 2.2, 0.6), "brick", bevel=False)
    b.box_base((0, 0, 0.3), (4.6, 1.8, 0.4), "choco", bevel=False)
    cols = ("blush", "pastel_butter", "neon_pink", "pastel_lilac", "offwhite", "shirt_red")
    for i, x in enumerate((-1.6, 0.0, 1.6)):
        fl.ico((x, 0.15 * (-1) ** i, 0.95), 0.6, "leaf_dark" if (i + seed) % 2 else "leaf_green", subdivisions=1,
               scale=(1.1, 0.9, 0.55))
        for j in (-1, 1):
            fl.ico((x + 0.45 * j, -0.3 * j, 1.12), 0.24, cols[(2 * i + j + seed) % len(cols)], subdivisions=1)
    return [b.finalize(N + "FlowerBed", mat), fl.finalize(N + "FlowerBed_Flowers", mat)]


def bench(mat):
    return [build_bench(N + "Bench", seat="caramel_wood", frame="dumpster_green").finalize(N + "Bench", mat)]


def washing_line(mat, L=9.0):
    b, deco = Builder(), Builder()
    for x in (-L / 2, L / 2):
        b.box_base((x, 0, 0), (0.25, 0.25, 6.0), "metal", bevel=False)
    deco.box((0, 0, 5.6), (L, 0.06, 0.06), "offwhite", bevel=False)
    for i, (sw, w, h) in enumerate((("shirt_blue", 1.6, 1.8), ("blush", 1.2, 1.4), ("offwhite", 1.8, 1.2),
                                     ("pastel_butter", 1.0, 1.6), ("shirt_red", 0.5, 0.9), ("mint", 1.4, 1.5))):
        x = -L / 2 + 1.0 + i * (L - 2.0) / 5
        deco.box((x, 0.01 * (i % 2) - 0.005, 5.6 - h / 2), (w, 0.08, h), sw, bevel=False)
    return [b.finalize(N + "WashingLine", mat), deco.finalize(N + "WashingLine_Decor", mat)]


def playhouse(mat):
    """A Wendy house: walls, a door opening a cat sits in, a window, a flower box, a gable roof."""
    b, fl = Builder(), Builder()
    b.box_base((0, 0, 0), (4.4, 3.6, 3.6), "pastel_lilac")
    b.box_base((-0.8, -1.82, 0), (1.3, 0.06, 2.4), "fur_black", bevel=False)                    # doorway
    b.box_base((-0.8, -1.86, 2.4), (1.6, 0.1, 0.25), "offwhite", bevel=False)
    b.box((1.1, -1.84, 2.1), (1.1, 0.1, 1.0), "glass", bevel=False)
    b.box((1.1, -1.95, 1.4), (1.4, 0.4, 0.35), "caramel_wood", bevel=False)
    flowers(fl, 1.1, -1.95, 1.55, n=4, r=0.4, seed=4)
    gable(b, 0, 0, 3.6, 4.4, 3.6, 1.8, "pastel_lilac", "blush", over=0.3, thick=0.25)
    return [b.finalize(N + "Playhouse", mat), fl.finalize(N + "Playhouse_Flowers", mat)]


def bird_bath(mat):
    b, water = Builder(), Builder()
    b.cyl_base((0, 0, 0), 0.7, 0.25, "concrete", segments=10)
    b.cyl_base((0, 0, 0.25), 0.3, 2.2, "concrete", segments=10, radius2=0.25)
    b.cyl_base((0, 0, 2.45), 1.1, 0.35, "concrete", segments=12)
    water.cyl_base((0, 0, 2.8), 0.9, 0.04, "puddle", segments=12, bevel=False)
    return [b.finalize(N + "BirdBath", mat), water.finalize(N + "BirdBath_Water", mat)]


def deck_chair(mat, sw="sign_teal"):
    b = Builder()
    for x in (-0.9, 0.9):
        b.box((x, 0.0, 1.2), (0.15, 0.15, 2.8), "caramel_wood", bevel=False, rot=rx(-35))
        b.box((x, -0.4, 0.83), (0.15, 0.15, 1.8), "caramel_wood", bevel=False, rot=rx(30))
    b.box((0, 0.1, 1.15), (1.65, 0.08, 2.6), sw, bevel=False, rot=rx(-35))
    b.box((0, 0.6, 2.25), (1.95, 0.12, 0.12), "caramel_wood", bevel=False)
    return [b.finalize(N + "DeckChair", mat)]


def veg_bed(mat, crop="cabbage", seed=0):
    """A raised allotment bed 7 x 3.2, soil top at 0.6; the crop is _Decor so a cat can sit in among it."""
    b, deco = Builder(), Builder()
    W, D, h = 7.0, 3.2, 0.7
    for sy in (-1, 1):
        b.box_base((0, sy * (D / 2 - 0.15), 0), (W, 0.3, h), "caramel_wood", bevel=False)
    for sx in (-1, 1):
        b.box_base((sx * (W / 2 - 0.15), 0, 0), (0.3, D - 0.6, h), "caramel_wood", bevel=False)
    b.box_base((0, 0, 0), (W - 0.6, D - 0.6, h - 0.1), "choco", bevel=False)
    top = h - 0.1
    if crop == "cabbage":
        for i in range(4):
            for j in (-1, 1):
                deco.ico((-2.4 + 1.6 * i, j * 0.65, top + 0.32), 0.5, ("leaf_green", "mint")[(i + j + seed) % 2],
                         subdivisions=1, scale=(1, 1, 0.75))
    elif crop == "carrot":
        for i in range(6):
            deco.box_base((-2.5 + i, 0.6 * (-1) ** i, top), (0.3, 0.3, 0.7), "leaf_green", bevel=False)
    elif crop == "pumpkin":
        for i, x in enumerate((-2.0, 0.2, 2.1)):
            deco.ico((x, 0.2 * (i % 2), top + 0.45), 0.75 - 0.1 * (i % 2), "fur_orange", subdivisions=1,
                     scale=(1.15, 1.0, 0.75))
            deco.ico((x + 0.9, -0.5, top + 0.2), 0.45, "leaf_dark", subdivisions=1, scale=(1.2, 1.0, 0.4))
    else:                                                                                         # bean canes
        for c in (0.0,):
            for k in range(4):
                a = PI / 2 * k + 0.4
                deco.box((c + 0.55 * math.cos(a), 0.55 * math.sin(a), top + 2.4), (0.1, 0.1, 4.8), "caramel_wood",
                         bevel=False, rot=(Matrix.Rotation(-0.22, 3, "X") @ Matrix.Rotation(-a + PI / 2, 3, "Z")))
                if k % 2:
                    deco.ico((c + 0.45 * math.cos(a), 0.45 * math.sin(a), top + 1.9), 0.5, "leaf_green",
                             subdivisions=1, scale=(0.8, 0.8, 1.8))
            deco.ico((c, 0, top + 3.6), 0.35, "shirt_red", subdivisions=1)
    return [b.finalize(N + "VegBed", mat), deco.finalize(N + "VegBed_Decor", mat)]


BED_TOP = 0.6


def greenhouse(mat):
    """A glass greenhouse 8 x 6 on a brick base, the door opening at the front (-Y), staging and tomatoes inside.
    The panes are 0.15 thick so they collide."""
    b, glass, deco = Builder(), Builder(), Builder()
    W, D, Hw, rise = 8.0, 6.0, 4.6, 1.8
    b.box_base((0, 0, 0), (W + 0.2, D + 0.2, 0.5), "brick")
    b.box_base((0, 0, 0.5), (W - 0.4, D - 0.4, 0.02), "paving_light", bevel=False)               # floor
    for sx in (-1, 0, 1):
        for sy in (-1, 1):
            if sx == 0 and sy == -1:
                continue
            b.box_base((sx * (W / 2 - 0.1), sy * (D / 2 - 0.1), 0.5), (0.2, 0.2, Hw), "offwhite", bevel=False)
    for x in (-1.3, 1.3):
        b.box_base((x, -D / 2 + 0.1, 0.5), (0.2, 0.2, Hw), "offwhite", bevel=False)              # door posts
    glass.box_base((0, D / 2 - 0.1, 0.5), (W - 0.4, 0.15, Hw - 0.1), "glass", bevel=False)            # back
    for sx in (-1, 1):
        glass.box_base((sx * (W / 4 + 0.65), -D / 2 + 0.1, 0.5), (W / 2 - 1.5, 0.15, Hw - 0.1), "glass", bevel=False)
        glass.box_base((sx * (W / 2 - 0.1), 0, 0.5), (0.15, D - 0.4, Hw - 0.1), "glass", bevel=False)
        glass.fan((sx * (W / 2 - 0.1), 0, 0.5 + Hw), (0, rise), [(-D / 2 + 0.1, 0), (D / 2 - 0.1, 0)], 0.15, "glass",
                  rot=Matrix(((0, 0, 1), (1, 0, 0), (0, 1, 0))))
    a = math.atan2(rise, D / 2)
    L = math.hypot(D / 2, rise) + 0.2
    for sy in (-1, 1):
        glass.box((0, sy * D / 4, 0.5 + Hw + rise / 2 + 0.05), (W + 0.2, L, 0.15), "glass", bevel=False,
                  rot=rx(-sy * math.degrees(a)))
    b.box((0, 0, 0.5 + Hw + rise + 0.05), (W + 0.4, 0.3, 0.3), "offwhite", bevel=False)            # ridge
    b.box_base((0, D / 2 - 1.0, 0.52), (W - 1.0, 1.2, 1.6), "caramel_wood", bevel=False)           # staging
    for i in range(4):
        x = -2.7 + 1.8 * i
        b.cyl_base((x, D / 2 - 1.0, 2.12), 0.35, 0.4, "terracotta", segments=8)
        deco.ico((x, D / 2 - 1.0, 2.9), 0.5, "leaf_dark", subdivisions=1, scale=(1, 1, 1.3))
        deco.ico((x + 0.2, D / 2 - 1.3, 2.7), 0.18, "shirt_red", subdivisions=1)
    name = N + "Greenhouse"
    return [b.finalize(name, mat), glass.finalize(name + "_Glass", mat), deco.finalize(name + "_Decor", mat)]


GREENHOUSE_FLOOR = 0.52


def scarecrow(mat):
    b, deco = Builder(), Builder()
    b.box_base((0, 0, 0), (0.3, 0.3, 6.0), "dark_wood", bevel=False)
    b.box((0, 0, 4.6), (4.2, 0.25, 0.25), "dark_wood", bevel=False)
    b.box_base((0, 0, 3.1), (1.6, 0.8, 2.0), "shirt_red", bevel=False)                          # the shirt
    b.box_base((0, 0, 2.2), (1.3, 0.7, 0.9), "pants_navy", bevel=False)
    b.box((0, 0, 4.6), (3.6, 0.6, 0.6), "shirt_red", bevel=False)                                # sleeves
    b.ico((0, 0, 5.9), 0.7, "fur_sand", subdivisions=1)
    b.cyl_base((0, 0, 6.35), 1.2, 0.12, "caramel_wood", segments=12, bevel=False)                 # the hat
    b.cyl_base((0, 0, 6.47), 0.6, 0.7, "caramel_wood", segments=10)
    for sx in (-1, 1):
        deco.ico((sx * 2.0, 0, 4.6), 0.35, "pastel_butter", subdivisions=1, scale=(1, 1, 1.4))     # straw
    deco.ico((0.45, 0, 7.4), 0.4, "fur_black", subdivisions=1, scale=(1.3, 0.8, 0.7))             # a crow on top
    return [b.finalize(N + "Scarecrow", mat), deco.finalize(N + "Scarecrow_Decor", mat)]


def water_butt(mat):
    b = Builder()
    b.box_base((0, 0, 0), (1.9, 1.9, 0.6), "concrete")
    b.cyl_base((0, 0, 0.6), 0.85, 2.6, "dumpster_green", segments=12)
    b.cyl_base((0, 0, 3.2), 0.92, 0.15, "fur_black", segments=12, bevel=False)
    b.box((0, -0.92, 1.0), (0.2, 0.3, 0.2), "brass", bevel=False)
    return [b.finalize(N + "WaterButt", mat)]


def compost_bin(mat):
    b = Builder()
    b.box_base((0, 0, 0), (2.8, 2.8, 2.2), "dark_wood")
    for z in (0.6, 1.2, 1.8):
        b.box((0, -1.42, z), (2.8, 0.06, 0.08), "fur_black", bevel=False)
    b.box_base((0, 0, 2.2), (3.0, 3.0, 0.15), "caramel_wood", bevel=False)
    b.ico((0, 0, 2.3), 1.0, "choco", subdivisions=1, scale=(1.1, 1.1, 0.3))
    return [b.finalize(N + "CompostBin", mat)]


def potting_shed(mat):
    """A small lean-to shed (not a trap: its door stands open), a bench outside it."""
    b = Builder()
    W, D, h0, h1 = 5.0, 4.0, 4.0, 4.8
    b.box_base((0, 0, 0), (W, D, h0), "sign_teal")
    b.fan((0, 0, h0), (D / 2, h1 - h0), [(-D / 2, 0), (D / 2, 0)], W, "sign_teal",
          rot=Matrix(((0, 0, 1), (1, 0, 0), (0, 1, 0))))
    a = math.atan2(h1 - h0, D)
    b.box((0, 0, (h0 + h1) / 2 + 0.12 / math.cos(a)), (W + 0.6, math.hypot(D, h1 - h0) + 0.6, 0.25), "dark_wood",
          bevel=False, rot=rx(math.degrees(a)))
    b.box_base((-0.9, -D / 2 - 0.02, 0), (1.8, 0.06, 3.3), "fur_black", bevel=False)              # the doorway
    b.box_base((-2.0, -D / 2 - 0.5, 0), (0.12, 1.0, 3.3), "dark_wood", bevel=False)               # the door, open
    b.box((1.4, -D / 2 - 0.05, 2.4), (1.2, 0.1, 1.0), "glass", bevel=False)
    b.box_base((1.4, -D / 2 - 0.8, 0), (1.8, 0.8, 1.2), "caramel_wood", bevel=False)              # potting bench
    b.cyl_base((1.0, -D / 2 - 0.8, 1.2), 0.3, 0.4, "terracotta", segments=8)
    return [b.finalize(N + "PottingShed", mat)]


def sunflowers(mat, n=5):
    fl = Builder()
    for i in range(n):
        x, h = -((n - 1) / 2) * 1.3 + i * 1.3, 5.2 + 0.6 * (i % 3)
        fl.box_base((x, 0, 0), (0.18, 0.18, h), "leaf_green", bevel=False)
        fl.box((x + 0.35, 0, h * 0.55), (0.7, 0.1, 0.35), "leaf_green", bevel=False)
        fl.cyl((x, -0.15, h + 0.3), 0.75, 0.15, "pastel_butter", segments=8, rot=rx(80))
        fl.cyl((x, -0.25, h + 0.3), 0.35, 0.15, "choco", segments=8, rot=rx(80))
    return [fl.finalize(N + "Sunflowers_Flowers", mat)]


# ---------------------------------------------------------------- ground -----
ROADS = [(-5.0, 5.0, -IN, S1_Z - 5), (-S1_END, S1_END, S1_Z - 5, S1_Z + 5), (G1_X - 5, G1_X + 5, S1_Z + 5, S3_Z - 5),
         (-S3_END, S3_END, S3_Z - 5, S3_Z + 5), (G2_X - 5, G2_X + 5, S3_Z + 5, H[1]),
         (EL_X - 5, EL_X + 5, TURN_C[1], H[1])]
HEADS = [(sx * S1_END, S1_Z, 8.0) for sx in (-1, 1)] + [(sx * S3_END, S3_Z, 8.0) for sx in (-1, 1)] + \
        [(TURN_C[0], TURN_C[1], TURN_R)]
PAVES = [(-8.0, -5.0, -IN, S1_Z - 8), (5.0, 8.0, -IN, S1_Z - 8),
         (-S1_END, -5.0, S1_Z - 8, S1_Z - 5), (5.0, S1_END, S1_Z - 8, S1_Z - 5),
         (-S1_END, G1_X - 5, S1_Z + 5, S1_Z + 8), (G1_X + 5, S1_END, S1_Z + 5, S1_Z + 8),
         (G1_X - 8, G1_X - 5, S1_Z + 8, S3_Z - 8), (G1_X + 5, G1_X + 8, S1_Z + 8, S3_Z - 8),
         (-S3_END, G1_X - 5, S3_Z - 8, S3_Z - 5), (G1_X + 5, S3_END, S3_Z - 8, S3_Z - 5),
         (-S3_END, G2_X - 5, S3_Z + 5, S3_Z + 8), (G2_X + 5, S3_END, S3_Z + 5, S3_Z + 8),
         (G2_X - 8, G2_X - 5, S3_Z + 8, H[1]), (G2_X + 5, G2_X + 8, S3_Z + 8, H[1]),
         (EL_X + 5, EL_X + 8, TURN_C[1] + TURN_R, H[1]), (EL_X - 8, EL_X - 5, TURN_C[1] + TURN_R, H[1])]


def _half_ring(g, r_out, w, top, swatch, n=24):
    """Blocks round the hub from 0 to 180 degrees; tops alternate 0.006 apart and sit 0.003 above the straight
    slabs of the same kind, so no two overlapping blocks share a top."""
    rr = r_out - w / 2
    da = PI / n
    chord = 2 * r_out * math.sin(da / 2) * 1.04
    for k in range(n):
        a = (k + 0.5) * da
        bx, by, _ = bl(*polar(rr, math.degrees(a)))
        g.box_base((bx, by, 0), (w, chord, top + 0.003 + 0.006 * (k % 2)), swatch, bevel=False, rot=(PI - a, "Z"))


def _strip(g, p0, p1, w, swatch, top):
    (ax, ay, _), (bx, by, _) = bl(*p0), bl(*p1)
    L = math.hypot(bx - ax, by - ay)
    g.box_base(((ax + bx) / 2, (ay + by) / 2, 0), (L, w, top), swatch, bevel=False,
               rot=(math.atan2(by - ay, bx - ax), "Z"))


def _ground(g):
    """Roads (top 0.24) with centre dashes, pavements (0.34) cut round the roads, the crescent's half rings, the
    turning heads (discs 0.006 proud), footpaths and the playground's safety surface."""
    for (x0, x1, z0, z1) in ROADS:
        span(g, x0, x1, z0, z1, 0.015, ROAD_Y, "concrete_dark")
    for (x, z, r) in HEADS:
        g.cyl_base(bl(x, z, 0.015), r, ROAD_Y + 0.006 - 0.015, "concrete_dark", segments=24, bevel=False)
    for (x0, x1, z0, z1) in rects_minus(PAVES, ROADS):
        span(g, x0, x1, z0, z1, 0.01, PAVE_Y, "concrete")
    _half_ring(g, CR + 5, 10.0, ROAD_Y, "concrete_dark")
    _half_ring(g, CR + 8, 3.0, PAVE_Y, "concrete")
    _half_ring(g, CR - 5, 3.0, PAVE_Y, "concrete")
    # dashes down the middle of every road
    dash = ROAD_Y + 0.01

    def dashes(p0, p1, step=7.0):
        L = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        for i in range(int(L / step)):
            t = (i + 0.5) * step / L
            x, z = p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t
            _strip(g, (x - (p1[0] - p0[0]) / L * 1.2, z - (p1[1] - p0[1]) / L * 1.2),
                   (x + (p1[0] - p0[0]) / L * 1.2, z + (p1[1] - p0[1]) / L * 1.2), 0.4, "offwhite", dash)

    dashes((0, -IN + 2), (0, S1_Z - 6))
    dashes((-S1_END + 4, S1_Z), (S1_END - 4, S1_Z))
    dashes((G1_X, S1_Z + 6), (G1_X, S3_Z - 6))
    dashes((-S3_END + 4, S3_Z), (S3_END - 4, S3_Z))
    dashes((G2_X, S3_Z + 6), (G2_X, H[1]))
    dashes((EL_X, TURN_C[1] + TURN_R), (EL_X, H[1]))
    for k in range(14):
        a = math.radians((k + 0.5) * 180 / 14)
        x, z = polar(CR, math.degrees(a))
        tx, tz = -math.sin(a) * 1.2, math.cos(a) * 1.2
        _strip(g, (x - tx, z - tz), (x + tx, z + tz), 0.4, "offwhite", dash + 0.003)
    # the playground's safety surface, footpaths into the back gardens and the allotments
    g.cyl_base(bl(*H, 0.0), 18.5, 0.045, "terracotta", segments=32, bevel=False)
    _strip(g, (-54.0, 28.0), (-96.0, 28.0), 4.0, "paving_sand", 0.05)                  # the west leg's footpath
    for (a, b, w) in (((-95.0, 0.0), (-95.0, 128.0), 3.0), ((-95.0, 128.0), (-40.0, 128.0), 3.0)):
        _strip(g, a, b, w, "paving_sand", 0.056)
    for th in TWITTENS:
        _strip(g, polar(CR + 8, th), polar(66, th), 4.0, "paving_sand", 0.05)
    for (a, b) in (((90.0, -2.0), (90.0, 134.0)), ((36.0, 108.0), (134.0, 108.0)), ((38.0, 50.0), (134.0, 50.0)),
                   ((38.0, 10.0), (134.0, 10.0))):
        _strip(g, a, b, 4.0, "paving_sand", 0.05 + (0.006 if a[0] == 90.0 else 0.0))


# ------------------------------------------------------------- the streets ---
def _walls(s, mat):
    far = ("fence", "hedge", "brick", "fence", "hedge", "brick", "hedge", "fence")
    east = ("hedge", "brick", "fence", "hedge", "brick", "fence", "hedge", "brick")
    west = ("brick", "fence", "hedge", "brick", "fence", "hedge", "brick", "hedge")
    _run(s, mat, far, 8, 2 * IN, lambda t: (-IN + t, IN, 0), 0)
    _run(s, mat, east, 8, 2 * IN, lambda t: (IN, -IN + t, 90), 1)
    _run(s, mat, west, 8, 2 * IN, lambda t: (-IN, IN - t, -90), 2)
    for sx in (-1, 1):
        s.put(pier(mat, h=11.2, w=2.4), sx * (IN + 1.2), IN, 0)                             # far corners
        s.put(pier(mat, h=6.0, w=2.4), sx * (IN + 1.2), -IN - 0.3, 180)                     # town corners
        L = IN - GATE_HALF - 1.0
        s.put(town_hedge(mat, L), sx * (GATE_HALF + 1.0 + L / 2), -IN, 180)
        s.put(nb.lamp_post(mat), sx * (GATE_HALF + 2.5), -IN + 1.5, 0)                      # either side of the gate
    bar = Builder()
    ox = IN + WALL_D
    bar.box_base((0, IN + WALL_D / 2, 0), (2 * ox, WALL_D, BARRIER_H), "offwhite", bevel=False)               # far
    for sx in (-1, 1):
        bar.box_base((sx * (IN + WALL_D / 2), 0, 0), (WALL_D, 2 * IN, BARRIER_H), "offwhite", bevel=False)    # sides
        bar.box_base((sx * (GATE_HALF + ox) / 2, -(IN + WALL_D / 2), 0), (ox - GATE_HALF, WALL_D, BARRIER_H),
                     "offwhite", bevel=False)                                                               # town side
    s.put([bar.finalize(N + "Walls_Barrier", mat)], 0, 0, 0)


def _spot(s, label, x, z, y=0.0, turn=None):
    p = [round(x, 2), round(y, 2), round(z, 2), "deep" if z > 0 else "near"]
    if turn is not None:
        p.append(turn)
    s.points.setdefault(label, []).append(p)


FENCE_KINDS = ("picket", "wall", "hedge")


def _lot(s, g, mat, variant, x, zc, rot, k, spot=None, extras=(), width=PLOT):
    """One house plot: the house (or bungalow), its front fence at FRONT with a gap and a path to the door, and the
    extras asked for (flower bed, hedge, mailbox). `spot` puts a cat spot on the porch or in the flower bed.
    Returns the door's Roblox local x."""
    if variant.startswith("D"):
        s.put(bungalow(mat, variant), x, zc, rot)
        door_bx, step_end = 0.0, HD / 2 + 1.4
    else:
        objs, door_bx = house(variant, mat)
        s.put(objs, x, zc, rot)
        step_end = HD / 2 + PD + 1.6
    lx_door = -door_bx
    s.put(front_fence(mat, FENCE_KINDS[k % 3], width, door_bx), *turned(x, zc, rot, 0, -FRONT), rot)
    pc = turned(x, zc, rot, lx_door, -(FRONT + step_end) / 2)
    g.box_base(bl(*pc), (3.0, FRONT - step_end, PATH_Y), "paving_light", bevel=False, rot=rz(rot))
    front = -HD / 2 - PD - 1.7
    bed_x = 9.5 if door_bx else 6.5
    if "bed" in extras:
        s.put(flower_bed(mat, k), *turned(x, zc, rot, bed_x, front), rot)
    if "hedge" in extras:
        s.put(nb.hedge(mat), *turned(x, zc, rot, -7.0, front), rot)
    if "mail" in extras:
        s.put(nb.mailbox(mat), *turned(x, zc, rot, lx_door - 3.2, -FRONT - 0.8), rot)
    if spot == "porch":
        _spot(s, "porch", *turned(x, zc, rot, 2.8 - door_bx, -HD / 2 - 2.4), y=1.0)
    elif spot == "flowerbed":
        _spot(s, "flowerbed", *turned(x, zc, rot, bed_x, front), y=0.7)
    return lx_door


def _row(s, g, mat, plots, zc, rot, x0, x1, seed=0):
    """A row of plots facing one street. plots: (x, variant, spot, extras). Side fences close the gaps between
    houses (and to the block's ends) just behind the front line, low hedges part the front gardens."""
    fs = -1 if rot == 0 else 1                       # the front's direction along z
    line = zc + fs * (HD / 2 - 0.35)                 # side fences: just behind the house fronts
    mid = zc + fs * (HD / 2 + 0.2 + 3.15)            # the front gardens' middle, for the low hedges
    xs = sorted(p[0] for p in plots)
    for i, (x, variant, spot, extras) in enumerate(plots):
        _lot(s, g, mat, variant, x, zc, rot, i + seed, spot, extras)
    edges = [x0] + [e for x in xs for e in (x - 10.5, x + 10.5)] + [x1]
    for a, b in zip(edges[0::2], edges[1::2]):
        ends = (0.6 if abs(a) > IN - 0.1 else 0.25, 0.6 if abs(b) > IN - 0.1 else 0.25)
        a2, b2 = a + (ends[0] if a in (x0, x1) else 0.0), b - (ends[1] if b in (x0, x1) else 0.0)
        if b2 - a2 > 0.8:
            s.put(side_fence(mat, b2 - a2), (a2 + b2) / 2, line, rot)
    for a, b in zip(xs, xs[1:]):
        if abs(b - a - PLOT) < 0.1:
            s.put(low_hedge(mat, 6.3), (a + b) / 2, mid, 90)
    return xs


def _block_end(s, mat, x, z0, z1, rot=90):
    """A close-board fence along a block's end, from one front line to the other (or to its back fence)."""
    s.put(side_fence(mat, abs(z1 - z0) - 1.0, gate=False), x, (z0 + z1) / 2, rot)       # posts clear of the rows'


def _rows(s, g, mat):
    z1s, z1n, z2s = ROW1[0] + FRONT, ROW1[1] - FRONT, ROW2[0] + FRONT       # house centres: -91.5, -66.5, -25.5
    # the first block, its south face on S1 (seen from the gate) and its north face on S3
    _row(s, g, mat, [(-113, "C2", "porch", ("bed",)), (-87, "A2", "flowerbed", ("bed", "mail")),
                     (-61, "B2", "porch", ("hedge",)), (-35, "C", None, ("mail",)),
                     (-9, "A", "porch", ("bed", "hedge")), (17, "B", "flowerbed", ("bed",))],
         z1s, 0, R1W[0], R1W[1])
    _row(s, g, mat, [(75, "C3", "porch", ("hedge", "mail")), (101, "A3", "flowerbed", ("bed",))], z1s, 0, R1E[0], 114.0,
         seed=1)
    _row(s, g, mat, [(-113, "A2", "flowerbed", ("bed",)), (-87, "B", "porch", ("hedge", "mail")),
                     (-61, "D", "flowerbed", ("bed",)), (-35, "A", None, ("bed",)),
                     (-9, "B3", "porch", ("hedge",)), (17, "C", "porch", ("bed", "mail"))],
         z1n, 180, R1W[0], R1W[1], seed=2)
    _row(s, g, mat, [(75, "B2", "flowerbed", ("bed",)), (101, "C", "porch", ("mail",))], z1n, 180, R1E[0], 119.5,
         seed=1)
    # the second block's south face on S3; its back gardens run to z -4
    _row(s, g, mat, [(-101, "C", "porch", ("bed",)), (-75, "A3", None, ("hedge",))], z2s, 0, -119.5, R2W[1],
         seed=2)
    _row(s, g, mat, [(-17, "B", "flowerbed", ("bed", "mail")), (9, "A2", "porch", ("hedge",)),
                     (35, "C2", None, ("bed",)), (61, "B3", "porch", ("mail",)), (87, "C3", "flowerbed", ("bed",)),
                     (113, "A", "porch", ("hedge",))], z2s, 0, R2E[0], R2E[1])
    # the gutter on the S3 bungalow (near): the cat in the gutter by the downpipe
    _spot(s, "trap_gutter", *turned(-61, z1n, 180, *GUTTER_SPOT), y=GUTTER_Z, turn=180)
    # block ends and the fillers at the walls
    for x in (R1W[1] - 0.2, R1E[0] + 0.2):
        _block_end(s, mat, x, ROW1[0] + 7.9, ROW1[1] - 7.9)
    for x in (R2W[1] + 0.2, R2E[0] + 0.2):
        _block_end(s, mat, x, ROW2[0] + 7.9, ROW2[1] - 0.2)
    for (x0, x1, z, rot) in ((-IN + 0.5, -126.0, ROW1[0], 0), (-IN + 0.5, -126.0, ROW1[1], 180),
                             (126.0, IN - 0.5, ROW2[0], 0)):
        s.put(front_fence(mat, "hedge", x1 - x0, -(x1 - x0) / 2 - 3.0, gap_w=0.0), (x0 + x1) / 2, z, rot)
    for (x, z0, z1) in ((R1W[1] - 0.7, ROW1[0] + 0.8, ROW1[0] + 7.1), (R1W[1] - 0.7, ROW1[1] - 7.1, ROW1[1] - 0.8),
                        (R1E[0] + 0.7, ROW1[0] + 0.8, ROW1[0] + 7.1), (R1E[0] + 0.7, ROW1[1] - 7.1, ROW1[1] - 0.8),
                        (R2W[1] + 0.7, ROW2[0] + 0.8, ROW2[0] + 7.1), (R2E[0] + 0.7, ROW2[0] + 0.8, ROW2[0] + 7.1),
                        (114.0, ROW1[0] + 0.8, ROW1[0] + 7.1)):
        s.put(low_hedge(mat, z1 - z0), x, (z0 + z1) / 2, 90)
    # the near shed's corner garden (first block, east end, on S1), and the garages at the other corners
    s.put(side_fence(mat, IN - 114.9, gate=False), (114.3 + IN - 0.6) / 2, -80.15, 0)
    s.put(side_fence(mat, 16.0, gate=False), 114.15, ROW1[0] + 7.5 + 8.0, 90)
    s.put(front_fence(mat, "picket", IN - 114.0, -(125.5 - (114.0 + IN) / 2)), (114.0 + IN) / 2, ROW1[0], 0)
    s.put(nb.garden_shed(mat), 127.0, -86.0, 0)
    _spot(s, "trap_shed", *turned(127.0, -86.0, 0, -0.6, -3.3), turn=0)
    s.put(nb.gnome(mat), 118.5, -98.0, 200)
    _spot(s, "garden", 120.0, -92.0)
    s.put(bench(mat), 119.0, -83.6, 180)
    for (x, zc, rot) in ((125.5, ROW1[1] - 7.5 - 6.0, 180), (-125.5, ROW2[0] + 7.5 + 6.0, 0)):
        s.put(nb.garage(mat), x, zc, rot)
        fz = zc - 6.0 - 7.5 if rot == 0 else zc + 6.0 + 7.5
        g.box_base(bl(x, (fz + (zc - 6.0 if rot == 0 else zc + 6.0)) / 2), (10.0, 7.5, DRIVE_Y), "concrete",
                   bevel=False)
        s.put(front_fence(mat, "hedge", IN - 114.0 if x > 0 else IN - 114.0, (x - (114.0 + IN) / 2) if x > 0 else
                          -(x + (114.0 + IN) / 2), gap_w=10.4), (114.0 + IN) / 2 * (1 if x > 0 else -1), fz, rot)
        sx = 1 if x > 0 else -1
        s.put(side_fence(mat, IN - 132.6, gate=False), sx * (132.0 + IN - 0.6) / 2, zc + (5.65 if rot == 180 else -5.65),
              rot)
    s.put(car(mat, "fur_rose"), -125.5, ROW2[0] + 2.0, 0)
    _spot(s, "car", -121.5, ROW2[0] + 3.0, y=DRIVE_Y)
    # back fences: the second block's, a hedge where the green looks at it
    s.put(side_fence(mat, R2W[1] - R2W[0] - 0.8, gate=False), (R2W[0] + R2W[1]) / 2 + 0.2, ROW2[1] - 0.15, 180)
    s.put(low_hedge(mat, E_LINE - R2E[0] - 0.6, h=7.0, d=1.6), (R2E[0] + E_LINE) / 2, ROW2[1] - 0.95, 0)
    s.put(side_fence(mat, R2E[1] - E_LINE - 1.0, gate=False), (E_LINE + R2E[1]) / 2 - 0.1, ROW2[1] - 0.15, 180)
    # trees in the back gardens, over the roofs
    tb = Builder()
    for (x, z, h, k) in ((-100, -79, 15, 0), (-48, -80, 16, 1), (4, -78, 14, 2), (86, -80, 15, 1), (-110, -10, 14, 0),
                         (22, -11, 15, 2), (74, -12, 14, 0), (-40, -82, 13, 2), (-80, -11, 13, 1), (122, -10, 14, 2)):
        tree_round(tb, -x, z, 0, h=h, r=3.4 + 0.3 * k, leaf=("leaf_green", "leaf_dark", "mint")[k])
    s.put([tb.finalize(N + "BackTrees", mat)], 0, 0, 0)
    return z1s, z1n, z2s


# ---------------------------------------------------------- the far third ----
def _fence_between(s, mat, p, q, trim=0.5, hedge=False):
    """A close-board fence (or a tall hedge) along the straight line p -> q, trimmed at both ends so its posts
    stay clear of the houses it runs between."""
    d = (q[0] - p[0], q[1] - p[1])
    L = math.hypot(*d)
    if L - 2 * trim < 0.8:
        return
    rot = math.degrees(math.atan2(-d[1], d[0]))
    mid = ((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)
    piece = low_hedge(mat, L - 2 * trim, h=6.8, d=1.6) if hedge else side_fence(mat, L - 2 * trim, gate=False)
    s.put(piece, *mid, rot)


def _theta(p):
    return math.degrees(math.atan2(p[1] - H[1], p[0] - H[0]))


def _crescent(s, g, mat):
    """The crescent's outer houses and the corner shop, each facing the hub. Returns their front corners (high
    angle first), 0.3 inside the pieces, for the barrier line."""
    corners = []
    for i, (th, kind, var) in enumerate(CRESCENT):
        depth, hw = (SHOP_D, 13.0) if kind == "shop" else (HD, 10.0)
        cx, cz = polar(47.5 + depth / 2, th)
        rot = round(face(cx, cz, *H), 2)
        if kind == "shop":
            s.put(corner_shop(mat), cx, cz, rot)
            fc = turned(cx, cz, rot, 0, -depth / 2 - 3.75)
            g.box_base(bl(*fc), (W_SHOP_FORECOURT, 7.5, PATH_Y), "paving_light", bevel=False, rot=rz(rot))
            s.put(bench(mat), *turned(cx, cz, rot, -15.5, -depth / 2 - 4.5),
                  rot)
            _spot(s, "shop_bench", *turned(cx, cz, rot, -13.5, -depth / 2 - 6.7), y=PATH_Y)
            _spot(s, "shop_step", *turned(cx, cz, rot, 0.0, -depth / 2 - 1.4), y=0.3)
            _spot(s, "fruit_stall", *turned(cx, cz, rot, -9.0, -depth / 2 - 4.6), y=PATH_Y)
            s.put(nb.bicycle(mat), *turned(cx, cz, rot, 14.4, -depth / 2 - 1.0), rot + 90)
            s.put(post_box(mat), *turned(cx, cz, rot, 14.0, -depth / 2 - 6.5), rot)
        elif kind == "bungalow":
            _lot(s, g, mat, var, cx, cz, rot, i, "flowerbed", ("bed",), width=22.0)
            _spot(s, "trap_gutter", *turned(cx, cz, rot, *GUTTER_SPOT), y=GUTTER_Z, turn=rot)
        else:
            _lot(s, g, mat, var, cx, cz, rot, i, "porch", ("bed",) if i % 2 else ("hedge",), width=22.0)
        pa, pb = turned(cx, cz, rot, hw, -depth / 2 + 0.3), turned(cx, cz, rot, -hw, -depth / 2 + 0.3)
        corners.append(tuple(sorted((pa, pb), key=_theta, reverse=True)))
    return corners


W_SHOP_FORECOURT = 26.0


def _far(s, g, mat):
    lines = []                                                       # barrier polylines
    # the west leg: two houses facing it, a footpath between them into the back gardens
    for k, (z, var, extras) in enumerate(((10.0, "B2", ("bed",)), (46.0, "C", ("hedge", "mail")))):
        _lot(s, g, mat, var, -66.5, z, -90, k, "porch", extras)
    s.put(pk.rose_arch(mat), -58.0, 28.0, 90)
    s.put(fingerpost(mat, "GARDENS"), -55.8, 33.4, 0)
    # the east leg's house, facing the turning circle's road
    _lot(s, g, mat, "A3", 38.5, 56.0, 90, 2, "porch", ("bed",), width=24.0)
    corners = _crescent(s, g, mat)
    (c160, c124, cshop, c56, c20) = corners
    lines.append([(W_LINE, ROW2[1]), (W_LINE, W_TWITTEN[0])])
    lines.append([(W_LINE, W_TWITTEN[1]), (W_LINE, 56.0), c160[0], c160[1]])
    lines.append([c124[0], c124[1], cshop[0], cshop[1], c56[0], c56[1]])
    lines.append([c20[0], c20[1], (E_LINE, 66.0), (E_LINE, ROW2[1])])
    # what you see on those lines between the houses
    _fence_between(s, mat, (W_LINE + 0.25, ROW2[1]), (W_LINE + 0.25, -0.6), trim=0.25)
    _fence_between(s, mat, (W_LINE + 0.25, 56.0), c160[0])
    for (p, q) in ((c124[1], cshop[0]), (cshop[1], c56[0]), (c20[1], (E_LINE - 0.25, 66.0))):
        _fence_between(s, mat, p, q)
    _fence_between(s, mat, (E_LINE, ROW2[1] + 0.2), (E_LINE, 45.6), trim=0.0, hedge=True)
    s.put(fingerpost(mat, "ALLOTMENTS"), *polar(41.5, TWITTENS[1] - 6.5), face(*polar(41.5, TWITTENS[1] - 6.5),
                                                                                      *H) - 90)
    s.put(street_sign(mat, "PAW CRESCENT"), -56.6, 62.0, 0)

    # ---- the hub: the playground in the crescent's round
    hx, hz = H
    s.put(nb.tyre_swing_oak(mat), hx + 2, hz + 4, 20)
    _spot(s, "tyre", *turned(hx + 2, hz + 4, 20, -4.4, -2.2))
    srot = face(hx - 13, hz + 8, hx, hz)
    s.put(nb.slide(mat), hx - 13, hz + 8, srot + 180)
    _spot(s, "slide", *turned(hx - 13, hz + 8, srot + 180, 0, 2.0), y=4.0)               # up on the deck
    s.put(nb.swings(mat), hx + 1, hz - 13, 0)
    _spot(s, "swings", hx - 2.0, hz - 16.5)
    s.put(nb.sandbox(mat), hx + 12, hz - 5, 10)
    _spot(s, "sandbox", *turned(hx + 12, hz - 5, 10, 1.2, 1.2), y=0.55)
    s.put(pk.roundabout(mat), hx - 11, hz - 7, 0)
    _spot(s, "roundabout", hx - 11, hz - 7, y=pk.ROUNDABOUT_TOP)
    s.put(pk.seesaw(mat), hx + 11, hz + 11, 60)
    _spot(s, "seesaw", *turned(hx + 11, hz + 11, 60, 0, -2.6))
    for th in (215, 325):
        x, z = polar(21.2, th)
        s.put(bench(mat), x, z, face(x, z, *H))

    # ---- the village green, between the second block's back hedge and the hub
    for (x, z, r) in ((-27, 30, 30), (22, 12, 100), (-8, 4, 200)):
        s.put(pk.oak(mat), x, z, r)
    _spot(s, "oak", -23.5, 26.5)
    for (x, z, r) in ((2, 22, 10), (-20, 12, -20)):
        s.put(pk.picnic_table(mat), x, z, r)
    _spot(s, "picnic", *turned(2, 22, 10, 0, -4.0))
    for (x, z) in ((-33.0, 18.0), (3.0, 42.0)):
        s.put(bench(mat), x, z, face(x, z, -4, 20))
    _spot(s, "green_bench", *turned(-33.0, 18.0, face(-33.0, 18.0, -4, 20), 0, -2.0))
    for i, (x, z) in enumerate(((-8.0, 34.0), (14.0, 28.0))):
        s.put(pk.flower_bed(mat, i), x, z, 15 * i)
    _spot(s, "flowerbed", -8.0, 34.0, y=0.62)
    s.put(nb.ice_cream_van(mat), TURN_C[0], TURN_C[1], 90, y=ROAD_Y + 0.006)
    _spot(s, "van", *turned(TURN_C[0], TURN_C[1], 90, 0, 8.6), y=ROAD_Y)
    s.put(post_box(mat), -36.5, -1.0, 90)

    # ---- the back gardens, behind the west houses: three gardens on a footpath, low hedges between with gaps
    for (z, gap) in ((42.0, (-98.5, -91.5)), (96.0, (-98.5, -91.5))):
        for (a0, a1) in ((-IN + 0.6, gap[0]), (gap[1], -72.5 if z < 60 else -74.0)):
            s.put(low_hedge(mat, a1 - a0, h=3.0), (a0 + a1) / 2, z, 0)
    s.put(nb.trampoline(mat), -118, 14, 0)
    _spot(s, "trampoline", -118, 14, y=1.73)
    s.put(washing_line(mat), -110, 34, 0)
    _spot(s, "washing", -108, 31.5)
    for (x, z, r, sw) in ((-86, 4, 200, "sign_teal"), (-81.5, 6, 165, "blush")):
        s.put(deck_chair(mat, sw), x, z, r)
    _spot(s, "deckchair", -84, 0.5)
    s.put(nb.bbq(mat), -80, 16, -30)
    for (x, z) in ((-84, 20), (-77, 22)):
        s.put(nb.gnome(mat), x, z, 120)
    _spot(s, "gnomes", -80.5, 21)
    s.put(nb.kiddie_pool(mat), -118, 62, 0)
    _spot(s, "pool", -118, 57.0)
    s.put(playhouse(mat), -110, 84, 170)
    _spot(s, "playhouse", *turned(-110, 84, 170, 0.8, -3.0))
    s.put(bench(mat), -80, 70, -90)
    _spot(s, "garden_bench", *turned(-80, 70, -90, 0, -2.4))
    s.put(bird_bath(mat), -104, 54, 0)
    _spot(s, "birdbath", -101.5, 54)
    for i, (x, z) in enumerate(((-130, 76), (-130, 88))):
        s.put(pk.flower_bed(mat, i + 2), x, z, 90)
    s.put(greenhouse(mat), -118, 122, 0)
    _spot(s, "greenhouse", -118, 120.5, y=GREENHOUSE_FLOOR)
    s.put(deck_chair(mat, "pastel_butter"), -100, 112, 180)
    s.put(washing_line(mat, 8.0), -62, 120, 30)
    s.put(bird_bath(mat), -84, 120, 0)
    _spot(s, "garden", -78, 132)
    s.put(nb.gnome(mat), -48, 131.5, 200)
    s.put(nb.recycling_bins(mat), -6, 133, 180)                                     # behind the shop
    s.put(potting_shed(mat), -128, 104, 90)

    # ---- the allotments, behind the east houses: beds along gravel paths, sheds, a greenhouse
    beds = [(48, 117, "cabbage"), (62, 117, "beans"), (76, 117, "carrot"), (104, 117, "pumpkin"), (118, 117, "cabbage"),
            (48, 99, "carrot"), (62, 99, "pumpkin"), (104, 99, "beans"), (118, 99, "carrot"),
            (52, 59, "pumpkin"), (66, 59, "cabbage"), (104, 59, "carrot"), (118, 59, "cabbage"),
            (52, 41, "beans"), (112, 41, "pumpkin"), (66, 18, "carrot"), (110, 18, "cabbage")]
    for i, (x, z, crop) in enumerate(beds):
        s.put(veg_bed(mat, crop, i), x, z, 0)
    for (x, z) in ((48, 117), (104, 99), (66, 59), (110, 18)):
        _spot(s, "veg_bed", x - 1.6, z, y=BED_TOP)
    s.put(nb.garden_shed(mat), 82.0, 84.0, -90)
    _spot(s, "trap_shed", *turned(82.0, 84.0, -90, -0.6, -3.3), turn=-90)
    s.put(water_butt(mat), 79.0, 78.0, 0)
    _spot(s, "water_butt", 80.5, 74.5)
    s.put(greenhouse(mat), 102.0, 80.0, 90)
    _spot(s, "greenhouse", *turned(102.0, 80.0, 90, 0, -0.6), y=GREENHOUSE_FLOOR)
    s.put(scarecrow(mat), 56.0, 108.0 - 8.5, 10)
    s.put(scarecrow(mat), 90.0 + 30.0, 130.0, 200)
    _spot(s, "scarecrow", 57.5, 96.0)
    for (x, z, r) in ((44.0, 70.0, 0), (128.0, 46.0, 0)):
        s.put(compost_bin(mat), x, z, r)
    _spot(s, "compost", 47.5, 70.0)
    s.put(potting_shed(mat), 98.0, 24.0, 90)
    _spot(s, "potting_bench", *turned(98.0, 24.0, 90, -1.4, -4.4))
    s.put(potting_shed(mat), 64.0, 130.0, 180)
    s.put(water_butt(mat), 69.0, 131.5, 0)
    s.put(sunflowers(mat, 5), 42.0, 28.0, 90)
    _spot(s, "sunflowers", 44.5, 24.0)
    s.put(sunflowers(mat, 4), 122.0, 134.0, 0)
    s.put(bench(mat), 96.0, 128.0, 180)
    _spot(s, "allot_bench", *turned(96.0, 128.0, 180, 0, -2.4))
    _spot(s, "allotments", 122.0, 88.0)
    _spot(s, "allotments", 60.0, 4.0)
    return lines


def _near(s, g, mat):
    """The verge between the town wall and S1, and the cars along the streets."""
    s.put(street_sign(mat, "WHISKER LANE"), 11.0, -124.0, 0)
    s.put(bus_stop(mat), -40.0, -125.0, 180)
    _spot(s, "bus_stop", -40.0, -125.0 + 0.6 - 0.0, y=BUS_SEAT)
    s.put(post_box(mat), 14.0, -128.0, 180)
    _spot(s, "post_box", 16.2, -128.0)
    for (x, r) in ((62.0, 180), (-78.0, 180)):
        s.put(bench(mat), x, -126.0, r)
    for x in (62.0, -78.0):
        _spot(s, "verge_bench", x, -123.6)
    s.put(nb.recycling_bins(mat), -28.0, -100.8, 0)
    _spot(s, "bins", -24.0, -100.8)
    for (x, z, r, sw) in ((80.0, S1_Z - 2.6, 90, "shirt_blue"), (-80.0, S3_Z - 2.6, -90, "pastel_butter"),
                          (72.0, S3_Z + 2.6, 90, "mint")):
        s.put(car(mat, sw), x, z, r, y=ROAD_Y)
    _spot(s, "car", 73.0, S1_Z - 7.2, y=PAVE_Y)
    # lamp posts along the pavements
    for (x, z) in ((-6.5, -128.0), (-80.0, -118.5), (-48.0, -105.5), (30.0, -118.5), (88.0, -105.5),  # on plot
                   (39.5, -90.0), (52.5, -68.0), (-74.0, -52.5), (-30.0, -39.5), (4.0, -52.5), (74.0, -39.5),  # lines,
                   (-52.5, -20.0), (-39.5, 10.0), (-52.5, 44.0), (24.5, 43.5)):                            # not gates
        s.put(nb.lamp_post(mat), x, z, 0, y=PAVE_Y)
    for th in (170.0, 112.0, 68.0, 10.0):
        s.put(nb.lamp_post(mat), *polar(CR + 6.5, th), 0, y=PAVE_Y + 0.003)
    # trees: the verge, the gaps' verges, the green, the gardens and allotments
    tb = Builder()
    for (x, z, h, k) in ((-110, -129, 10, 0), (-62, -130, 11, 1), (36, -130, 10, 2), (84, -129, 11, 0),
                         (116, -130, 10, 1), (-130, -126, 11, 2), (35, -95, 9, 1), (35, -66, 10, 0), (57, -80, 9, 2),
                         (-58, -26, 10, 0), (-34, -14, 9, 1), (-130, 0, 11, 1), (-128, 128, 12, 0), (-84, 104, 10, 2),
                         (130, 4, 10, 0), (124, 120, 11, 1), (44, 132, 10, 2), (128, 72, 10, 2), (-38, 40, 9, 0)):
        tree_round(tb, -x, z, 0, h=h, r=3.0 + 0.4 * k, leaf=("leaf_green", "leaf_dark", "mint")[k])
    s.put([tb.finalize(N + "Trees", mat)], 0, 0, 0)


def _barriers(s, mat, lines):
    """The blockers' invisible walls, 30 high: on each house block from the house fronts back (the first block's
    corner garden left open), and along the crescent's lines, open only at the two footpaths."""
    bar = Builder()
    rects = [(R1W[0], R1W[1], ROW1[0] + 7.8, ROW1[1] - 7.8), (R2W[0], R2W[1], ROW2[0] + 7.8, ROW2[1]),
             (R2E[0], R2E[1], ROW2[0] + 7.8, ROW2[1])]
    rects += rects_minus([(R1E[0], R1E[1], ROW1[0] + 7.8, ROW1[1] - 7.8)], [(113.9, IN + 1.0, ROW1[0] - 1.0, -80.0)])
    for (x0, x1, z0, z1) in rects:
        span(bar, x0, x1, z0, z1, 0, BARRIER_H, "offwhite")
    for line in lines:
        for p, q in zip(line, line[1:]):
            seg(bar, p, q, 0.6, 0, BARRIER_H, "offwhite")
    s.put([bar.finalize(N + "Blocks_Barrier", mat)], 0, 0, 0)


def build_set(mat):
    s = Set(SET)
    g = Builder()
    _ground(g)
    _walls(s, mat)
    _rows(s, g, mat)
    lines = _far(s, g, mat)
    _near(s, g, mat)
    _barriers(s, mat, lines)
    return s.finish(g, mat), s


def build_neighbourhood_set(mat):
    objs, _ = build_set(mat)
    return objs


ASSETS = {
    SET: (build_neighbourhood_set, 120000),
}
