"""The back yard's picket fence (hometown-cannon.md section 2: "each cafe's back yard: the back step with the bait
bowl, a little garden and a low fence 10 studs out from the back wall"). WorldBuilder builds the yard fence as three
plain parts (YardFence: FenceSide x2 and FenceBack); this is the same fence as art, for every cafe at the Plot pivot.

Plot space, Roblox axes (common.RB): x across the plot, y up from the cafe floor, z away from the street (+Z is the
back). The yard runs x -19 to 19 and z 15 to 25 (Layout.plot.yard); the side fences stand on x -18.9 and 18.9 and
the back fence on z 24.8, as the code fence's parts. White pickets face the yard, the rails run behind them, square
posts with caps and ball finials stand every 3.8 studs or so. Climbing roses on the back corners and a bird house
on the middle back post.

The `_Barrier` is the code fence's three parts exactly (sides 0.4 x 3.2 x 10 from 0.2 below the floor, back
38 x 3 x 0.4), invisible and solid, so the fence stops players where it did; of the art only the posts collide.
"""

import math

from mathutils import Matrix

from common import RB
from plot import BACK, HW, YARD

NAME = "CatCafe_Plot_YardFence"
SIDE_X = HW - 0.1            # 18.9 at today's 36 wide cafe
BACK_Z = BACK + YARD - 0.2   # 24.8 at today's 28 deep cafe
FIRST_Z = BACK + 0.7         # the side fences' first post, clear of the shell's corner trim (z 15.4)
BACK_SPANS = round(2 * SIDE_X / 3.78)                                   # 10 at 36 wide: a post every 3.8 or so
POST, POST_TOP = 0.45, 3.1
PICKET_W, PICKET_T, PICKET_TOP, PITCH = 0.36, 0.12, 2.7, 0.62
RAILS = ((0.55, 0.8), (2.05, 2.3))


def rot_about(axis, deg):
    return Matrix.Rotation(math.radians(deg), 3, axis)


def _post(b, x, z, base=-0.2):
    b.span((x - POST / 2, base, z - POST / 2), (x + POST / 2, POST_TOP, z + POST / 2), "offwhite")
    b.span((x - 0.3, POST_TOP, z - 0.3), (x + 0.3, POST_TOP + 0.12, z + 0.3), "cream")
    b.ball((x, POST_TOP + 0.12 + 0.15, z), 0.17, "offwhite")


def _run(b, a, c, fixed, along_x, inward):
    """Rails and pickets between two posts at a and c on a line (x = fixed for a side run, z = fixed for the back),
    pickets on the yard side (`inward` +1 or -1 along the other axis)."""
    lo, hi = min(a, c) + POST / 2, max(a, c) - POST / 2
    out0, out1 = fixed - inward * 0.14, fixed - inward * 0.02           # the rails, behind the pickets
    in0, in1 = fixed - inward * 0.02, fixed + inward * (PICKET_T - 0.02)

    def box(u0, u1, v0, v1, y0, y1, swatch):
        v0, v1 = min(v0, v1), max(v0, v1)
        if along_x:
            b.span((u0, y0, v0), (u1, y1, v1), swatch)
        else:
            b.span((v0, y0, u0), (v1, y1, u1), swatch)

    for y0, y1 in RAILS:
        box(lo, hi, out0, out1, y0, y1, "offwhite")
    n = max(1, int((hi - lo - 0.16) / PITCH + 1e-6))
    start = (lo + hi) / 2 - (n - 1) * PITCH / 2
    for k in range(n):
        u = start + k * PITCH
        box(u - PICKET_W / 2, u + PICKET_W / 2, in0, in1, 0.05, PICKET_TOP, "offwhite")
        mid = (in0 + in1) / 2
        d = PICKET_W / math.sqrt(2)                                     # the pointed top: a turned square
        if along_x:
            b.box((u, PICKET_TOP, mid), (d, d, PICKET_T - 0.02), "offwhite", rot=rot_about("Z", 45))
        else:
            b.box((mid, PICKET_TOP, u), (PICKET_T - 0.02, d, d), "offwhite", rot=rot_about("X", 45))


def _roses(b, x, z, sx, sz):
    """A climbing rose up a back corner post's two yard-facing faces: a green stem, leaf clumps and pink blooms."""
    fz = z + sz * (POST / 2 + 0.04)                                      # just off the face toward the yard (z)
    fx = x + sx * (POST / 2 + 0.04)                                      # and the one toward the plot's middle (x)
    b.span((x - 0.05, -0.1, fz - 0.045), (x + 0.05, 3.0, fz + 0.045), "leaf_green")
    b.span((fx - 0.045, -0.1, z - 0.05), (fx + 0.045, 2.6, z + 0.05), "leaf_green")
    for k, y in enumerate((0.45, 1.05, 1.65, 2.25, 2.8)):
        o = 0.1 if k % 2 else -0.1
        b.ball((x + o, y, fz + sz * 0.06), 0.2, "leaf_green", scale=(1.0, 0.8, 0.6))
        if y < 2.6:
            b.ball((fx + sx * 0.06, y + 0.2, z + o), 0.2, "leaf_green", scale=(0.6, 0.8, 1.0))
    for y, o, sw in ((1.25, 0.12, "blush"), (2.0, -0.12, "nose_pink"), (2.6, 0.1, "blush"), (3.05, 0.0, "nose_pink")):
        b.ball((x + o, y, fz + sz * 0.16), 0.15, sw)
    for y, o, sw in ((0.8, -0.1, "nose_pink"), (1.5, 0.1, "blush"), (2.25, -0.05, "blush")):
        b.ball((fx + sx * 0.16, y, z + o), 0.15, sw)


def _bird_house(b, x, z):
    """A little mint bird house on the middle back post, its round hole toward the yard."""
    y0 = POST_TOP + 0.12
    b.span((x - 0.32, y0, z - 0.3), (x + 0.32, y0 + 0.62, z + 0.3), "mint")
    b.cyl((x, y0 + 0.36, z - 0.31), 0.12, 0.04, "dark_wood", axis="Z", segments=10)
    b.span((x - 0.03, y0 + 0.12, z - 0.42), (x + 0.03, y0 + 0.18, z - 0.3), "dark_wood")             # perch
    for s in (-1, 1):
        b.box((x + s * 0.2, y0 + 0.78, z), (0.5, 0.06, 0.74), "blush", rot=rot_about("Z", -s * 35))  # roof
    b.span((x - 0.04, y0 + 0.88, z - 0.37), (x + 0.04, y0 + 0.96, z + 0.37), "blush")


def build_yard_fence(mat):
    b, bar = RB(), RB()
    back_xs = [-SIDE_X + k * (2 * SIDE_X) / BACK_SPANS for k in range(BACK_SPANS + 1)]
    side_zs = [FIRST_Z + k * (BACK_Z - FIRST_Z) / 3 for k in range(4)]
    for x in back_xs:
        _post(b, x, BACK_Z)
    for sx in (-1, 1):
        for z in side_zs[:-1]:
            _post(b, sx * SIDE_X, z)
        for z0, z1 in zip(side_zs, side_zs[1:]):
            _run(b, z0, z1, sx * SIDE_X, False, -sx)
    for x0, x1 in zip(back_xs, back_xs[1:]):
        _run(b, x0, x1, BACK_Z, True, -1)
    _roses(b, -SIDE_X, BACK_Z, 1, -1)
    _roses(b, SIDE_X, BACK_Z, -1, -1)
    _bird_house(b, 0.0, BACK_Z)
    for sx in (-1, 1):                                                   # the code fence's parts, to the stud
        bar.span((sx * SIDE_X - 0.2, -0.2, BACK), (sx * SIDE_X + 0.2, 3.0, BACK + YARD), "offwhite")
    bar.span((-HW, 0.0, BACK + YARD - 0.4), (HW, 3.0, BACK + YARD), "offwhite")
    return [b.finalize(NAME, mat), bar.finalize(NAME + "_Barrier", mat)]


ASSETS = {NAME: (build_yard_fence, 8000)}
