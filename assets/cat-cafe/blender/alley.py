"""Alley set. Spawn points sit beside these. Pivot base center, front -Y."""

import math

from common import Builder


def build_dumpster(mat):
    b = Builder()
    b.box_base((0, 0, 0.6), (6.0, 3.5, 2.8), "dumpster_green")
    b.box_base((0, 0, 3.3), (6.1, 3.6, 0.15), "concrete_dark")                # rim
    for x in (-2.6, 2.6):
        for y in (-1.3, 1.3):
            b.cyl((x, y, 0.3), 0.3, 0.3, "concrete_dark", segments=10, rot=(math.radians(90), "Y"))
    for x in (-3.05, 3.05):
        b.box((x, 0, 1.6), (0.3, 2.0, 0.6), "metal")                            # fork pockets
    b.box((0, -1.76, 1.2), (4.0, 0.04, 0.5), "rust", bevel=False)              # rust streak
    b.box((0, -1.76, 2.5), (2.0, 0.04, 0.8), "offwhite", bevel=False)          # faded label
    b.box_base((1.5, 0, 3.45), (2.9, 3.6, 0.2), "concrete_dark")                # closed lid half
    # open lid half hinged at the back (+Y), tilted up 60 degrees
    a = math.radians(60)
    cy, cz = 1.8 - 1.8 * math.cos(a), 3.55 + 1.8 * math.sin(a)
    b.box((-1.5, cy, cz), (2.9, 3.6, 0.2), "concrete_dark", rot=(a, "X"))
    b.box((-1.5, 0.4, 3.75), (1.0, 1.0, 0.9), "cardboard", rot=(math.radians(20), "Z"))   # box poking out
    b.sphere((-2.4, -0.6, 3.6), 0.3, "fur_black", segments=8, rings=5)         # trash bag
    return [b.finalize("CatCafe_Alley_Dumpster", mat)]


def build_trash_can(mat):
    b = Builder()
    b.cyl_base((0, 0, 0), 0.7, 2.2, "metal", segments=12, radius2=0.8)
    for z in (0.6, 1.2, 1.8):
        b.ring((0, 0, z), 0.86, 0.1, 0.1, "concrete", segments=12, bevel=False)
    b.cyl_base((0, 0, 2.2), 0.86, 0.2, "metal", segments=12)
    b.box((0, 0, 2.5), (0.5, 0.14, 0.14), "concrete_dark")
    b.box((0, -0.82, 1.0), (0.6, 0.04, 0.3), "rust", bevel=False)
    return [b.finalize("CatCafe_Alley_TrashCan", mat)]


def build_street_lamp(mat):
    """Post + Bulb objects; Bulb gets Neon and a SpotLight in Studio."""
    post = Builder()
    post.cyl_base((0, 0, 0), 0.38, 0.5, "concrete_dark", segments=10)
    post.cyl_base((0, 0, 0.5), 0.15, 8.8, "fur_black", segments=10, radius2=0.12)
    post.box((0, -0.8, 9.3), (0.2, 1.6, 0.2), "fur_black")
    post.box((0, -1.5, 9.25), (0.9, 0.9, 0.5), "fur_black")
    bulb = Builder()
    bulb.box((0, -1.5, 8.85), (0.6, 0.6, 0.3), "lamp_warm", bevel=False)
    return [post.finalize("CatCafe_Alley_StreetLamp_Post", mat), bulb.finalize("CatCafe_Alley_StreetLamp_Bulb", mat)]


def build_crate(mat):
    b = Builder()
    for x in (-0.68, 0.68):
        for y in (-0.68, 0.68):
            b.box_base((x, y, 0), (0.15, 0.15, 1.5), "dark_wood", bevel=False)
    for z in (0.2, 0.65, 1.1):
        for sgn in (-1, 1):
            b.box((0, sgn * 0.72, z + 0.15), (1.5, 0.08, 0.3), "caramel_wood", bevel=False)
            b.box((sgn * 0.72, 0, z + 0.15), (0.08, 1.5, 0.3), "caramel_wood", bevel=False)
    for x in (-0.5, 0.0, 0.5):
        b.box((x, 0, 1.46), (0.4, 1.5, 0.08), "caramel_wood", bevel=False)
    b.box_base((0, 0, 0.02), (1.4, 1.4, 0.1), "caramel_wood", bevel=False)
    b.box((0, -0.77, 0.8), (0.5, 0.02, 0.3), "rust", bevel=False)
    return [b.finalize("CatCafe_Alley_Crate", mat)]


def build_cardboard_box(mat):
    b = Builder()
    b.box_base((0, 0, 0), (1.5, 1.5, 1.2), "cardboard")
    a = math.radians(25)
    for sx in (-1, 1):
        c = (sx * (0.75 + 0.35 * math.cos(a)), 0, 1.2 + 0.35 * math.sin(a))
        b.box(c, (0.7, 1.5, 0.05), "cardboard", bevel=False, rot=(-sx * a, "Y"))
    for sy in (-1, 1):
        c = (0, sy * (0.75 + 0.35 * math.cos(a)), 1.2 + 0.35 * math.sin(a))
        b.box(c, (1.5, 0.7, 0.05), "cardboard", bevel=False, rot=(sy * a, "X"))
    b.box((0, -0.76, 0.6), (0.5, 0.02, 0.35), "offwhite", bevel=False)
    return [b.finalize("CatCafe_Alley_CardboardBox", mat)]


def build_pallet(mat):
    b = Builder()
    for x in (-1.2, -0.6, 0.0, 0.6, 1.2):
        b.box_base((x, 0, 0.22), (0.45, 3.0, 0.08), "cardboard", bevel=False)
    for y in (-1.3, 0.0, 1.3):
        b.box_base((0, y, 0.08), (3.0, 0.3, 0.14), "rust", bevel=False)
    for x in (-1.2, 0.0, 1.2):
        b.box_base((x, 0, 0), (0.45, 3.0, 0.08), "cardboard", bevel=False)
    return [b.finalize("CatCafe_Alley_Pallet", mat)]


def build_puddle(mat):
    b = Builder()
    b.cyl_base((0, 0, 0), 1.3, 0.03, "puddle", segments=14, bevel=False, scale=(1, 0.65, 1))
    b.cyl_base((0.6, -0.2, 0.005), 0.6, 0.03, "puddle", segments=10, bevel=False, scale=(1, 0.8, 1))
    return [b.finalize("CatCafe_Alley_Puddle", mat)]


def build_stuck_tree(mat):
    """Street tree with one thick low branch a cat clings to. Pivot base center.
    Stuck pose: see poses.STUCK_POSES["CatCafe_Alley_StuckTree"]."""
    b = Builder()
    b.cyl_base((0, 0, 0), 0.55, 5.2, "fur_brown", segments=10, radius2=0.4)
    b.box((1.5, 0, 4.1), (3.2, 0.5, 0.5), "fur_brown", rot=(math.radians(8), "Y"))            # branch toward +X
    b.box((-0.9, 0.3, 3.4), (1.6, 0.4, 0.4), "fur_brown", rot=(math.radians(-25), "Y"))
    b.ico((0, 0, 6.3), 1.7, "leaf_green")
    b.ico((1.0, 0.5, 5.6), 1.1, "leaf_dark")
    b.ico((-1.1, -0.4, 5.7), 1.0, "leaf_green")
    b.cyl_base((0, 0, 0), 1.0, 0.25, "concrete_dark", segments=12, bevel=False)            # tree pit
    return [b.finalize("CatCafe_Alley_StuckTree", mat)]


def build_stuck_box(mat):
    """Cardboard box on its side, opening toward -Y; a cat gets its head stuck inside.
    Five slabs, no lid, so the head is hidden by the walls."""
    b = Builder()
    w, d, h, t = 1.7, 1.6, 1.95, 0.06
    cy = 0.65
    b.box((0, cy, t / 2), (w, d, t), "cardboard", bevel=False)                                  # floor
    b.box((0, cy, h - t / 2), (w, d, t), "cardboard", bevel=False)                              # top
    b.box((-w / 2 + t / 2, cy, h / 2), (t, d, h), "cardboard", bevel=False)
    b.box((w / 2 - t / 2, cy, h / 2), (t, d, h), "cardboard", bevel=False)
    b.box((0, cy + d / 2 - t / 2, h / 2), (w, t, h), "cardboard", bevel=False)                  # back
    b.box((0, cy - d / 2 - 0.3, h - 0.03), (w, 0.6, t), "cardboard", bevel=False, rot=(math.radians(-30), "X"))  # top flap
    b.box((-w / 2 - 0.3, cy - d / 2 + 0.3, h / 2), (0.6, t, h), "cardboard", bevel=False, rot=(math.radians(20), "Z"))
    b.box((0, cy + d / 2 + 0.01, h * 0.55), (0.6, 0.02, 0.4), "offwhite", bevel=False)          # label on the back
    return [b.finalize("CatCafe_Alley_StuckBox", mat)]


def build_drainpipe(mat):
    """Wall drainpipe with an elbow at the bottom opening toward -Y. Pivot at the wall,
    back-bottom center. A cat sits inside the elbow with its head poking out."""
    b = Builder()
    r = 0.78
    b.cyl_base((0, -r, 1.3), r * 0.8, 7.0, "concrete_dark", segments=12)                      # riser
    for z in (3.0, 6.5):
        b.ring((0, -r, z), r * 0.85, 0.1, 0.2, "metal", segments=10, bevel=False)              # brackets
        b.box((0, -r / 2, z), (0.3, r, 0.15), "metal", bevel=False)
    b.sphere((0, -r, 1.3), r, "concrete_dark", segments=10, rings=6)                           # elbow
    b.cyl((0, -r - 0.9, r), r, 1.8, "concrete_dark", segments=12, rot=(math.radians(90), "X")) # outlet, open end at -Y
    b.ring((0, -r - 1.8, r), r + 0.06, 0.12, 0.12, "metal", segments=12, bevel=False, rot=(math.radians(90), "X"))
    b.cyl_base((0, -r - 1.2, 0), 1.0, 0.03, "puddle", segments=12, bevel=False, scale=(1.3, 1, 1))  # drip puddle
    return [b.finalize("CatCafe_Alley_Drainpipe", mat)]


def build_shop_window(mat):
    """Cafe street window that glows at night. Frame + Pane objects; the Pane is glass by
    day (Transparency 0.5) and Neon lamp_warm at night. Pivot at the wall, back-bottom center."""
    frame = Builder()
    frame.box((0, -0.03, 1.75), (4.0, 0.06, 3.1), "night_sky", bevel=False)                  # back plate (hidden by the pane)
    for c, sz in (((-2.1, -0.15, 1.75), (0.2, 0.3, 3.5)), ((2.1, -0.15, 1.75), (0.2, 0.3, 3.5)),
                  ((0, -0.15, 0.1), (4.4, 0.3, 0.2)), ((0, -0.15, 3.4), (4.4, 0.3, 0.2))):
        frame.box(c, sz, "dark_wood")                                                          # border
    frame.box((0, -0.35, 0.05), (4.8, 0.7, 0.1), "cream")                                      # sill
    frame.box((0, -0.3, 3.6), (4.8, 0.6, 0.2), "cream")                                        # lintel
    frame.box((0, -0.24, 1.75), (0.12, 0.08, 3.1), "dark_wood", bevel=False)                   # mullion
    frame.box((0, -0.24, 1.75), (4.0, 0.08, 0.12), "dark_wood", bevel=False)
    pane = Builder()
    pane.box((0, -0.12, 1.75), (4.0, 0.04, 3.1), "lamp_warm", bevel=False)
    return [frame.finalize("CatCafe_Alley_ShopWindow_Frame", mat), pane.finalize("CatCafe_Alley_ShopWindow_Pane", mat)]


ASSETS = {
    "CatCafe_Alley_StuckTree": (build_stuck_tree, 800),
    "CatCafe_Alley_StuckBox": (build_stuck_box, 300),
    "CatCafe_Alley_Drainpipe": (build_drainpipe, 800),
    "CatCafe_Alley_ShopWindow": (build_shop_window, 500),
    "CatCafe_Alley_Dumpster": (build_dumpster, 1200),
    "CatCafe_Alley_TrashCan": (build_trash_can, 800),
    "CatCafe_Alley_StreetLamp": (build_street_lamp, 800),
    "CatCafe_Alley_Crate": (build_crate, 800),
    "CatCafe_Alley_CardboardBox": (build_cardboard_box, 800),
    "CatCafe_Alley_Pallet": (build_pallet, 800),
    "CatCafe_Alley_Puddle": (build_puddle, 300),
}
