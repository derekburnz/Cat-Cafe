"""Cafe expansions (data-model section 6: expansion 1 at Tier 2, 2 at Tier 3, 3 at Tier 4, 4 at Tier 5).

Built in the plot's own space so each one is placed at the Plot's pivot (the floor top centre of the
base plot, -Z toward the street) with no offset. Positions below are written in Roblox plot-local
axes (x across the plot, y up, z away from the street) to match Layout.luau and converted to
Blender with _b. The base plot is 36 x 28 with 1-stud walls 9 tall outside the floor edge.

Back strips grow the cafe away from the street and are additive. Each has an arch on the line of
the wall it replaces (z = a), a floor from a - 0.5 to b - 0.5, side walls, and a _BackWall at z = b:
  Expansion1  a 14.5 (the base WallBack), b 21.5
  Expansion2  a 21.5, b 28.5
  Expansion4  a 28.5, b 36.5, a glass conservatory
When a strip is added, hide the wall it replaces: the base WallBack for Expansion1, Expansion1's
_BackWall for Expansion2, Expansion2's _BackWall for Expansion4.
Expansion3 is the patio on the street side (z -15..-20): deck, fence with a gap at the door,
a striped awning on the front wall and string lights (_Bulbs, Neon at night).
"""

from common import Builder

H = 9.0            # WallHeight
HALF_W = 18.0      # PlotWidth / 2
FLOOR_T = 0.4


def _b(x, y, z):
    """Roblox plot-local (x, y, z) to Blender (x, y, z): Roblox (x, y, z) = Blender (-x, z, y)."""
    return (-x, z, y)


def box(b, center, size, swatch, bevel=False):
    """Box from a Roblox centre and a Roblox size (x, y, z)."""
    b.box(_b(*center), (size[0], size[2], size[1]), swatch, bevel=bevel)


def _strip(b, glass, a, bw, first):
    """Floor, side walls with a window, and the arch on the line a of the wall this strip replaces."""
    f0, f1 = a - 0.5, bw - 0.5
    box(b, (0, -FLOOR_T / 2, (f0 + f1) / 2), (2 * HALF_W, FLOOR_T, f1 - f0), "caramel_wood")
    w0, w1 = (a - 0.5 if first else a + 0.5), bw + 0.5                                             # side wall span
    wz, ww = (a + bw) / 2, 4.0
    lo, hi = wz - ww / 2, wz + ww / 2
    for sx in (-1, 1):
        x = sx * (HALF_W + 0.5)
        box(b, (x, H / 2, (w0 + lo) / 2), (1, H, lo - w0), "cream")
        box(b, (x, H / 2, (hi + w1) / 2), (1, H, w1 - hi), "cream")
        box(b, (x, 1.25, wz), (1, 2.5, ww), "cream")                                              # under the window
        box(b, (x, H - 1.25, wz), (1, 2.5, ww), "cream")                                          # over it
        box(b, (x, 2.6, wz), (1.2, 0.2, ww + 0.4), "dark_wood")                                   # sill
        box(glass, (x, 4.5, wz), (0.3, 4.0, ww), "glass")
        box(b, (x - sx * 0.55, 0.3, (f0 + f1) / 2), (0.1, 0.6, f1 - f0), "dark_wood")              # baseboard
        box(b, (sx * (HALF_W - 1.5), H / 2, a), (3, H, 1), "cream")                                # arch stubs
        box(b, (sx * (HALF_W - 3.1), H / 2, a), (0.4, H, 1.2), "caramel_wood")
    box(b, (0, H - 0.75, a), (2 * HALF_W - 6, 1.5, 1), "cream")                                    # arch header
    box(b, (0, H - 1.6, a), (2 * HALF_W - 6, 0.25, 1.2), "caramel_wood")


def _back_wall(name, z, mat):
    w = Builder()
    box(w, (0, H / 2, z), (2 * HALF_W, H, 1), "cream")
    box(w, (0, 0.3, z - 0.55), (2 * HALF_W, 0.6, 0.1), "dark_wood")
    box(w, (0, 5.0, z - 0.56), (6, 3.0, 0.12), "mint")                                             # a framed panel
    box(w, (0, 5.0, z - 0.6), (5.4, 2.4, 0.04), "cream")
    return w.finalize(name, mat)


def build_expansion_back(n, a, bw, mat):
    name = f"CatCafe_Plot_Expansion{n}"
    b, glass = Builder(), Builder()
    _strip(b, glass, a, bw, first=n == 1)
    box(b, ((-9, 9)[n - 1], 0.02, (a + bw) / 2), (8, 0.04, 4), ("blush", "mint")[n - 1])         # rug
    return [b.finalize(name + "_Room", mat), glass.finalize(name + "_Glass", mat), _back_wall(name + "_BackWall", bw, mat)]


def build_conservatory(mat):
    """Expansion4: a glass room at the back. Frames are wood, panes are one _Glass object."""
    name = "CatCafe_Plot_Expansion4"
    a, bw = 28.5, 36.5
    b, glass = Builder(), Builder()
    f0, f1 = a - 0.5, bw - 0.5
    zc, d = (f0 + f1) / 2, f1 - f0
    box(b, (0, -FLOOR_T / 2, zc), (2 * HALF_W, FLOOR_T, d), "floor_tile")
    for k in range(-3, 4):                                                                         # tile stripes
        box(b, (k * 5.0, 0.01, zc), (2.5, 0.02, d - 1), "cream")
    for sx in (-1, 1):
        x = sx * (HALF_W + 0.5)
        box(b, (x, 0.75, (a + 0.5 + bw + 0.5) / 2), (1, 1.5, bw - a), "cream")                    # low wall
        for z in (a + 0.8, zc, bw):
            box(b, (x, H / 2, z), (0.6, H, 0.6), "dark_wood")                                      # posts
        box(b, (x, H - 0.3, zc), (0.6, 0.6, d), "dark_wood")
        box(glass, (x, (H + 1.5) / 2, zc), (0.2, H - 1.5, d), "glass")
        box(b, (sx * (HALF_W - 1.5), H / 2, a), (3, H, 1), "cream")                                # arch stubs
    box(b, (0, H - 0.75, a), (2 * HALF_W - 6, 1.5, 1), "cream")                                    # arch header
    box(b, (0, 0.75, bw), (2 * HALF_W + 2, 1.5, 1), "cream")                                       # back
    for k in range(-3, 4):
        box(b, (k * 6.0, H / 2, bw), (0.5, H, 0.6), "dark_wood")
    box(b, (0, H - 0.3, bw), (2 * HALF_W + 2, 0.6, 0.6), "dark_wood")
    box(glass, (0, (H + 1.5) / 2, bw), (2 * HALF_W, H - 1.5, 0.2), "glass")
    for k in range(-2, 3):                                                                         # roof beams
        box(b, (k * 7.0, H, zc), (0.4, 0.4, d), "dark_wood")
    for (x, z) in ((-14, f1 - 2), (14, f1 - 2), (-14, f0 + 2.5), (14, f0 + 2.5)):                 # potted plants
        b.cyl_base(_b(x, 0, z), 0.8, 1.2, "terracotta", segments=8, bevel=False)
        b.ico(_b(x, 2.0, z), 1.2, "leaf_green")
    return [b.finalize(name + "_Room", mat), glass.finalize(name + "_Glass", mat)]


def build_patio(mat):
    """Expansion3: the street-side patio in front of the cafe (Layout's patio spots sit on it)."""
    name = "CatCafe_Plot_Expansion3"
    z0, z1 = -15.0, -20.0                                                                          # wall face to fence
    b, bulbs = Builder(), Builder()
    zc, d = (z0 + z1) / 2, z0 - z1
    box(b, (0, -FLOOR_T / 2, zc), (2 * HALF_W, FLOOR_T, d), "caramel_wood")
    for k in range(1, 5):
        box(b, (0, 0.01, z0 - k), (2 * HALF_W, 0.02, 0.08), "dark_wood")                           # plank lines
    door_half = 3.5
    posts = [(x, z1) for x in (-18, -14, -10, -6, -door_half, door_half, 6, 10, 14, 18)]
    posts += [(sx * 18, z) for sx in (-1, 1) for z in (-16.5, -18)]
    for (x, z) in posts:
        box(b, (x, 1.4, z), (0.4, 2.8, 0.4), "offwhite")
    for sx in (-1, 1):
        span = HALF_W - door_half
        xc = sx * (door_half + span / 2)
        for y in (1.0, 2.5):
            box(b, (xc, y, z1), (span, 0.2, 0.2), "offwhite")                                      # front rails
            box(b, (sx * 18, y, zc), (0.2, 0.2, d), "offwhite")                                    # side rails
    for sx in (-1, 1):                                                                             # planters by the gap
        box(b, (sx * (door_half + 1.2), 0.6, z1 + 0.9), (1.6, 1.2, 1.0), "terracotta")
        b.ico(_b(sx * (door_half + 1.2), 1.5, z1 + 0.9), 0.8, "leaf_green")
    stripes = 12                                                                                   # awning over the front wall
    for i in range(stripes):
        x = -HALF_W + 2 * HALF_W * (i + 0.5) / stripes
        sw = ("mint", "cream")[i % 2]
        b.box(_b(x, 7.6, -16.2), (2 * HALF_W / stripes, 2.6, 0.12), sw, bevel=False,
              rot=(0.5, "X"))
        b.cyl(_b(x, 6.95, -17.45), HALF_W / stripes, 0.1, sw, segments=8, bevel=False, rot=(1.5708, "X"))
    for k in range(15):                                                                            # string lights
        x = -HALF_W + 1.2 + (2 * HALF_W - 2.4) * k / 14
        bulbs.sphere(_b(x, 6.6 - 0.25 * (1 - ((k % 5) - 2) ** 2 / 4), -17.5), 0.16, "lamp_warm", segments=6, rings=4)
    return [b.finalize(name + "_Patio", mat), bulbs.finalize(name + "_Bulbs", mat)]


ASSETS = {
    "CatCafe_Plot_Expansion1": (lambda m: build_expansion_back(1, 14.5, 21.5, m), 1500),
    "CatCafe_Plot_Expansion2": (lambda m: build_expansion_back(2, 21.5, 28.5, m), 1500),
    "CatCafe_Plot_Expansion3": (build_patio, 1500),
    "CatCafe_Plot_Expansion4": (build_conservatory, 1500),
}
