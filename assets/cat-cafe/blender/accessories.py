"""Cat accessories: small meshes that weld to a cat part at a named attachment point.

Each accessory's pivot is its attachment point, so in Studio: Motor6D or WeldConstraint
to the part named in ATTACH, with the accessory's pivot at that part-local offset.
The same offsets hold for an upright variant because they live on the Head and Body.
"""

import math

from common import Builder

# attachment name -> (cat part, offset local to that part's pivot, in studs, Blender axes)
# Quadruped (default) slots. Glasses and Hat ride the Head, so they are the same in every pose.
ATTACH = {
    "Glasses": ("Head", (0.0, -0.57, 0.2)),   # just in front of the face, eye height
    "Hat":     ("Head", (0.0, -0.18, 0.5)),   # head top center
    "BowTie":  ("Body", (0.0, -0.72, 0.95)),  # front of the collar
    "Apron":   ("Body", (0.0, -0.70, 1.0)),   # chest, hangs down the front
}


# Upright slots: when a cat stands (poses.POSES["upright"]) its belly faces forward, so the
# Body accessories move to the belly and turn +90 degrees about X (part-local) to stay upright.
# (part, offset, rotation_xyz_deg). Head slots are unchanged.
ATTACH_UPRIGHT = {
    "BowTie": ("Body", (0.0, -0.62, 0.38), (90, 0, 0)),
    "Apron":  ("Body", (0.0, -0.45, 0.38), (90, 0, 0)),
}


def build_glasses(mat):
    b = Builder()
    for x in (-0.2, 0.2):
        b.box((x, 0, 0), (0.3, 0.05, 0.3), "fur_black", bevel=False)                  # rims
        b.box((x, -0.005, 0), (0.22, 0.03, 0.22), "glass", bevel=False)              # lenses
    b.box((0, 0, 0.02), (0.14, 0.05, 0.05), "fur_black", bevel=False)               # bridge
    for x in (-0.37, 0.37):
        b.box((x, 0.3, 0.05), (0.05, 0.7, 0.05), "fur_black", bevel=False)          # arms back along the head
    return [b.finalize("CatCafe_Accessory_Glasses", mat)]


def build_bow_tie(mat):
    b = Builder()
    b.box((0, 0, 0), (0.14, 0.12, 0.14), "blush")                                  # knot
    b.box((-0.2, 0.02, 0), (0.3, 0.1, 0.26), "blush", rot=(math.radians(10), "Y"))
    b.box((0.2, 0.02, 0), (0.3, 0.1, 0.26), "blush", rot=(math.radians(-10), "Y"))
    return [b.finalize("CatCafe_Accessory_BowTie", mat)]


def build_apron(mat):
    b = Builder()
    b.box((0, 0, -0.32), (0.6, 0.06, 0.6), "mint")                                 # bib down the chest
    b.box((0, 0.0, 0.0), (0.7, 0.05, 0.08), "dark_wood", bevel=False)              # neck strap front
    b.box((0, -0.02, -0.45), (0.3, 0.03, 0.2), "cream", bevel=False)               # pocket
    return [b.finalize("CatCafe_Accessory_Apron", mat)]


def build_hat(mat):
    """A small beret-style cap."""
    b = Builder()
    b.cyl_base((0, 0, 0), 0.36, 0.1, "blush", segments=12)
    b.cyl_base((0, 0, 0.1), 0.3, 0.12, "blush", segments=12, radius2=0.2)
    b.sphere((0, 0, 0.26), 0.06, "dark_wood", segments=6, rings=4)
    return [b.finalize("CatCafe_Accessory_Hat", mat)]


ASSETS = {
    "CatCafe_Accessory_Glasses": (build_glasses, 200),
    "CatCafe_Accessory_BowTie": (build_bow_tie, 200),
    "CatCafe_Accessory_Apron": (build_apron, 200),
    "CatCafe_Accessory_Hat": (build_hat, 300),
}
