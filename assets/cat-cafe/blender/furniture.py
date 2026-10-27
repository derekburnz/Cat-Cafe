"""Counter (hero), espresso machine levels, cat spots, table and chair.

Every spot asset has a visible sit pad; its local sit point (where the cat's
base pivot goes) is in SIT_POINTS and in exports/manifest.json.
"""

import math

from mathutils import Matrix

from common import Builder

SIT_POINTS = {
    "CatCafe_Furniture_Cushion": (0, 0, 0.46),
    "CatCafe_Furniture_WallShelf": (0, -0.6, 0.12),
    "CatCafe_Furniture_CatTree": (0.5, -0.4, 4.45),
    "CatCafe_Furniture_WindowSeat": (0, -0.1, 1.6),
    "CatCafe_Furniture_PatioBench": (0, -0.1, 1.37),
    "CatCafe_Furniture_Counter": (2.0, 0.0, 3.0),
    "CatCafe_Furniture_GreeterPodium": (1.6, 0.0, 0.24),     # role stations: the cat stands upright here
    "CatCafe_Furniture_StageCatTree": (0.0, -0.3, 0.44),
}


def _sit_pad(b, p, swatch="mint", r=0.55):
    b.cyl_base((p[0], p[1], p[2] - 0.02), r, 0.04, swatch, segments=12, bevel=False)


def build_counter(mat):
    b = Builder()
    b.box_base((0, 0.1, 0), (7.8, 2.0, 0.25), "dark_wood")                    # toe kick
    b.box_base((0, 0.1, 0.25), (8.0, 2.2, 2.55), "caramel_wood")              # body
    for x in (-2.8, -1.4, 0.0, 1.4, 2.8):
        b.box((x, -1.02, 1.55), (1.1, 0.06, 1.9), "cream", bevel=False)        # front panels
    b.box_base((0, 0, 2.8), (8.4, 2.6, 0.2), "cream")                         # top slab
    b.box((0, -1.31, 2.9), (8.4, 0.04, 0.2), "offwhite", bevel=False)         # front trim
    # display case, right side
    b.box_base((2.4, -0.3, 3.0), (2.6, 1.2, 1.1), "glass")
    for dx in (-1.3, 1.3):
        for dy in (-0.6, 0.6):
            b.box_base((2.4 + dx, -0.3 + dy, 3.0), (0.1, 0.1, 1.15), "dark_wood", bevel=False)
    b.box_base((2.4, -0.3, 4.1), (2.7, 1.3, 0.1), "offwhite")
    b.cyl_base((1.8, -0.3, 3.0), 0.08, 0.3, "offwhite", segments=8, bevel=False)
    b.cyl_base((1.8, -0.3, 3.3), 0.45, 0.06, "offwhite", segments=12, bevel=False)
    b.cyl_base((1.8, -0.3, 3.36), 0.36, 0.3, "blush", segments=12)             # cake
    b.cyl_base((1.8, -0.3, 3.66), 0.36, 0.06, "cream", segments=12, bevel=False)
    for i, x in enumerate((2.7, 3.1, 3.5)):
        b.cyl_base((x, -0.6 + (i % 2) * 0.5, 3.0), 0.16, 0.22, "treat_tan", segments=8, bevel=False)
        b.sphere((x, -0.6 + (i % 2) * 0.5, 3.3), 0.16, "blush" if i != 1 else "mint", segments=8, rings=5)
    # register, left of center
    b.box_base((-1.2, 0.3, 3.0), (1.0, 0.8, 0.45), "mint")
    b.box((-1.2, 0.55, 3.75), (0.8, 0.1, 0.5), "dark_wood", rot=(math.radians(-15), "X"))
    b.box((-1.2, 0.0, 3.47), (0.6, 0.3, 0.05), "offwhite", bevel=False)      # keypad
    # tip jar and napkins
    b.cyl_base((-0.2, -0.6, 3.0), 0.2, 0.5, "glass", segments=10)
    b.cyl_base((-0.2, -0.6, 3.0), 0.18, 0.15, "rarity_legend", segments=10, bevel=False)
    b.box_base((0.6, -0.6, 3.0), (0.4, 0.4, 0.15), "offwhite")
    # cat sit pad on the free left end of the counter top
    _sit_pad(b, (-3.0, 0.0, 3.0), "blush", 0.6)
    return [b.finalize("CatCafe_Furniture_Counter", mat)]


def build_espresso(level, mat):
    b = Builder()
    body = "mint" if level == 1 else ("mint" if level == 2 else "cream")
    h = 1.0 if level < 3 else 1.3
    w = 1.4 if level < 3 else 2.0
    b.box_base((0, 0, 0), (w, 1.0, 0.2), "metal")                              # base plate
    b.box_base((0, 0, 0.2), (w, 0.9, h), body)                                  # body
    b.box_base((0, 0, 0.2 + h), (w, 0.9, 0.2), "metal" if level >= 2 else "concrete_dark")   # top
    if level >= 2:
        b.box((0, -0.46, 0.2 + h / 2), (w - 0.1, 0.04, 0.2), "metal", bevel=False)  # chrome band
        b.cyl_base((0, 0, 0.4 + h), 0.25, 0.1, "metal", segments=12)              # gauge
    heads = [0.0] if level < 3 else [-0.5, 0.5]
    cups = Builder()                                   # _Steam: the effects code puffs steam from these
    for x in heads:
        b.box((x, -0.55, 0.55), (0.5, 0.3, 0.3), "metal")                        # group head
        b.cyl((x, -0.9, 0.5), 0.06, 0.5, "dark_wood", segments=8, rot=(math.radians(90), "X"))  # portafilter handle
        cups.cyl_base((x, -0.7, 0.2), 0.16, 0.25, "offwhite", segments=10, bevel=False)        # cup
    b.box((0, -0.35, 0.2), (w - 0.4, 0.4, 0.06), "concrete_dark", bevel=False)  # drip tray
    wands = [w / 2 + 0.05] if level < 3 else [w / 2 + 0.05, -w / 2 - 0.05]
    for x in wands:
        b.cyl((x, -0.3, 0.75), 0.05, 0.7, "metal", segments=8, rot=(math.radians(25), "Y"))
    for x in (-0.3, 0.3):
        b.cyl((x * (w / 1.4), -0.47, 0.35 + h / 2 + 0.2), 0.1, 0.1, "dark_wood" if level < 3 else "rarity_legend",
              segments=10, rot=(math.radians(90), "X"))                          # knobs
    name = f"CatCafe_Furniture_EspressoMachine_L{level}"
    return [b.finalize(name, mat), cups.finalize(name + "_Steam", mat)]


def build_cushion(mat):
    b = Builder()
    b.cyl_base((0, 0, 0), 0.9, 0.4, "blush", segments=16)
    b.cyl_base((0, 0, 0.3), 0.62, 0.14, "cream", segments=16)
    _sit_pad(b, SIT_POINTS["CatCafe_Furniture_Cushion"], "mint", 0.5)
    return [b.finalize("CatCafe_Furniture_Cushion", mat)]


def build_wall_shelf(mat):
    """Pivot at the wall: back-bottom center. Shelf extends toward -Y."""
    b = Builder()
    b.box((0, -0.6, 0.06), (3.0, 1.2, 0.12), "caramel_wood")
    for x in (-1.1, 1.1):
        b.wedge((x, -0.5, -0.3), (0.12, 1.0, 0.6), "dark_wood")
    b.cyl_base((-1.1, -0.35, 0.12), 0.15, 0.25, "offwhite", segments=8, bevel=False)
    b.cyl_base((1.1, -0.3, 0.12), 0.2, 0.35, "terracotta", segments=8)
    b.ico((1.1, -0.3, 0.6), 0.22, "leaf_green")
    _sit_pad(b, SIT_POINTS["CatCafe_Furniture_WallShelf"], "mint", 0.5)
    return [b.finalize("CatCafe_Furniture_WallShelf", mat)]


def build_cat_tree(mat):
    b = Builder()
    b.box_base((0, 0, 0), (2.0, 2.0, 0.2), "caramel_wood")
    b.cyl_base((-0.5, 0.3, 0.2), 0.2, 2.0, "caramel_wood", segments=10)
    for z in (0.7, 1.5):
        b.ring((-0.5, 0.3, z), 0.24, 0.06, 0.3, "cardboard", segments=10, bevel=False)   # sisal wraps
    b.box_base((-0.5, 0.3, 2.2), (1.4, 1.4, 0.15), "mint")
    b.box_base((0.5, -0.4, 0.2), (1.2, 1.2, 1.0), "cream")                     # cube house
    b.cyl((0.5, -1.01, 0.7), 0.35, 0.04, "dark_wood", segments=12, bevel=False, rot=(math.radians(90), "X"))  # door
    b.cyl_base((0.5, -0.4, 1.2), 0.2, 3.1, "caramel_wood", segments=10)
    for z in (1.7, 2.6, 3.5):
        b.ring((0.5, -0.4, z), 0.24, 0.06, 0.3, "cardboard", segments=10, bevel=False)
    b.box_base((0.5, -0.4, 4.3), (1.3, 1.3, 0.15), "blush")
    b.sphere((-0.5, 0.3, 2.55), 0.15, "rarity_legend", segments=8, rings=5)   # dangling toy ball
    _sit_pad(b, SIT_POINTS["CatCafe_Furniture_CatTree"], "mint", 0.5)
    return [b.finalize("CatCafe_Furniture_CatTree", mat)]


def build_window_seat(mat):
    """Bench under a window. Wall side is +Y. Pivot base center."""
    b = Builder()
    b.box_base((0, 0, 0), (4.0, 1.4, 1.3), "caramel_wood")
    b.box_base((0, 0, 1.3), (3.9, 1.3, 0.3), "mint")
    for x in (-1.3, 1.3):
        b.box((x, 0.45, 1.85), (0.9, 0.3, 0.7), "blush", rot=(math.radians(-12), "X"))     # throw pillows
    b.box((0, 0.55, 1.9), (4.0, 0.3, 0.6), "cream")                           # window sill
    _sit_pad(b, SIT_POINTS["CatCafe_Furniture_WindowSeat"], "blush", 0.55)
    return [b.finalize("CatCafe_Furniture_WindowSeat", mat)]


def build_bench(name, seat="caramel_wood", frame="dark_wood", cushion="mint", mat=None, slats=True):
    b = Builder()
    for x in (-1.75, 1.75):
        b.box_base((x, 0, 0), (0.25, 1.3, 1.3), frame)
    if slats:
        for y in (-0.45, -0.15, 0.15, 0.45):
            b.box_base((0, y, 1.2), (4.0, 0.26, 0.15), seat)
        for z in (1.8, 2.25, 2.7):
            b.box((0, 0.65, z), (4.0, 0.15, 0.3), seat)
    else:
        b.box_base((0, 0, 1.2), (4.0, 1.3, 0.2), seat)
        b.box_base((0, 0, 1.4), (3.8, 1.1, 0.12), cushion)
        b.box((0, 0.65, 2.2), (4.0, 0.2, 1.4), seat)
    for x in (-1.75, 1.75):
        b.box((x, 0.65, 2.2), (0.25, 0.25, 1.6), frame)
    return b


def build_patio_bench(mat):
    b = build_bench("CatCafe_Furniture_PatioBench")
    _sit_pad(b, SIT_POINTS["CatCafe_Furniture_PatioBench"], "blush", 0.55)
    return [b.finalize("CatCafe_Furniture_PatioBench", mat)]


def build_table_round(mat):
    b = Builder()
    b.cyl_base((0, 0, 0), 0.8, 0.12, "dark_wood", segments=16)
    b.cyl_base((0, 0, 0.12), 0.2, 2.3, "dark_wood", segments=10)
    b.cyl_base((0, 0, 2.4), 1.75, 0.2, "cream", segments=16)
    b.ring((0, 0, 2.5), 1.8, 0.12, 0.2, "caramel_wood", segments=16, bevel=False)
    return [b.finalize("CatCafe_Furniture_TableRound", mat)]


def build_chair(mat):
    b = Builder()
    for x in (-0.6, 0.6):
        for y in (-0.6, 0.6):
            b.box_base((x, y, 0), (0.16, 0.16, 1.3), "dark_wood")
    b.box_base((0, 0, 1.3), (1.5, 1.5, 0.15), "caramel_wood")
    b.box_base((0, 0, 1.45), (1.3, 1.3, 0.12), "mint")
    for x in (-0.6, 0.6):
        b.box_base((x, 0.67, 1.4), (0.16, 0.16, 1.6), "dark_wood")
    for z in (2.15, 2.7):
        b.box((0, 0.67, z), (1.3, 0.12, 0.3), "caramel_wood")
    return [b.finalize("CatCafe_Furniture_Chair", mat)]


def build_greeter_podium(mat):
    """Greeter station: a host stand with the reservation book, and a round stand pad beside it
    (+X) where the greeter cat stands upright in its sash. Pivot base center of the stand."""
    b = Builder()
    b.box_base((0, 0, 0), (1.3, 0.95, 0.12), "dark_wood")                                     # foot
    b.box_base((0, 0, 0.12), (1.1, 0.75, 1.85), "caramel_wood")                               # column
    b.box((0, -0.385, 1.15), (0.8, 0.02, 1.1), "cream", bevel=False)                          # front panel
    b.cyl((0, -0.4, 1.1), 0.17, 0.03, "blush", segments=10, bevel=False, rot=(math.radians(90), "X"))  # paw pad
    for (x, z) in ((-0.2, 1.38), (-0.07, 1.46), (0.07, 1.46), (0.2, 1.38)):
        b.cyl((x, -0.4, z), 0.065, 0.03, "blush", segments=8, bevel=False, rot=(math.radians(90), "X"))
    b.box((0, -0.05, 2.1), (1.5, 1.1, 0.12), "dark_wood", rot=(math.radians(15), "X"))       # slanted desk
    b.box((0, -0.12, 2.2), (1.4, 0.07, 0.07), "dark_wood", bevel=False)                       # book stop
    for x, a in ((-0.27, -6), (0.27, 6)):                                                     # open book
        b.box((x, -0.02, 2.2), (0.52, 0.66, 0.05), "offwhite", bevel=False,
              rot=Matrix.Rotation(math.radians(15), 3, "X") @ Matrix.Rotation(math.radians(a), 3, "Y"))
    b.box((0.05, -0.36, 2.07), (0.06, 0.06, 0.3), "bowl_red", bevel=False)                    # ribbon
    b.cyl_base((0.55, 0.3, 2.25), 0.14, 0.12, "rarity_legend", segments=8, radius2=0.05)      # desk bell
    b.sphere((0.55, 0.3, 2.4), 0.04, "rarity_legend", segments=6, rings=4)
    p = SIT_POINTS["CatCafe_Furniture_GreeterPodium"]
    b.cyl_base((p[0], p[1], 0), 0.75, 0.2, "caramel_wood", segments=12)                      # stand pad
    _sit_pad(b, p, "blush", 0.62)
    return [b.finalize("CatCafe_Furniture_GreeterPodium", mat)]


def build_stage_cat_tree(mat):
    """Entertainer station: a round stage with footlights and a short cat tree behind it topped
    by a gold star. The entertainer stands upright at the front of the stage. Stage + Bulbs
    objects: the footlight Bulbs go Neon at night. Pivot base center of the stage."""
    b = Builder()
    b.cyl_base((0, 0, 0), 1.8, 0.4, "caramel_wood", segments=16)
    b.ring((0, 0, 0.36), 1.82, 0.1, 0.08, "neon_pink", segments=16, bevel=False)              # trim
    b.cyl_base((0, 0, 0.4), 1.6, 0.04, "blush", segments=16, bevel=False)                     # felt top
    b.cyl_base((0, 1.25, 0.44), 0.2, 3.5, "treat_tan", segments=8)                            # sisal post
    for z in (1.1, 2.1, 3.1):
        b.cyl((0, 1.25, z), 0.22, 0.08, "caramel_wood", segments=8, bevel=False)              # rope bands
    b.cyl_base((0, 1.25, 2.3), 0.65, 0.16, "caramel_wood", segments=10)                       # mid platform
    b.cyl_base((0, 1.25, 2.46), 0.55, 0.12, "mint", segments=10, bevel=False)
    b.cyl_base((0, 1.25, 3.94), 0.55, 0.16, "caramel_wood", segments=10)                      # top platform
    b.star((0, 1.25, 4.75), 0.55, 0.24, 0.16, "rarity_legend", rot=(math.radians(90), "X"))   # star topper
    b.cyl_base((0, 1.25, 4.1), 0.05, 0.25, "dark_wood", segments=6, bevel=False)
    for (x, z, r) in ((-0.9, 3.3, 0.18), (0.95, 2.9, 0.14)):                                  # hanging stars
        b.cyl((x, 1.25, z + 0.5), 0.015, 0.8, "fur_black", segments=4, bevel=False)
        b.star((x, 1.25, z), r, r * 0.45, 0.06, "sparkle", rot=(math.radians(90), "X"))
    b.cyl((0.75, 1.25, 3.6), 0.02, 1.5, "dark_wood", segments=4, bevel=False, rot=(math.radians(90), "Y"))
    b.cyl((-0.75, 1.25, 4.0), 0.02, 1.5, "dark_wood", segments=4, bevel=False, rot=(math.radians(90), "Y"))
    bulbs = Builder()
    for k in range(7):                                                                         # footlights along the front edge
        a = math.radians(-160 + 140 * k / 6)
        bulbs.sphere((1.68 * math.cos(a), 1.68 * math.sin(a), 0.5), 0.1, "lamp_warm", segments=6, rings=4)
    return [b.finalize("CatCafe_Furniture_StageCatTree_Stage", mat), bulbs.finalize("CatCafe_Furniture_StageCatTree_Bulbs", mat)]


ASSETS = {
    "CatCafe_Furniture_Counter": (build_counter, 3000),
    "CatCafe_Furniture_EspressoMachine_L1": (lambda m: build_espresso(1, m), 800),
    "CatCafe_Furniture_EspressoMachine_L2": (lambda m: build_espresso(2, m), 800),
    "CatCafe_Furniture_EspressoMachine_L3": (lambda m: build_espresso(3, m), 1000),
    "CatCafe_Furniture_Cushion": (build_cushion, 500),
    "CatCafe_Furniture_WallShelf": (build_wall_shelf, 800),
    "CatCafe_Furniture_CatTree": (build_cat_tree, 1200),
    "CatCafe_Furniture_WindowSeat": (build_window_seat, 800),
    "CatCafe_Furniture_PatioBench": (build_patio_bench, 800),
    "CatCafe_Furniture_TableRound": (build_table_round, 800),
    "CatCafe_Furniture_Chair": (build_chair, 800),
    "CatCafe_Furniture_GreeterPodium": (build_greeter_podium, 800),
    "CatCafe_Furniture_StageCatTree": (build_stage_cat_tree, 1400),
}
