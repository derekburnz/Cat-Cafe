"""Park set (features.md priority 9). Pivot base center, front -Y."""

import math

from common import Builder
from furniture import build_bench


def build_park_bench(mat):
    b = build_bench("CatCafe_Park_Bench", seat="caramel_wood", frame="concrete_dark")
    return [b.finalize("CatCafe_Park_Bench", mat)]


def build_tree(mat):
    b = Builder()
    b.cyl_base((0, 0, 0), 0.5, 4.0, "fur_brown", segments=10, radius2=0.35)
    b.ico((0, 0, 5.2), 2.0, "leaf_green")
    b.ico((1.2, 0.4, 4.4), 1.3, "leaf_dark")
    b.ico((-1.1, -0.5, 4.6), 1.2, "leaf_green")
    b.ico((0.2, -1.0, 6.3), 1.1, "leaf_dark")
    return [b.finalize("CatCafe_Park_Tree", mat)]


def build_rescue_tree(mat):
    """Rescue trap (tree, shake_catch). Trunk + Branch objects: the Branch pivots at its root
    on the trunk so it can wobble; weld the stuck cat to the Branch. Pivot base center."""
    t = Builder()
    t.cyl_base((0, 0, 0), 0.55, 6.0, "fur_brown", segments=10, radius2=0.4)
    t.box((-0.9, 0.3, 3.5), (1.6, 0.4, 0.4), "fur_brown", rot=(math.radians(-25), "Y"))
    t.ico((0, 0, 7.1), 1.7, "leaf_green")
    t.ico((-1.1, -0.4, 6.4), 1.0, "leaf_green")
    t.ico((0.6, 0.7, 6.4), 0.9, "leaf_dark")
    t.cyl_base((0, 0, 0), 1.0, 0.12, "leaf_dark", segments=12, bevel=False)                   # grass ring
    root = (0.3, 0.0, 4.0)
    br = Builder()                                                                             # built relative to its root
    br.box((1.45, 0, 0.2), (3.0, 0.45, 0.45), "fur_brown", rot=(math.radians(8), "Y"))
    br.box((2.6, 0.25, 0.55), (0.9, 0.2, 0.2), "fur_brown", rot=(math.radians(-30), "Y"))      # twig
    br.ico((3.25, 0.1, 0.55), 0.6, "leaf_dark")                                                # leaf tuft at the tip
    return [t.finalize("CatCafe_Park_RescueTree_Trunk", mat),
            br.finalize("CatCafe_Park_RescueTree_Branch", mat, location=root)]


def build_trash_can(mat):
    """Rescue trap (trashcan): round slatted park bin, its lid pushed open. Pivot base center; the
    Lid is its own part pivoting on the back of the rim. The stuck cat stands inside with head and
    front paws over the rim."""
    b = Builder()
    b.cyl_base((0, 0, 0), 0.9, 2.1, "metal", segments=12)                                      # liner
    b.cyl((0, 0, 2.1), 0.85, 0.02, "fur_black", segments=12, bevel=False)                      # trash inside
    n = 12
    for i in range(n):
        a = 2 * math.pi * i / n
        b.box_base((0.99 * math.cos(a), 0.99 * math.sin(a), 0.1), (0.34, 0.1, 1.95), "dark_wood", bevel=False,
                   rot=(a + math.pi / 2, "Z"))
    for z in (0.5, 1.7):
        b.ring((0, 0, z), 1.07, 0.06, 0.12, "concrete_dark", segments=12, bevel=False)          # hoops
    b.ring((0, 0, 2.15), 1.05, 0.12, 0.1, "concrete_dark", segments=12, bevel=False)            # rim
    b.cyl_base((0, 0, 0), 1.1, 0.1, "concrete", segments=12, bevel=False)                     # foot
    lid = Builder()                                                                            # pushed open, own part
    t = math.radians(110)                                                                      # past upright, resting back
    lid.cyl((0, -1.0 * math.cos(t), 1.0 * math.sin(t)), 1.0, 0.08, "concrete_dark", segments=12, rot=(-t, "X"))
    lid.cyl((0, -1.0 * math.cos(t) + 0.1 * math.sin(t), 1.0 * math.sin(t) + 0.1 * math.cos(t)), 0.16, 0.12, "metal",
            segments=8, rot=(-t, "X"))                                                         # knob
    return [b.finalize("CatCafe_Park_TrashCan_Can", mat),
            lid.finalize("CatCafe_Park_TrashCan_Lid", mat, location=(0, 1.05, 2.2))]


def build_fountain(mat):
    """Basin + Water objects; Water gets Transparency 0.3 in Studio."""
    basin = Builder()
    basin.ring((0, 0, 0.5), 2.5, 0.35, 1.0, "concrete", segments=16, bevel=False)
    basin.cyl_base((0, 0, 0), 2.5, 0.2, "concrete_dark", segments=16, bevel=False)
    basin.cyl_base((0, 0, 0.2), 0.35, 2.2, "concrete", segments=10)
    basin.cyl_base((0, 0, 2.4), 1.0, 0.2, "concrete", segments=12, radius2=1.1)
    basin.ring((0, 0, 2.75), 1.15, 0.15, 0.35, "concrete", segments=12, bevel=False)
    basin.sphere((0, 0, 3.4), 0.3, "sign_teal", segments=10, rings=6)
    water = Builder()
    water.cyl_base((0, 0, 0.2), 2.15, 0.6, "puddle", segments=16, bevel=False)
    water.cyl_base((0, 0, 2.6), 1.0, 0.25, "puddle", segments=16, bevel=False)
    return [basin.finalize("CatCafe_Park_Fountain_Basin", mat), water.finalize("CatCafe_Park_Fountain_Water", mat)]


ASSETS = {
    "CatCafe_Park_Bench": (build_park_bench, 800),
    "CatCafe_Park_Tree": (build_tree, 800),
    "CatCafe_Park_Fountain": (build_fountain, 1200),
    "CatCafe_Park_RescueTree": (build_rescue_tree, 900),
    "CatCafe_Park_TrashCan": (build_trash_can, 900),
}
